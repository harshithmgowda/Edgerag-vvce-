package com.edgerag.mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.media.MediaMetadataRetriever
import android.media.MediaExtractor
import android.media.MediaCodec
import android.media.MediaFormat
import android.graphics.Bitmap
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import java.io.File
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val worker = Executors.newSingleThreadExecutor()
    private var encoder: MiniLmEncoder? = null
    private var encoderPath: String? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.edgerag.mobile/embedding")
            .setMethodCallHandler { call, result ->
                if (call.method != "embed" && call.method != "tokenize") { result.notImplemented(); return@setMethodCallHandler }
                worker.execute {
                    try {
                        val directory = call.argument<String>("directory") ?: error("Missing model directory")
                        val text = call.argument<String>("text") ?: error("Missing query")
                        if (encoderPath != directory) {
                            encoder?.close(); encoder = null; encoderPath = null
                            encoder = MiniLmEncoder(directory); encoderPath = directory
                        }
                        val value: Any = if (call.method == "embed") encoder!!.embed(text) else encoder!!.tokenize(text).toList()
                        runOnUiThread { result.success(value) }
                    } catch (e: Exception) { runOnUiThread { result.error("EMBEDDING", e.message, null) } }
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.edgerag.mobile/media")
            .setMethodCallHandler { call, result ->
                val path = call.argument<String>("path")
                if (path == null || !File(path).isFile) {
                    result.error("MEDIA", "The selected file is unavailable.", null)
                    return@setMethodCallHandler
                }
                when (call.method) {
                    "recognizeText" -> {
                        val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                        try {
                            val input = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                            recognizer.process(input)
                                .addOnSuccessListener { result.success(it.text) }
                                .addOnFailureListener { result.error("OCR", it.message, null) }
                                .addOnCompleteListener { recognizer.close() }
                        } catch (e: Exception) {
                            recognizer.close()
                            result.error("OCR", e.message, null)
                        }
                    }
                    "extractFrames", "decodeAudio" -> worker.execute {
                        try {
                            val output = if (call.method == "extractFrames") extractFrames(path) else decodeAudio(path)
                            runOnUiThread { result.success(output) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("MEDIA", e.message, null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun extractFrames(path: String): List<Map<String, Any>> {
        val reader = MediaMetadataRetriever()
        val files = mutableListOf<File>()
        try {
            reader.setDataSource(path)
            val rawDuration = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong() ?: 0
            val duration = if (rawDuration <= 0) 3000L else rawDuration.coerceIn(500L, 45000L)
            return (0..2).map { index ->
                val time = duration * (index * 2 + 1) / 6
                var bitmap: Bitmap? = try {
                    reader.getScaledFrameAtTime(time * 1000, MediaMetadataRetriever.OPTION_CLOSEST, 768, 768)
                } catch (e: Throwable) {
                    null
                }
                if (bitmap == null) {
                    bitmap = try {
                        reader.getFrameAtTime(time * 1000, MediaMetadataRetriever.OPTION_CLOSEST)
                    } catch (e: Throwable) {
                        null
                    }
                }
                if (bitmap == null) {
                    bitmap = try {
                        reader.frameAtTime
                    } catch (e: Throwable) {
                        null
                    }
                }
                val validBitmap = bitmap ?: error("Cannot decode video frame at ${time}ms.")
                val file = File.createTempFile("edgerag_frame_", ".jpg", cacheDir)
                files.add(file)
                try { file.outputStream().use { validBitmap.compress(Bitmap.CompressFormat.JPEG, 85, it) } }
                finally { validBitmap.recycle() }
                mapOf("path" to file.path, "timestampMs" to time)
            }
        } catch (e: Exception) {
            files.forEach { it.delete() }
            throw e
        } finally { reader.release() }
    }

    // Decode compressed audio using Android codecs; downsample to mono WAV.
    private fun decodeAudio(path: String): String {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        try {
            extractor.setDataSource(path)
            val track = (0 until extractor.trackCount).firstOrNull {
                extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true
            } ?: error("No supported audio track found.")
            extractor.selectTrack(track)
            val format = extractor.getTrackFormat(track)
            require(format.containsKey(MediaFormat.KEY_DURATION) &&
                format.getLong(MediaFormat.KEY_DURATION) <= 90_000_000) { "Offline audio is limited to 90 seconds." }
            var rate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            if (format.getString(MediaFormat.KEY_MIME) == "audio/raw" &&
                rate == 16000 && channels == 1 && path.endsWith(".wav", ignoreCase = true)) {
                return path
            }
            val decoder = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
            codec = decoder
            decoder.configure(format, null, null, 0)
            decoder.start()
            val pcm = ByteArrayOutputStream()
            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            var frameIndex = 0L
            var nextOutput = 0L
            val deadline = System.nanoTime() + 120_000_000_000L
            while (!outputDone) {
                check(System.nanoTime() < deadline) { "Audio decoding timed out." }
                if (!inputDone) {
                    val index = decoder.dequeueInputBuffer(10000)
                    if (index >= 0) {
                        val size = extractor.readSampleData(decoder.getInputBuffer(index)!!, 0)
                        if (size < 0) {
                            decoder.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val index = decoder.dequeueOutputBuffer(info, 10000)
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val output = decoder.outputFormat
                    rate = output.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = output.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
                    require(!output.containsKey(MediaFormat.KEY_PCM_ENCODING) ||
                        output.getInteger(MediaFormat.KEY_PCM_ENCODING) == 2) { "Unsupported PCM encoding." }
                } else if (index >= 0) {
                    val buffer = decoder.getOutputBuffer(index)!!.order(ByteOrder.LITTLE_ENDIAN)
                    buffer.position(info.offset)
                    buffer.limit(info.offset + info.size)
                    while (buffer.remaining() >= channels * 2) {
                        var sum = 0
                        repeat(channels) { sum += buffer.short.toInt() }
                        if (frameIndex * 16000 >= nextOutput * rate) {
                            val sample = sum / channels
                            pcm.write(sample and 255)
                            pcm.write((sample shr 8) and 255)
                            nextOutput++
                        }
                        frameIndex++
                        require(nextOutput <= 16000L * 90) { "Offline audio is limited to 90 seconds." }
                    }
                    outputDone = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                    decoder.releaseOutputBuffer(index, false)
                }
            }
            val bytes = pcm.toByteArray()
            require(bytes.isNotEmpty()) { "Audio contains no samples." }
            val header = ByteBuffer.allocate(44).order(ByteOrder.LITTLE_ENDIAN)
            header.put("RIFF".toByteArray()).putInt(36 + bytes.size).put("WAVEfmt ".toByteArray())
                .putInt(16).putShort(1).putShort(1).putInt(16000).putInt(32000)
                .putShort(2).putShort(16).put("data".toByteArray()).putInt(bytes.size)
            val file = File.createTempFile("edgerag_audio_", ".wav", cacheDir)
            file.outputStream().use { it.write(header.array()); it.write(bytes) }
            return file.path
        } finally {
            try { codec?.stop() } finally { codec?.release(); extractor.release() }
        }
    }
}
