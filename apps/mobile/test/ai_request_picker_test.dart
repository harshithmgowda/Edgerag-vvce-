import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:edgerag_mobile/models/models.dart';
import 'package:edgerag_mobile/widgets/ai_request_picker.dart';

void main() {
  testWidgets('Provider selection is explicit and local mode hides cloud controls', (tester) async {
    var mode = AiMode.offlineOnly;
    var provider = 'auto';
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: StatefulBuilder(
      builder: (context, setState) => AiRequestPicker(mode: mode, provider: provider,
        onChanged: (m, p) => setState(() { mode = m; provider = p; })),
    ))));
    expect(find.byType(DropdownButton<String>), findsNothing);
    await tester.tap(find.byType(DropdownButton<AiMode>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('External AI · choose provider').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gemini · model from AI Providers').last);
    await tester.pumpAndSettle();
    expect(mode, AiMode.onlineAi);
    expect(provider, 'gemini');
  });
  testWidgets('Cloud audio offers only audio-capable providers', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: AiRequestPicker(
      mode: AiMode.onlineAi, provider: 'auto', audio: true, onChanged: (_, __) {},
    ))));
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('Gemini · model from AI Providers'), findsWidgets);
    expect(find.text('NVIDIA · model from AI Providers'), findsNothing);
  });
}
