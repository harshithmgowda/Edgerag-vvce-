from pathlib import Path
r=Path.cwd();p=r/'apps/mobile/lib/services/agent_controller.dart';s=p.read_text();s="import 'dart:convert';\nimport 'package:http/http.dart' as http;\n"+s
s=s.replace('    Function(String token)? onTokenStream,','    Function(String token)? onTokenStream,\n    Function(String status)? onStatus,\n    Function()? onReset,\n    List<Map<String, String>> history = const [],')
s=s.replace('    // 1. Initial Retrieval','''    onStatus?.call('Searching your documents…');
    if (aiMode != AiMode.offlineOnly &&
        (_netService.currentState == NetworkState.hqLanHotspot || _netService.currentState == NetworkState.fullyConnected)) {
      try {
        return await _queryHeadquarters(question, equipmentId, history, onTokenStream, onStatus, onReset);
      } catch (_) {
        onReset?.call();
        trace.add('[NETWORK] HQ chat unavailable; trying downloaded knowledge and device providers.');
      }
    }
    // 1. Initial Retrieval''')
s=s.replace('    String currentQuery = question;', "    String currentQuery = question;\n    if (RegExp(r'^(explain (it|that)|why|how so|give (me )?an? example|continue|what about)', caseSensitive: false).hasMatch(question) && history.isNotEmpty) {\n      final previous = history.where((m) => m['role'] == 'user').toList();\n      if (previous.isNotEmpty) currentQuery = previous.last['content']!;\n    }")
s=s.replace('    // 3. Model Selection & Reasoning', "    onStatus?.call('Found ${retrievedChunks.length} relevant passages');\n    // 3. Model Selection & Reasoning")
s=s.replace("        providerUsed = 'NVIDIA NIM Llama 3.2 (Cloud)';", "        providerUsed = 'NVIDIA NIM (Cloud)';\n        onStatus?.call('Writing with NVIDIA…');")
s=s.replace("          providerUsed = 'Google Gemini (Online Cloud)';", "          providerUsed = 'Google Gemini (Cloud)';\n          onStatus?.call('Writing with Gemini…');")
s=s.replace("      providerUsed = 'Local GGUF Model';", "      providerUsed = 'Local GGUF Model';\n      onStatus?.call('Loading the on-device model…');")
s=s.replace('question: question, chunks: retrievedChunks)', 'question: question, chunks: retrievedChunks, onStatus: onStatus)')
s=s.replace('    // 4. Citation Grounding Verifier', "    onStatus?.call('Checking source references…');\n    // 4. Citation Grounding Verifier")
a=s.index('  String _rewriteQuery')
s=s[:a]+'''  http.Client? _activeClient;
  Future<void> cancel() async {
    _activeClient?.close();
    await _localAi.cancel();
  }

  Future<AgentResult> _queryHeadquarters(String question, String equipmentId,
      List<Map<String,String>> history, Function(String)? onToken,
      Function(String)? onStatus, Function()? onReset) async {
    final client = http.Client();
    _activeClient = client;
    try {
      final request = http.Request('POST', Uri.parse('${_netService.hqBaseUrl}/ai/chat/stream'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({'question': question, 'equipment_id': equipmentId, 'ai_mode': 'ONLINE_AI', 'history': history});
      final response = await client.send(request).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('HQ chat unavailable');
      String event = '';
      AgentResult? result;
      await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter()).timeout(const Duration(seconds: 100))) {
        if (line.startsWith('event: ')) event = line.substring(7);
        if (!line.startsWith('data: ')) continue;
        final data = jsonDecode(line.substring(6)) as Map<String,dynamic>;
        if (event == 'status') onStatus?.call(data['message'] as String);
        if (event == 'reset') onReset?.call();
        if (event == 'delta') onToken?.call(data['text'] as String);
        if (event == 'error') throw StateError(data['message'] as String);
        if (event == 'result') {
          result = AgentResult(answer: data['answer'] as String,
            citations: (data['citations'] as List).map((c)=>ChunkModel(id:c['chunk_id'], manualId:c['manual_id'],
              manualTitle:c['manual_title'], pageNumber:c['page_number'], chunkText:c['snippet'],
              embedding:const [], similarityScore:(c['similarity_score'] as num).toDouble())).toList(),
            providerUsed:data['provider_used'] as String,
            executionTrace:List<String>.from(data['execution_trace']), isSuccess:data['status']=='SUCCESS');
        }
      }
      if (result == null) throw StateError('HQ response ended early');
      return result;
    } finally { client.close(); _activeClient = null; }
  }

'''+s[a:];p.write_text(s,encoding='utf-8')
p=r/'apps/mobile/lib/services/local_ai_service.dart';s=p.read_text();s="import 'dart:async';\n"+s;s=s.replace('    required List<ChunkModel> chunks,','    required List<ChunkModel> chunks,\n    Function(String)? onStatus,')
s=s.replace("          'Cite every factual claim", "          'Use readable Markdown, clear explanations, numbered steps when helpful, and one or two relevant emojis. '\n          'Cite every factual claim")
a=s.index('      final response = await runtime.completion');b=s.index('    } finally {',a)
s=s[:a]+'''      onStatus?.call('Writing with $_modelName…');
      final tokens = StreamController<String>();
      var emitted = false;
      final subscription = runtime.onTokenStream?.listen((event) {
        if (event['function'] == 'completion') {
          final token = event['result']?['token']?.toString() ?? '';
          if (token.isNotEmpty && !tokens.isClosed) { emitted = true; tokens.add(token); }
        }
      });
      final completion = runtime.completion(_contextId!, prompt:prompt,
        temperature:.2, nPredict:700, penaltyRepeat:1.1, emitRealtimeCompletion:true,
        stop:['<|end|>', '<|eot_id|>', '<|im_end|>']);
      unawaited(completion.then((response) {
        final answer = response?['text']?.toString().trim() ?? '';
        if (!emitted && answer.isNotEmpty) tokens.add(answer);
        if (!emitted && answer.isEmpty) tokens.addError(StateError('Local model returned an empty answer.'));
      }, onError: (Object error, StackTrace stack) { tokens.addError(error, stack); }).whenComplete(() async {
        await subscription?.cancel();
        await tokens.close();
      }));
      yield* tokens.stream;
''' + s[b:]
s=s.replace('  double? _contextId;', '''  Future<void> cancel() async {
    if (_contextId != null) await Fllama.instance()!.stopCompletion(contextId: _contextId!);
  }

  double? _contextId;''');p.write_text(s,encoding='utf-8')
