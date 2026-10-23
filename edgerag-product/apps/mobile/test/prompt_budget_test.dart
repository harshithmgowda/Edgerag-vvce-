import 'package:flutter_test/flutter_test.dart';
import 'package:edgerag_mobile/services/prompt_budget.dart';

void main() {
  Future<int> count(String value) async => value.runes.length;
  test('A short prompt is unchanged', () async {
    expect(await fitPrompt('What is pressure?', 100, count), 'What is pressure?');
  });
  test('Oversized evidence keeps the question and fits the reserved input budget', () async {
    final text = '${List.filled(4000, 'manual evidence ').join()}\nQUESTION: What is pressure?';
    final result = await fitPrompt(text, 1100, count);
    expect(await count(result), lessThanOrEqualTo(1100));
    expect(result, endsWith('QUESTION: What is pressure?'));
    expect(result, startsWith('manual evidence'));
  });
  test('Unicode stays intact under truncation', () async {
    final result = await fitPrompt(List.filled(1000, '🔧 ಕನ್ನಡ ').join(), 180, count);
    expect(await count(result), lessThanOrEqualTo(180));
    expect(result.contains('\uFFFD'), isFalse);
  });
}
