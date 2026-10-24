import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/models.dart';

class NvidiaService {
  static final NvidiaService _instance = NvidiaService._internal();
  factory NvidiaService() => _instance;
  NvidiaService._internal();

  final _secureStorage = const FlutterSecureStorage();
  static const _keyStorageId = 'byok_nvidia_key';
  static const _modelStorageId = 'byok_nvidia_model';

  static const String defaultKey =
      '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';
  static const String defaultModel = 'meta/llama-3.2-11b-vision-instruct';
  static const String visionModel = 'meta/llama-3.2-11b-vision-instruct';

  Future<void> saveApiKey(String apiKey, {String model = defaultModel}) async {
    await _secureStorage.write(key: _keyStorageId, value: apiKey);
    await _secureStorage.write(key: _modelStorageId, value: model);
  }

  Future<String> getApiKey() async {
    final key = await _secureStorage.read(key: _keyStorageId);
    return (key != null && key.isNotEmpty) ? key : defaultKey;
  }

  Future<String> getSelectedModel() async {
    final model = await _secureStorage.read(key: _modelStorageId);
    if (model == null || model.isEmpty) {
      return defaultModel;
    }
    return model;
  }

  Future<bool> hasKey() async {
    final key = await getApiKey();
    return key.isNotEmpty;
  }