# Prompt style shared by direct mobile cloud paths.
for name in ['gemini_service.dart','nvidia_service.dart']:
 p=r/'apps/mobile/lib/services'/name;s=p.read_text();s=s.replace('For every factual instruction,', 'Write a direct, helpful answer in Markdown. Use headings, short paragraphs, steps, tables or fenced code when useful. Use one or two relevant emojis naturally. Explain the evidence instead of copying passages verbatim.\nFor every factual instruction,');p.write_text(s)
p=r/'apps/mobile/pubspec.yaml';s=p.read_text();s+='''  fonts:
    - family: Metropolis
      fonts:
        - asset: assets/fonts/Metropolis-Regular.ttf
        - asset: assets/fonts/Metropolis-SemiBold.ttf
          weight: 600
        - asset: assets/fonts/Metropolis-Bold.ttf
          weight: 700
    - family: OpenSans
      fonts:
        - asset: assets/fonts/OpenSans-Regular.ttf
        - asset: assets/fonts/OpenSans-Bold.ttf
          weight: 700
        - asset: assets/fonts/OpenSans-Italic.ttf
          style: italic
''';p.write_text(s)
p=r/'apps/mobile/lib/main.dart';s=p.read_text().replace("fontFamily: 'Roboto'", "fontFamily: 'Metropolis'").replace('0xFF0F172A','0xFF174E39').replace('0xFFF8FAFC','0xFFF8FAF5');s=s.replace('        useMaterial3: true,', '''        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8FAF5),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF8FAF5), centerTitle: false, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDCE5D8)))),
        textTheme: const TextTheme(bodyMedium: TextStyle(fontFamily: 'OpenSans', height: 1.6), bodyLarge: TextStyle(fontFamily:'OpenSans', height:1.6)),''');p.write_text(s)
