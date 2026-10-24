import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:edgerag_mobile/services/edge_runtime.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Installed Gemma handles oversized evidence and a second warm request', (tester) async {
    final runtime = EdgeRuntime();
    try {
      final answer = await runtime.generate(
        systemPrompt: 'Answer in one short sentence using the evidence.',
        prompt: '${List.filled(400, "Pump A has a rated pressure of 5 bar. ").join()}\nQUESTION: What is Pump A rated pressure?');
      expect(answer.trim(), isNotEmpty);
      expect(answer, contains('5'));
      final next = await runtime.generate(prompt: 'Reply with the word READY.');
      expect(next.trim(), isNotEmpty);
    } finally { await runtime.release(); }
  }, timeout: const Timeout(Duration(minutes: 8)));
}
