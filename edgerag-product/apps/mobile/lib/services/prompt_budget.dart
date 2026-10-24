/// Fit text using the loaded model's tokenizer, preserving both evidence at the
/// start and the technician's question at the end. Never estimate by word count.
Future<String> fitPrompt(
    String text, int budget, Future<int> Function(String) countTokens) async {
  if (budget <= 0) throw ArgumentError.value(budget, 'budget');
  if (await countTokens(text) <= budget) return text;
  final points = text.runes.toList();
  String candidate(int length) {
    final tail = length ~/ 3;
    return '${String.fromCharCodes(points.take(length - tail))}\n[Excerpt shortened to fit on-device context]\n${String.fromCharCodes(points.skip(points.length - tail))}';
  }

  var low = 0, high = points.length;
  var best = '';
  while (low <= high) {
    final middle = (low + high) ~/ 2;
    final value = candidate(middle);
    if (await countTokens(value) <= budget) {
      best = value;
      low = middle + 1;
    } else {
      high = middle - 1;
    }
  }
  return best;
}
