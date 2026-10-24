import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:edgerag_mobile/services/audio_chunks.dart';

void main() {
  test('Long audio is split without dropping PCM samples', () {
    final bytes = Uint8List(44 + 17 * 32000);
    final data = ByteData.sublistView(bytes);
    bytes.setRange(0, 4, ascii.encode('RIFF'));
    data.setUint32(4, bytes.length - 8, Endian.little);
    bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, 16000, Endian.little);
    data.setUint32(28, 32000, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    bytes.setRange(36, 40, ascii.encode('data'));
    data.setUint32(40, bytes.length - 44, Endian.little);
    for (var i = 44; i < bytes.length; i++) { bytes[i] = i % 255; }
    final segments = splitPcmWave(bytes);
    expect(segments, hasLength(3));
    expect(segments.expand((s) => s.skip(44)), orderedEquals(bytes.skip(44)));
    expect(segments.every((s) => s.length <= 44 + 8 * 32000), isTrue);
  });
  test('Corrupt audio fails instead of returning a fake transcript', () {
    expect(() => splitPcmWave(Uint8List(10)), throwsFormatException);
  });
}
