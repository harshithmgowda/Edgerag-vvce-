package com.edgerag.mobile

import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import org.json.JSONObject
import java.io.File
import java.text.Normalizer
import java.util.Locale
import kotlin.math.sqrt

/** BERT uncased WordPiece, 256 tokens, masked mean pooling, L2 normalization. */
class MiniLmEncoder(directory: String) : AutoCloseable {
    private val env = OrtEnvironment.getEnvironment()
    private val vocab = JSONObject(File(directory, "tokenizer.json").readText()).getJSONObject("model").getJSONObject("vocab")
    private val session = OrtSession.SessionOptions().use { options ->
        options.setIntraOpNumThreads(2)
        env.createSession(File(directory, "onnx/model.onnx").path, options)
    }

    fun tokenize(text: String): LongArray {
        val cleaned = StringBuilder()
        text.codePoints().forEach { cp ->
            val type = Character.getType(cp)
            when {
                cp == 0 || cp == 0xfffd -> Unit
                Character.isWhitespace(cp) || type == Character.SPACE_SEPARATOR.toInt() -> cleaned.append(' ')
                type == Character.CONTROL.toInt() || type == Character.FORMAT.toInt() -> Unit
                cp in 0x4e00..0x9fff || cp in 0x3400..0x4dbf || cp in 0x20000..0x2fa1f -> cleaned.append(' ').appendCodePoint(cp).append(' ')
                else -> cleaned.appendCodePoint(cp)
            }
        }
        val normalized = Normalizer.normalize(cleaned.toString().lowercase(Locale.ROOT), Normalizer.Form.NFD)
            .replace(Regex("\\p{Mn}"), "")
        val words = mutableListOf<String>()
        val current = StringBuilder()
        fun flush() { if (current.isNotEmpty()) { words.add(current.toString()); current.setLength(0) } }
        normalized.codePoints().forEach { cp ->
            val punctuation = cp in 33..47 || cp in 58..64 || cp in 91..96 || cp in 123..126 ||
                Character.getType(cp) in listOf(20, 21, 22, 23, 24, 29, 30)
            when { Character.isWhitespace(cp) -> flush()
                punctuation -> { flush(); words.add(String(Character.toChars(cp))) }
                else -> current.appendCodePoint(cp) }
        }
        flush()
        val result = mutableListOf(vocab.getLong("[CLS]"))
        for (word in words) {
            val pieces = mutableListOf<Long>()
            var start = 0
            var bad = word.length > 100
            while (start < word.length && !bad) {
                var end = word.length
                var found: String? = null
                while (end > start) {
                    val piece = (if (start == 0) "" else "##") + word.substring(start, end)
                    if (vocab.has(piece)) { found = piece; break }
                    end--
                }
                if (found == null) bad = true else { pieces.add(vocab.getLong(found)); start = end }
            }
            result.addAll(if (bad) listOf(vocab.getLong("[UNK]")) else pieces)
            if (result.size >= 255) break
        }
        return (result.take(255) + vocab.getLong("[SEP]")).toLongArray()
    }

    fun embed(text: String): List<Double> {
        val ids = tokenize(text)
        val tensors = mutableMapOf<String, OnnxTensor>()
        try {
            tensors["input_ids"] = OnnxTensor.createTensor(env, arrayOf(ids))
            tensors["attention_mask"] = OnnxTensor.createTensor(env, arrayOf(LongArray(ids.size) { 1 }))
            if (session.inputNames.contains("token_type_ids")) tensors["token_type_ids"] = OnnxTensor.createTensor(env, arrayOf(LongArray(ids.size)))
            session.run(tensors).use { output ->
                @Suppress("UNCHECKED_CAST")
                val tokens = (output[0].value as Array<Array<FloatArray>>)[0]
                require(tokens.isNotEmpty() && tokens[0].size == 384) { "Expected MiniLM token embeddings" }
                val vector = DoubleArray(384)
                for (token in tokens) for (i in vector.indices) vector[i] += token[i] / tokens.size.toDouble()
                val norm = sqrt(vector.sumOf { it * it }).coerceAtLeast(1e-12)
                return vector.map { it / norm }
            }
        } finally { tensors.values.forEach { it.close() } }
    }
    override fun close() { session.close() }
}
