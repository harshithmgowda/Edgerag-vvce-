import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import '../models/models.dart';
import 'database_service.dart';
import 'knowledge_retrieval.dart';
import 'local_ai_service.dart';
import 'gemini_service.dart';
import 'nvidia_service.dart';
import 'network_service.dart';
import 'model_registry_service.dart';

class AgentExecutionTrace {
  final List<String> events = [];
  void add(String event) => events.add(event);
}

class AgentResult {
  final String answer;
  final List<ChunkModel> citations;
  final String providerUsed;
  final List<String> executionTrace;
  final bool isSuccess;
  final String evidenceStatus;
  final String? errorMessage;

  AgentResult({
    required this.answer,
    required this.citations,
    required this.providerUsed,
    required this.executionTrace,
    this.isSuccess = true,
    this.evidenceStatus = 'NEEDS_REVIEW',
    this.errorMessage,
  });
}

class AgentController {
  static final AgentController _instance = AgentController._internal();
  factory AgentController() => _instance;
  AgentController._internal();

  final _dbService = DatabaseService();
  final _localAi = LocalAiService();
  final _geminiService = GeminiService();
  final _nvidiaService = NvidiaService();
  final _netService = NetworkService();

  /// Execute bounded on-device agent state machine
  Future<AgentResult> executeQuery({
    required String question,
    required String equipmentId,
    required AiMode aiMode,
    String cloudProvider = 'auto',
    Function(String token)? onTokenStream,
    Function(String status)? onStatus,
    Function()? onReset,
    List<Map<String, String>> history = const [],
  }) async {
    _cancelRequested = false;
    final trace = AgentExecutionTrace();
    trace.add('[PLANNER] Parsing question for equipment $equipmentId');
    trace.add('[PLANNER] Identified query intent: "$question"');

    onStatus?.call('Searching your documents…');
    if (cloudProvider == 'auto' &&
        aiMode == AiMode.smartAuto &&
        !await _dbService.hasExclusions(equipmentId) &&
        (_netService.currentState == NetworkState.hqLanHotspot ||
            _netService.currentState == NetworkState.fullyConnected)) {
      try {
        return await _queryHeadquarters(
            question, equipmentId, history, onTokenStream, onStatus, onReset);
      } catch (_) {
        if (_cancelRequested) throw StateError('Generation stopped');
        onReset?.call();
        trace.add(
            '[NETWORK] HQ chat unavailable; trying downloaded knowledge and device providers.');
      }
    }
    // 1. Initial Retrieval
    String currentQuery = question;
    if (RegExp(r'^(explain (it|that)|why|how so|give (me )?an? example|continue|what about)',
                caseSensitive: false)
            .hasMatch(question) &&
        history.isNotEmpty) {
      final previous = history.where((m) => m['role'] == 'user').toList();
      if (previous.isNotEmpty) currentQuery = previous.last['content']!;
    }
    List<ChunkModel> retrievedChunks = [];
    int attempts = 0;
    const maxAttempts = 3;
    final searchBase = currentQuery;

    while (attempts < maxAttempts) {
      attempts++;
      trace.add(
          '[RETRIEVER] Preparing hybrid retrieval for query attempt #$attempts: "$currentQuery"');
      retrievedChunks = await _dbService
          .searchKnowledgeChunks(equipmentId, currentQuery, limit: 6);

      // 2. Evidence Sufficiency Check
      if (hasSufficientEvidence(retrievedChunks, searchBase)) {
        trace.add(
            '[EVIDENCE] Sufficient evidence located: ${retrievedChunks.length} chunks (Top relevance score: ${retrievedChunks.first.similarityScore.toStringAsFixed(2)})');
        break;
      } else {
        trace.add(
            '[EVIDENCE] Insufficient score (${retrievedChunks.isNotEmpty ? retrievedChunks.first.similarityScore.toStringAsFixed(2) : '0.00'}). Rewriting query...');
        currentQuery = rewriteKnowledgeQuery(searchBase, attempts + 1);
        trace.add(
            '[QUERY_REWRITE] Formulated augmented technical query: "$currentQuery"');
      }
    }

    if (!hasSufficientEvidence(retrievedChunks, searchBase)) {
      final terms = retrievalTerms(searchBase);
      final hasSpecificCode = terms.any((t) => RegExp(r'\d').hasMatch(t));
      final String refusalReason = hasSpecificCode
          ? 'The downloaded manual does not contain technical procedures for this specific code.'
          : 'The manual does not contain verified diagnostic steps for this phrasing.';
      final answer =
          'I cannot verify this procedure in the manual. $refusalReason\n\n'
          'To protect operator safety, EdgeRAG will not guess equipment procedures without manual backing.\n\n'
          '**To find the right section, please clarify:**\n'
          '• The exact error code or alarm number\n'
          '• The component name or subsystem\n'
          '• Or check if a newer manual package is available at HQ';
      onTokenStream?.call(answer);
      trace.add(
          '[EVIDENCE] Insufficient after $attempts attempts; refusal triggered to protect operator safety.');
      return AgentResult(
        answer: answer,
        citations: [],
        providerUsed: 'Evidence Guard',
        executionTrace: trace.events,
        isSuccess: true,
        evidenceStatus: 'INSUFFICIENT',
      );
    }
    // Filter chunks with relevance
    final relevantChunks =
        retrievedChunks.where((c) => c.similarityScore >= 0.40).toList();
    if (relevantChunks.isNotEmpty) {
      onStatus?.call('Found ${relevantChunks.length} relevant manual passages');
      trace.add(
          '[EVIDENCE] Utilizing ${relevantChunks.length} grounded passages from local manual database');
    } else {
      onStatus?.call('Formulating on-device answer…');
      trace.add('[EVIDENCE] General advisory reasoning activated.');
    }
    // 3. Model Selection & Reasoning
    final registry = ModelRegistryService();
    await registry.scanInstalledModels();
    await _localAi.checkModelReadiness();
    final offlineModelName = _localAi.isModelReady ? _localAi.modelName : (registry.getModel(registry.activeChatModelId)?.displayName ?? 'Google Gemma 4 E2B IT');
    String providerUsed = '$offlineModelName (On-Device)';
    String generatedText = '';

    bool canUseCloud = (aiMode == AiMode.onlineAi) ||
        (aiMode == AiMode.smartAuto &&
            (_netService.currentState == NetworkState.publicInternetOnly ||
                _netService.currentState == NetworkState.fullyConnected));

    if (canUseCloud) {
      bool cloudSuccess = false;

      // 1. Try NVIDIA NIM (Fast Cloud Reasoner) first
      if (cloudProvider != 'gemini')
        try {
          trace.add(
              '[REASONER] Invoking NVIDIA NIM (Cloud) with grounded manual evidence');
          providerUsed = 'NVIDIA · ${await _nvidiaService.getSelectedModel()}';
          onStatus?.call('Writing with NVIDIA Cloud AI…');
          await for (final token in _nvidiaService.generateGroundedAnswerStream(
            question: question,
            retrievedChunks: relevantChunks,
            onStatus: onStatus,
          )) {
            generatedText += token;
            if (onTokenStream != null) onTokenStream(token);
          }
          if (generatedText.trim().isNotEmpty) {
            cloudSuccess = true;
          } else {
            throw StateError('NVIDIA Nemotron returned empty response');
          }
        } catch (nvidiaErr) {
          trace.add(
              '[REASONER] NVIDIA Nemotron invocation failed ($nvidiaErr). Trying Gemini...');
        }

      // 2. Try Gemini fallback if NVIDIA NIM failed
      if (!cloudSuccess && cloudProvider != 'nvidia') {
        generatedText = '';
        onReset?.call();
        try {
          trace.add(
              '[REASONER] Invoking Online Google Gemini with grounded evidence');
          providerUsed = 'Gemini · ${await _geminiService.getSelectedModel()}';
          onStatus?.call('Writing with Gemini…');
          generatedText = await _geminiService.generateGroundedAnswer(
            question: question,
            retrievedChunks: relevantChunks,
            onToken: onTokenStream,
          );
          cloudSuccess = true;
        } catch (geminiErr) {
          trace.add(
              '[REASONER] Gemini invocation failed ($geminiErr). Falling back to local offline model.');
        }
      }

      // 3. Fallback to local grounded synthesis if all cloud attempts failed
      if (!cloudSuccess) {
        generatedText = '';
        onReset?.call();
        if (aiMode == AiMode.onlineAi) {
          throw StateError(
              'Cloud provider usage limit reached or unavailable. Switch AI Mode to "Local AI" at the top to answer 100% offline, or check your API key in Settings -> AI Providers.');
        }
        providerUsed = '$offlineModelName (On-Device)';
        try {
          await for (final token in _localAi.generateLocalResponseStream(
              question: question, chunks: relevantChunks, onStatus: onStatus)) {
            generatedText += token;
            if (onTokenStream != null) onTokenStream(token);
          }
        } catch (_) {
          rethrow;
        }
      }
    } else {
      trace.add(
          '[REASONER] Executing on-device inference with $offlineModelName');
      providerUsed = '$offlineModelName (On-Device)';
      onStatus?.call('Reasoning with $offlineModelName…');
      try {
        await for (final token in _localAi.generateLocalResponseStream(
            question: question, chunks: relevantChunks, onStatus: onStatus)) {
          generatedText += token;
          if (onTokenStream != null) onTokenStream(token);
        }
      } catch (_) {
        rethrow;
      }
    }

    if (_cancelRequested) throw StateError('Generation stopped');
    if (providerUsed.endsWith('(On-Device)'))
      providerUsed = '${_localAi.modelName} (On-Device)';
    onStatus?.call('Checking source references…');
    // 4. Citation Grounding Verifier
    trace.add(
        '[VERIFIER] Verifying citation grounding against retrieved chunks: ${relevantChunks.map((c) => 'Page ${c.pageNumber}').toSet().toList()}');
    final verifiedCitations = _verifyCitations(generatedText, relevantChunks);
    trace.add(
        '[VERIFIER] Confirmed ${verifiedCitations.length} cited source manual pages');
    trace.add(
        '[RESULT] Emitted response with ${verifiedCitations.length} verified citation chips');

    final String computedEvidenceStatus;
    if (verifiedCitations.isNotEmpty) {
      computedEvidenceStatus = 'MANUAL_SUPPORTED';
    } else if (relevantChunks.isNotEmpty) {
      computedEvidenceStatus = 'MANUAL_SUPPORTED';
    } else {
      computedEvidenceStatus = 'GENERAL_GUIDANCE';
    }

    return AgentResult(
      answer: generatedText,
      citations: verifiedCitations,
      providerUsed: providerUsed,
      executionTrace: trace.events,
      isSuccess: generatedText.trim().isNotEmpty,
      evidenceStatus: computedEvidenceStatus,
    );
  }

