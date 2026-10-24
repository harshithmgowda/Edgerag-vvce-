import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SemanticEncoder {
  static const channel = MethodChannel('com.edgerag.mobile/embedding');
  static Future<List<double>?> embed(String text, String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    if (fingerprint.isEmpty || prefs.getString('encoder_fingerprint') != fingerprint) return null;
    final directory = prefs.getString('encoder_directory');
    if (directory == null) return null;
    try {
      final result = await channel.invokeListMethod<num>('embed', {'directory': directory, 'text': text});
      final vector = result?.map((v) => v.toDouble()).toList();
      return vector?.length == 384 && vector!.every((v) => v.isFinite) ? vector : null;
    } on PlatformException { return null; } on MissingPluginException { return null; }
  }

  static Future<void> importBundle(String zipPath) async {
    final archive = ZipDecoder().decodeBytes(await File(zipPath).readAsBytes());
    final manifestFile = archive.findFile('encoder.json');
    if (manifestFile == null) throw StateError('Use the MiniLM bundle exported by this backend.');
    final manifest = jsonDecode(utf8.decode(manifestFile.content as List<int>));
    final fingerprint = manifest['fingerprint'] as String;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(fingerprint)) throw StateError('Invalid encoder identity');
    final docs = await getApplicationDocumentsDirectory();
    final directory = Directory('${docs.path}/models/minilm-$fingerprint');
    final stage = Directory('${directory.path}-${DateTime.now().microsecondsSinceEpoch}.partial');
    await stage.create(recursive: true);
    try {
      for (final name in ['tokenizer.json', 'onnx/model.onnx']) {
        final entry = archive.findFile(name);
        if (entry == null || entry.size > 200 * 1024 * 1024) throw StateError('Missing or oversized encoder file');
        final bytes = entry.content as List<int>;
        if (sha256.convert(bytes).toString() != manifest['files'][name]) throw StateError('Encoder checksum mismatch');
        final file = File('${stage.path}/$name');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes, flush: true);
      }
      final actual = sha256.convert(utf8.encode('${manifest['files']['onnx/model.onnx']}${manifest['files']['tokenizer.json']}')).toString();
      if (actual != fingerprint) throw StateError('Encoder fingerprint mismatch');
      final cases = manifest['parity_cases'] as List;
      if (cases.length < 3) throw StateError('Missing tokenizer and vector parity cases');
      for (final test in cases) {
        final args = {'directory': stage.path, 'text': test['text']};
        final ids = await channel.invokeListMethod<num>('tokenize', args);
        if (jsonEncode(ids) != jsonEncode(test['ids'])) throw StateError('Mobile tokenizer differs from server');
        final vector = await channel.invokeListMethod<num>('embed', args);
        final expected = (test['vector'] as List).cast<num>();
        if (vector == null || vector.length != 384 || expected.length != 384) throw StateError('Invalid encoder output');
        var cosine = 0.0;
        for (var i=0; i<384; i++) { cosine += vector[i] * expected[i]; }
        if (!cosine.isFinite || cosine < .999) throw StateError('Mobile embeddings differ from server');
      }
      if (!await directory.exists()) await stage.rename(directory.path);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('encoder_directory', directory.path);
      await prefs.setString('encoder_fingerprint', fingerprint);
    } finally { if (await stage.exists()) await stage.delete(recursive: true); }
  }
}
