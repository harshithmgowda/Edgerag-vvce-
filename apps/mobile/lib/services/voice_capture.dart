import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class VoiceCapture {
  final _recorder = AudioRecorder();
  String? _path;
  bool _disposed = false;
  Future<void> start() async {
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission is required. Enable it in Android app settings.');
    }
    if (_disposed) return;
    final temp = await getTemporaryDirectory();
    _path = '${temp.path}/edgerag_voice_${DateTime.now().microsecondsSinceEpoch}.wav';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.wav,
      sampleRate: 16000, numChannels: 1), path: _path!);
  }

  Future<File> stop() async {
    final path = await _recorder.stop();
    if (path == null) throw StateError('No audio recording was captured.');
    return File(path);
  }

  Future<void> dispose() async {
    _disposed = true;
    await _recorder.dispose();
    final path = _path;
    if (path != null && await File(path).exists()) await File(path).delete();
  }
}
