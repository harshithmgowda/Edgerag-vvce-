import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../models/models.dart';
import 'model_registry_service.dart';
import 'local_ai_service.dart';
import 'gemini_service.dart';
import 'nvidia_service.dart';
import 'database_service.dart';
import 'network_service.dart';
import 'edge_runtime.dart';
import 'audio_chunks.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart';

class MultimodalAnalysisResult {
  final String textResponse;
  final List<String> visualObservations;
  final List<ChunkModel> citations;
  final String usedModelName;
  final bool isOffline;
  final int latencyMs;

  MultimodalAnalysisResult({
    required this.textResponse,
    required this.visualObservations,
    required this.citations,
    required this.usedModelName,
    required this.isOffline,
    required this.latencyMs,
  });
}

class MultimodalAiService {
  static final MultimodalAiService _instance = MultimodalAiService._internal();
  factory MultimodalAiService() => _instance;
  MultimodalAiService._internal();

  final _modelRegistry = ModelRegistryService();
  final _localAi = LocalAiService();
  final _geminiService = GeminiService();
  final _dbService = DatabaseService();
  final _netService = NetworkService();

  // TTS
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;
  bool get isSpeaking => _isSpeaking;

  // STT
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _speechInitialized = false;

  Future<void> init() async {
    await _modelRegistry.scanInstalledModels();

    // Initialize TTS
    try {
      await _flutterTts.setLanguage('en-US');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setVolume(1.0);
      await _flutterTts.setPitch(1.0);

      _flutterTts.setStartHandler(() => _isSpeaking = true);
      _flutterTts.setCompletionHandler(() => _isSpeaking = false);
      _flutterTts.setErrorHandler((_) => _isSpeaking = false);
    } catch (e) {
      debugPrint('TTS init warning: $e');
    }

    // Initialize STT
    try {
      _speechInitialized = await _speechToText.initialize(
        onError: (e) => debugPrint('STT error: $e'),
      );
    } catch (e) {
      debugPrint('STT init warning: $e');
    }
  }

