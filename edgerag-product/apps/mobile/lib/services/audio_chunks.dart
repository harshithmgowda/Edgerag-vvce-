import 'dart:convert';
import 'dart:typed_data';

/// Bound audio embeddings as well as text tokens. Each request contains at most
/// eight seconds of normalized PCM; WAV headers are regenerated per segment.
List<Uint8List> splitPcmWave(Uint8List wav, {int seconds = 8}) {
  if (wav.length < 44 ||
      ascii.decode(wav.sublist(0, 4)) != 'RIFF' ||
      ascii.decode(wav.sublist(8, 12)) != 'WAVE')
    throw FormatException('Expected WAV audio.');
  final data = ByteData.sublistView(wav);
  Uint8List? format, pcm;
  for (var offset = 12; offset + 8 <= wav.length;) {
    final name = ascii.decode(wav.sublist(offset, offset + 4));
    final size = data.getUint32(offset + 4, Endian.little);
    if (offset + 8 + size > wav.length)
      throw FormatException('Incomplete WAV audio.');
    if (name == 'fmt ')
      format = Uint8List.sublistView(wav, offset + 8, offset + 8 + size);
    if (name == 'data')
      pcm = Uint8List.sublistView(wav, offset + 8, offset + 8 + size);
    offset += 8 + size + (size % 2);
  }
  if (format == null || format.length < 16 || pcm == null || pcm.isEmpty)
    throw FormatException('WAV contains no audio.');
  final fmt = ByteData.sublistView(format);
  if (fmt.getUint16(0, Endian.little) != 1 ||
      fmt.getUint16(2, Endian.little) != 1 ||
      fmt.getUint32(4, Endian.little) != 16000 ||
      fmt.getUint16(14, Endian.little) != 16) {
    throw FormatException('Use 16 kHz mono PCM WAV audio.');
  }
  if (seconds < 1) throw ArgumentError.value(seconds);
  final result = <Uint8List>[];
  final size = seconds * 32000;
  for (var offset = 0; offset < pcm.length; offset += size) {
    final end = (offset + size).clamp(0, pcm.length);
    final bytes = Uint8List(44 + end - offset);
    final header = ByteData.sublistView(bytes);
    bytes.setRange(0, 4, ascii.encode('RIFF'));
    header.setUint32(4, bytes.length - 8, Endian.little);
    bytes.setRange(8, 16, ascii.encode('WAVEfmt '));
    header.setUint32(16, 16, Endian.little);
    bytes.setRange(20, 36, format.take(16));
    bytes.setRange(36, 40, ascii.encode('data'));
    header.setUint32(40, end - offset, Endian.little);
    bytes.setRange(44, bytes.length, pcm.sublist(offset, end));
    result.add(bytes);
  }
  return result;
}
