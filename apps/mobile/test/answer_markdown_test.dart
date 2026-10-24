import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edgerag_mobile/widgets/answer_markdown.dart';

void main() {
  test('Answers hide source metadata without altering Markdown or measurements', () {
    expect(cleanAnswerText('Use 40 °C [Source abc-123].\n\n- Check [Chunk def].'),
        'Use 40 °C.\n\n- Check.');
    expect(cleanAnswerText('Check [1](source:abc) and [2](#source-def).'), 'Check and.');
    for (final suffix in ['[S', '[Source', '[Source abc', '[Chunk def']) {
      expect(cleanAnswerText('Answer $suffix'), 'Answer');
    }
    const markdown = '1. Step\n   - detail\n\n[Manual](https://example.com) [1] [40 °C]\n\n```dart\n  value[0];\n```';
    expect(cleanAnswerText(markdown), markdown);
  });
  test('Streaming preserves indentation and closes only an unfinished fence', () {
    const text = '1. Step\n   - nested\n\n```dart\n  print("hello");';
    expect(prepareMarkdown(text, streaming: true), '$text\n```\n');
    expect(prepareMarkdown(text), text);
    const complete = '~~~sql\nSELECT 1;\n~~~\n\nDone';
    expect(prepareMarkdown(complete, streaming: true), complete);
  });

  testWidgets('Headings, lists, wide tables and code fit a narrow dark screen', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(theme: ThemeData.dark(),
      home: const Scaffold(body: SingleChildScrollView(child: Padding(
        padding: EdgeInsets.all(16),
        child: AnswerMarkdown('''# Answer

**Check the source.**

1. First step
   - Nested detail
2. Second step

| Parameter with a long name | Measured value | Notes |
| --- | --- | --- |
| Temperature | 40 °C | Recorded observation |

```python
print("a very long line of code that must scroll horizontally on a phone")
```
'''),
      )))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Answer'), findsOneWidget);
  });
}