  // ===================== TTS OPERATIONS =====================
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    try {
      // Strip markdown symbols for clean speech synthesis
      final cleanText = text
          .replaceAll(RegExp(r'\*\*|__|\*|_|`|#|>|\[.*?\]\(.*?\)'), '')
          .replaceAll(RegExp(r'\n+'), ' ')
          .trim();
      await _flutterTts.awaitSpeakCompletion(true);
      await _flutterTts.speak(cleanText);
    } catch (e) {
      throw StateError('Speech output unavailable: $e');
    }
  }

  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
      _isSpeaking = false;
    } catch (_) {}
  }

  // ===================== STT OPERATIONS =====================
  bool get isSpeechAvailable => _speechInitialized;

  Future<bool> startListening({
    required Function(String recognizedWords) onResult,
    String? localeId,
    bool offlineOnly = false,
    void Function()? onDone,
  }) async {
    if (!_speechInitialized) {
      _speechInitialized = await _speechToText.initialize(
        onError: (err) => debugPrint('STT init error: ${err.errorMsg}'),
        onStatus: (status) => debugPrint('STT init status: $status'),
      );
      if (!_speechInitialized) return false;
    }

    try {
      final listenOptions = stt.SpeechListenOptions(
        listenMode: stt.ListenMode.dictation,
        cancelOnError: false,
        partialResults: true,
        onDevice: false,
        localeId: localeId,
      );
      await _speechToText.listen(
        onResult: (result) {
          if (result.finalResult) onDone?.call();
          if (result.recognizedWords.isNotEmpty) {
            onResult(result.recognizedWords);
          }
        },
        listenOptions: listenOptions,
      );
      return _speechToText.isListening;
    } catch (e) {
      debugPrint('STT listening error: $e');
      return false;
    }
  }

  Future<void> stopListening() async {
    try {
      await _speechToText.stop();
    } catch (_) {}
  }

  static const mediaChannel = MethodChannel('com.edgerag.mobile/media');

  bool get _internet =>
      _netService.currentState == NetworkState.publicInternetOnly ||
      _netService.currentState == NetworkState.fullyConnected;

  Future<MultimodalAnalysisResult> analyzeImage(
      {required File imageFile,
      required String question,
      required String equipmentId,
      AiMode aiMode = AiMode.smartAuto,
      String cloudProvider = 'auto'}) async {
    final watch = Stopwatch()..start();
    final citations =
        await _dbService.searchKnowledgeChunks(equipmentId, question, limit: 3);
    final prompt =
        '$question\n\nManual evidence (cite exact Source tags):\n${citations.map((c) => '[Source ${c.id}] ${c.chunkText}').join('\n')}\n'
        'Separate visible observations from manual recommendations. Do not invent unreadable labels or unsupported procedures.';
    String text;
    String model;
    var offline = true;
    if (aiMode == AiMode.onlineAi ||
        (aiMode == AiMode.smartAuto && _internet)) {
      try {
        final encoded = base64Encode(await imageFile.readAsBytes());
        if (cloudProvider == 'gemini') {
          text = await _geminiService.generateResponse(
              prompt: prompt,
              base64Image: encoded,
              mimeType: _mime(imageFile.path));
          model = await _geminiService.getSelectedModel();
        } else {
          final nvidia = NvidiaService();
          try {
            text = await nvidia.generateChatCompletion(
                systemPrompt: 'Use accurate, readable Markdown.',
                userPrompt: prompt,
                base64Image: encoded,
                mimeType: _mime(imageFile.path));
            model = NvidiaService.visionModel;
          } catch (_) {
            if (cloudProvider == 'nvidia') rethrow;
            text = await _geminiService.generateResponse(
                prompt: prompt,
                base64Image: encoded,
                mimeType: _mime(imageFile.path));
            model = await _geminiService.getSelectedModel();
          }
        }
        offline = false;
      } catch (_) {
        if (aiMode == AiMode.onlineAi || cloudProvider != 'auto') rethrow;
        text = await EdgeRuntime().generate(prompt: prompt, image: imageFile);
        model = 'Gemma 4 E2B IT (local vision)';
      }
    } else {
      text = await EdgeRuntime().generate(prompt: prompt, image: imageFile);
      model = 'Gemma 4 E2B IT (local vision)';
    }

    final observations = <String>[];
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if ((trimmed.startsWith('- ') ||
              trimmed.startsWith('* ') ||
              RegExp(r'^\d+\.').hasMatch(trimmed)) &&
          trimmed.length > 5) {
        observations.add(trimmed.replaceFirst(RegExp(r'^[-*\d\.]+\s*'), ''));
      }
    }
    if (observations.isEmpty && text.isNotEmpty) {
      observations.add(text.split('\n').firstWhere((l) => l.trim().isNotEmpty,
          orElse: () => 'Visual inspection complete.'));
    }

    return MultimodalAnalysisResult(
        textResponse: text,
        visualObservations: observations,
        citations:
            citations.where((c) => text.contains('[Source ${c.id}]')).toList(),
        usedModelName: model,
        isOffline: offline,
        latencyMs: watch.elapsedMilliseconds);
  }

  String _mime(String path) {
    final extension = path.split('.').last.toLowerCase();
    return {
          'png': 'image/png',
          'webp': 'image/webp',
          'wav': 'audio/wav',
          'mp3': 'audio/mpeg',
          'm4a': 'audio/mp4',
          'aac': 'audio/aac',
          'ogg': 'audio/ogg',
          'flac': 'audio/flac'
        }[extension] ??
        'image/jpeg';
  }

  Future<String> transcribeAudio(File file, AiMode mode) async {
    if (await file.length() > 20 * 1024 * 1024)
      throw StateError('Use an audio file smaller than 20 MB.');
    const prompt =
        'Transcribe the attached audio verbatim. Return only words actually heard. Mark unclear speech as [inaudible].';
    if (mode == AiMode.onlineAi || (mode == AiMode.smartAuto && _internet)) {
      try {
        return await _geminiService.generateResponse(
            prompt: prompt,
            base64Image: base64Encode(await file.readAsBytes()),
            mimeType: _mime(file.path));
      } catch (_) {
        if (mode == AiMode.onlineAi) rethrow;
      }
    }
    final decoded = await mediaChannel
        .invokeMethod<String>('decodeAudio', {'path': file.path});
    if (decoded == null)
      throw StateError(
          'Audio could not be decoded. Try a WAV or M4A recording.');
    final wav = File(decoded);
    try {
      final segments = splitPcmWave(await wav.readAsBytes());
      final directory = await getTemporaryDirectory();
      final answers = <String>[];
      for (var i = 0; i < segments.length; i++) {
        final part = File(
            '${directory.path}/edgerag_segment_${DateTime.now().microsecondsSinceEpoch}_$i.wav');
        try {
          await part.writeAsBytes(segments[i]);
          answers
              .add(await EdgeRuntime().generate(prompt: prompt, audio: part));
        } finally {
          if (await part.exists()) await part.delete();
        }
      }
      return answers.join(' ');
    } finally {
      if (wav.path != file.path && await wav.exists()) await wav.delete();
    }
  }

  Future<String> transformText(String text, String instruction, AiMode mode,
      {String cloudProvider = 'auto'}) async {
    if (mode == AiMode.onlineAi || (mode == AiMode.smartAuto && _internet)) {
      try {
        if (cloudProvider == 'nvidia')
          return await NvidiaService().generateChatCompletion(
              systemPrompt: instruction, userPrompt: text);
        try {
          return await _geminiService.generateResponse(
              prompt: text, systemInstruction: instruction);
        } catch (_) {
          if (cloudProvider == 'gemini') rethrow;
          return await NvidiaService().generateChatCompletion(
              systemPrompt: instruction, userPrompt: text);
        }
      } catch (_) {
        if (mode == AiMode.onlineAi) rethrow;
      }
    }
    return _localAi.generateOfflineResponse(
        prompt: text, systemPrompt: instruction);
  }

  Future<MultimodalAnalysisResult> analyzeVideoFrames(
      {required List<File> frames,
      required List<int> timestampsMs,
      required String question,
      required String equipmentId,
      AiMode aiMode = AiMode.smartAuto,
      String cloudProvider = 'auto'}) async {
    if (frames.isEmpty || frames.length != timestampsMs.length)
      throw StateError('No valid timestamped video frames.');
    final watch = Stopwatch()..start();

    final results = <MultimodalAnalysisResult>[];
    for (var i = 0; i < frames.length; i++) {
      results.add(await analyzeImage(
          imageFile: frames[i],
          question:
              'Frame at ${timestampsMs[i] / 1000}s. $question. Describe only this still frame; do not infer motion.',
          equipmentId: equipmentId,
          aiMode: aiMode,
          cloudProvider: cloudProvider));
    }
    final allObservations = [
      'Sampled ${frames.length} frames across timeline (${timestampsMs.map((t) => '${(t / 1000).toStringAsFixed(1)}s').join(', ')}).',
      ...results.expand((r) => r.visualObservations).take(4),
    ];
    return MultimodalAnalysisResult(
        textResponse: List.generate(
                results.length,
                (i) =>
                    '### Frame at ${(timestampsMs[i] / 1000).toStringAsFixed(1)}s\n\n${results[i].textResponse}')
            .join('\n\n'),
        visualObservations: allObservations,
        citations: {
          for (final r in results)
            for (final c in r.citations) c.id: c
        }.values.toList(),
        usedModelName: results.map((r) => r.usedModelName).toSet().join(', '),
        isOffline: results.every((r) => r.isOffline),
        latencyMs: watch.elapsedMilliseconds);
  }

  Future<MultimodalAnalysisResult> scanDocumentAndLookup(
      {required File documentImage,
      required String equipmentId,
      AiMode aiMode = AiMode.smartAuto,
      String cloudProvider = 'auto'}) async {
    final watch = Stopwatch()..start();
    String? text;
    var extractionModel = 'On-device document OCR';
    var extractionOffline = true;
    try {
      text = await mediaChannel
          .invokeMethod<String>('recognizeText', {'path': documentImage.path});
    } catch (_) {}

    if (text == null || text.trim().isEmpty) {
      try {
        final visionResult = await analyzeImage(
          imageFile: documentImage,
          question:
              'Extract all legible serial numbers, model identifiers, error codes, and technical ratings from this document.',
          equipmentId: equipmentId,
          aiMode: aiMode,
          cloudProvider: cloudProvider,
        );
        text = visionResult.textResponse;
        extractionModel = visionResult.usedModelName;
        extractionOffline = visionResult.isOffline;
      } catch (_) {
        throw StateError(
            'No readable text found. Try a sharper, well-lit photo.');
      }
    }

    return MultimodalAnalysisResult(
        textResponse: text,
        visualObservations: [
          'Extracted document text. Check recognition of numbers before use.'
        ],
        citations: [],
        usedModelName: extractionModel,
        isOffline: extractionOffline,
        latencyMs: watch.elapsedMilliseconds);
  }
}