  /// Live connection test against NVIDIA NIM
  Future<({bool success, String message, int latencyMs})> testConnection(
    String apiKey, {
    String model = defaultModel,
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final url =
          Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');
      final isNemotron = model.toLowerCase().contains('nemotron');

      final bodyMap = <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'user', 'content': 'Ping test. Respond with OK.'}
        ],
        'max_tokens': isNemotron ? 32 : 16,
        'temperature': 0.1,
      };
      if (isNemotron) {
        bodyMap['chat_template_kwargs'] = {'enable_thinking': false};
      }

      final response = await http
          .post(
            url,
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(bodyMap),
          )
          .timeout(const Duration(seconds: 15));

      stopwatch.stop();

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final firstChoice = data['choices']?[0];
        final message = firstChoice?['message'];
        final answer = message?['content']?.toString().trim() ??
            message?['reasoning_content']?.toString().trim() ??
            'OK';
        return (
          success: true,
          message: 'NVIDIA NIM verified! ($answer)',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      } else {
        String msg = response.body;
        try {
          final err = jsonDecode(response.body);
          msg = err['detail'] ??
              err['error']?['message'] ??
              err['title'] ??
              response.body;
        } catch (_) {}
        return (
          success: false,
          message: 'NVIDIA NIM Error (${response.statusCode}): $msg',
          latencyMs: stopwatch.elapsedMilliseconds,
        );
      }
    } catch (e) {
      stopwatch.stop();
      return (
        success: false,
        message: 'Connection failed: $e',
        latencyMs: stopwatch.elapsedMilliseconds,
      );
    }
  }

  /// Real-time streaming Grounded RAG with retrieved chunks via NVIDIA NIM SSE
  Stream<String> generateGroundedAnswerStream({
    required String question,
    required List<ChunkModel> retrievedChunks,
    Function(String status)? onStatus,
    String? instruction,
  }) async* {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      throw Exception('NVIDIA NIM API key is not configured.');
    }

    final model = await getSelectedModel();
    final url =
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');

    final evidenceText = retrievedChunks.isNotEmpty
        ? retrievedChunks.map((c) {
            return '[Source ${c.id}] ${c.manualTitle}, Page ${c.pageNumber}\n${c.chunkText}\n';
          }).join('\n---\n')
        : 'No specific manual passages found for this equipment in local database. Rely on verified industrial safety and technical best practices.';

    final systemInstruction = instruction ??
        '''
You are the EdgeRAG Master Industrial & Diagnostic AI powered by NVIDIA Nemotron 3 Ultra (550B).
Your objective is to provide an expertly structured, pristine, and citation-grounded response to the technician.

CRITICAL FORMATTING INSTRUCTIONS:
1. Direct Executive Summary:
   - Begin with a bold, concise executive summary answering the question directly in 1-2 punchy sentences.
2. Structured Markdown Headings:
   - Use ### and #### section headings to logically separate domains (e.g., ### 1. Diagnostic Overview, ### 2. Step-by-Step Action Plan, ### 3. Technical Specifications, ### 4. Safety & Compliance).
3. Step-by-Step Procedures:
   - When describing troubleshooting, maintenance, calibration, or assembly, use numbered steps:
     1. **Action Title**: Detailed instruction.
     2. **Action Title**: Detailed instruction.
4. Clean Bullet Points & Technical Data:
   - Use bold lead-ins for bullets (e.g. - **Sensor Voltage**: 4.8V to 5.2V).
   - Use Markdown tables for multi-parameter specifications, tolerances, or thresholds.
5. Safety Warnings & Advisories:
   - Use blockquotes for critical safety points:
     > ⚠️ **CAUTION**: Wear proper PPE and depressurize hydraulic circuits before opening relief valves.
6. Factual Grounding & Verifiable Citations:
   - Answer using the verified manual evidence excerpts provided. Treat evidence strictly as facts.
   - For EVERY technical specification, procedure, step, value, or warning derived from evidence, explicitly append the exact source tag: `[Source CHUNK_ID]` (for example `[Source 101]`).
   - If manual evidence is silent or partial, state clearly what is known from evidence, state what is missing, and provide safe standard guidance.
7. Output Quality:
   - Professional, authoritative, and directly actionable for field technicians and engineers. No unformatted text or messy dumps.
''';

    final userContent = '''
=== VERIFIED MANUAL EVIDENCE EXCERPTS ===
$evidenceText

=== TECHNICIAN QUESTION ===
$question
''';

    final isNemotron = model.toLowerCase().contains('nemotron');
    final client = http.Client();
    try {
      final request = http.Request('POST', url);
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      });

      final bodyMap = <String, dynamic>{
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemInstruction},
          {'role': 'user', 'content': userContent},
        ],
        'temperature': 0.2,
        'max_tokens': 1024,
        'stream': true,
      };
      if (isNemotron) {
        bodyMap['chat_template_kwargs'] = {'enable_thinking': false};
      }

      request.body = jsonEncode(bodyMap);

      onStatus?.call('Streaming verified answer from NVIDIA NIM…');
      final streamedResponse =
          await client.send(request).timeout(const Duration(seconds: 20));

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        String msg = errorBody;
        try {
          final err = jsonDecode(errorBody);
          msg = err['detail'] ?? err['error']?['message'] ?? errorBody;
        } catch (_) {}
        throw Exception(
            'NVIDIA NIM API error (${streamedResponse.statusCode}): $msg');
      }

      bool hasStreamedContent = false;
      bool hasShownThinking = false;
      final lineStream = streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .timeout(const Duration(seconds: 45));

      await for (final line in lineStream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed == 'data: [DONE]') break;
        if (!trimmed.startsWith('data: ')) continue;

        final jsonStr = trimmed.substring(6).trim();
        if (jsonStr.isEmpty) continue;

        try {
          final eventData = jsonDecode(jsonStr);
          final choices = eventData['choices'] as List?;
          if (choices == null || choices.isEmpty) continue;

          final delta = choices[0]['delta'] as Map<String, dynamic>?;
          if (delta == null) continue;

          final reasoning = delta['reasoning_content']?.toString();
          if (reasoning != null &&
              reasoning.isNotEmpty &&
              !hasStreamedContent) {
            if (!hasShownThinking) {
              hasShownThinking = true;
              onStatus?.call('🧠 Analyzing evidence & reasoning…');
            }
          }

          final content = delta['content']?.toString();
          if (content != null && content.isNotEmpty) {
            if (!hasStreamedContent) {
              hasStreamedContent = true;
              onStatus?.call('✍️ Formulating verified answer…');
            }
            yield content;
          }

          final finishReason = choices[0]['finish_reason']?.toString();
          if (finishReason != null &&
              finishReason != 'null' &&
              finishReason.isNotEmpty) {
            break;
          }
        } catch (_) {
          // ignore malformed chunk
        }
      }
    } finally {
      client.close();
    }
  }

  /// Execute Online Grounded RAG with retrieved chunks via NVIDIA NIM (returns complete String)
  Future<String> generateGroundedAnswer({
    required String question,
    required List<ChunkModel> retrievedChunks,
    Function(String status)? onStatus,
  }) async {
    final buffer = StringBuffer();
    await for (final token in generateGroundedAnswerStream(
      question: question,
      retrievedChunks: retrievedChunks,
      onStatus: onStatus,
    )) {
      buffer.write(token);
    }
    final answer = buffer.toString().trim();
    if (answer.isEmpty) {
      throw Exception('NVIDIA NIM returned an empty response.');
    }
    return answer;
  }

  /// Multimodal and flexible chat completion supporting base64 images
  Future<String> generateChatCompletion({
    required String systemPrompt,
    required String userPrompt,
    String? base64Image,
    String mimeType = 'image/jpeg',
  }) async {
    final apiKey = await getApiKey();
    if (apiKey.isEmpty) {
      throw Exception('NVIDIA NIM API key is not configured.');
    }

    final selected = await getSelectedModel();
    // Nemotron 3 Ultra is text-reasoning; route vision requests to multimodal vision model
    final targetModel = (base64Image != null && base64Image.isNotEmpty)
        ? visionModel
        : selected;

    final url =
        Uri.parse('https://integrate.api.nvidia.com/v1/chat/completions');

    final dynamic userContent;
    if (base64Image != null && base64Image.isNotEmpty) {
      userContent = [
        {'type': 'text', 'text': userPrompt},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:$mimeType;base64,$base64Image'},
        },
      ];
    } else {
      userContent = userPrompt;
    }

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': targetModel,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userContent},
            ],
            'temperature': 0.2,
            'max_tokens': 1024,
          }),
        )
        .timeout(const Duration(seconds: 45));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      String? text;
      if (choices != null && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map && first['message'] is Map) {
          text = first['message']['content']?.toString().trim() ??
              first['message']['reasoning_content']?.toString().trim();
        }
      }
      if (text == null || text.isEmpty)
        throw StateError('NVIDIA returned an empty answer.');
      return text;
    } else {
      throw Exception(
          'NVIDIA NIM Error (${response.statusCode}): ${response.body}');
    }
  }
}