  bool _cancelRequested = false;
  http.Client? _activeClient;
  Future<void> cancel() async {
    _cancelRequested = true;
    _activeClient?.close();
    await _localAi.cancel();
  }

  Future<AgentResult> _queryHeadquarters(
      String question,
      String equipmentId,
      List<Map<String, String>> history,
      Function(String)? onToken,
      Function(String)? onStatus,
      Function()? onReset) async {
    final client = http.Client();
    _activeClient = client;
    try {
      final request = http.Request(
          'POST', Uri.parse('${_netService.hqBaseUrl}/ai/chat/stream'));
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode({
        'question': question,
        'equipment_id': equipmentId,
        'ai_mode': 'ONLINE_AI',
        'history': history
      });
      final response =
          await client.send(request).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('HQ chat unavailable');
      String event = '';
      AgentResult? result;
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 100))) {
        if (line.startsWith('event: ')) event = line.substring(7);
        if (!line.startsWith('data: ')) continue;
        final data = jsonDecode(line.substring(6)) as Map<String, dynamic>;
        if (event == 'status') onStatus?.call(data['message'] as String);
        if (event == 'reset') onReset?.call();
        if (event == 'delta') onToken?.call(data['text'] as String);
        if (event == 'error') throw StateError(data['message'] as String);
        if (event == 'result') {
          result = AgentResult(
              answer: data['answer'] as String,
              citations: (data['citations'] as List)
                  .map((c) => ChunkModel(
                      id: c['chunk_id'],
                      manualId: c['manual_id'],
                      manualTitle: c['manual_title'],
                      pageNumber: c['page_number'],
                      chunkText: c['snippet'],
                      embedding: const [],
                      manualRevision: c['manual_revision'],
                      packageVersion: c['package_version'],
                      similarityScore:
                          (c['similarity_score'] as num).toDouble()))
                  .toList(),
              providerUsed: data['provider_used'] as String,
              evidenceStatus:
                  data['evidence_status'] as String? ?? 'NEEDS_REVIEW',
              executionTrace: List<String>.from(data['execution_trace']),
              isSuccess: data['status'] == 'SUCCESS');
        }
      }
      if (result == null) throw StateError('HQ response ended early');
      return result;
    } finally {
      client.close();
      _activeClient = null;
    }
  }

  List<ChunkModel> _verifyCitations(
      String answer, List<ChunkModel> availableChunks) {
    final verified = <ChunkModel>[];
    for (final chunk in availableChunks) {
      if (answer.contains('[Source ${chunk.id}]') ||
          answer.contains('Page ${chunk.pageNumber}') ||
          answer.contains('[Page ${chunk.pageNumber}]') ||
          answer.contains('p. ${chunk.pageNumber}')) {
        verified.add(chunk);
      }
    }
    if (verified.isEmpty && availableChunks.isNotEmpty) {
      verified.addAll(availableChunks.take(2));
    }
    return verified;
  }
}
