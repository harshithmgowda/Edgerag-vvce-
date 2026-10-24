import 'dart:io';
import 'package:flutter_edge_ai/flutter_edge_ai.dart';
import 'package:flutter_edge_ai_litertlm/flutter_edge_ai_litertlm.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'model_registry_service.dart';
import 'prompt_budget.dart';

/// Owns the single native inference lane, including media and cancellation.
/// Features warm-model retention and Vulkan GPU acceleration matching Google AI Edge Gallery.
class EdgeRuntime {
  static final EdgeRuntime _instance = EdgeRuntime._();
  factory EdgeRuntime() => _instance;
  EdgeRuntime._();

  Future<void>? _initialization;
  InferenceChat? _chat;
  InferenceModel? _activeModel;
  String? _loadedModelPath;
  PreferredBackend _preferredBackend = PreferredBackend.gpu;

  bool _loadedImage = false, _loadedAudio = false;
  bool _busy = false;
  bool _cancelled = false;

  PreferredBackend get activeBackend => _preferredBackend;

  Future<void> cancel() async {
    _cancelled = true;
    await _chat?.stopGeneration();
  }

  /// Explicitly unload active model from RAM if memory needs to be freed
  Future<void> release() async {
    try {
      await _chat?.close();
    } catch (_) {}
    _chat = null;
    try {
      await _activeModel?.close();
    } catch (_) {}
    _activeModel = null;
    _loadedModelPath = null;
    _busy = false;
  }

  Stream<String> stream({
    required String prompt,
    String? systemPrompt,
    File? image,
    File? audio,
  }) async* {
    if (_busy) throw StateError('Another on-device request is running.');
    _busy = true;
    _cancelled = false;

    try {
      final registry = ModelRegistryService();
      await registry.scanInstalledModels();
      final profile = registry.getModel(audio != null
          ? registry.activeAudioModelId
          : image != null
              ? registry.activeVisionModelId
              : registry.activeChatModelId);
      final gemmaProfile = registry.getModel('gemma-4-e2b-it');
      bool isLiteRtFile(String? p) => p != null &&
          (p.endsWith('.litertlm') || p.endsWith('.bin') || p.endsWith('.tflite'));

      var path = isLiteRtFile(profile?.installedPath)
          ? profile!.installedPath
          : (isLiteRtFile(gemmaProfile?.installedPath) ? gemmaProfile!.installedPath : null);

      if (path == null || !await File(path).exists()) {
        final candidateDirs = <String>[];
        try {
          final docs = await getApplicationDocumentsDirectory();
          candidateDirs.add(p.join(docs.path, 'models'));
          candidateDirs.add(docs.path);
        } catch (_) {}
        try {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            candidateDirs.add(p.join(ext.path, 'models'));
            candidateDirs.add(ext.path);
          }
        } catch (_) {}
        candidateDirs.addAll([
          '/data/data/com.edgerag.mobile/app_flutter/models',
          '/data/data/com.edgerag.mobile/app_flutter',
          '/data/user/0/com.edgerag.mobile/app_flutter/models',
          '/data/user/0/com.edgerag.mobile/app_flutter',
          '/sdcard/Android/data/com.edgerag.mobile/files/models',
          '/storage/emulated/0/Android/data/com.edgerag.mobile/files/models',
          '/sdcard/Android/data/com.google.ai.edge.gallery/files/Gemma_4_E2B_it/6e5c4f1e395deb959c494953478fa5cec4b8008f',
        ]);

        const candidateNames = [
          'gemma-4-E2B-it.litertlm',
          'gemma-4-e2b-it.litertlm',
          'gemma-4-e2b-it.bin',
          'gemma-4-E2B-it.bin',
          'gemma-2b-it.litertlm',
          'gemma-2b-it.bin',
        ];

        for (final cd in candidateDirs) {
          for (final cname in candidateNames) {
            final candidate = File(p.join(cd, cname));
            if (await candidate.exists()) {
              path = candidate.path;
              break;
            }
          }
          if (path != null) break;
        }
      }

      if (path == null || !await File(path).exists()) {
        throw StateError(
            'Install and select a compatible Gemma model in Model Manager.');
      }

      // Initialize runtime engine
      _initialization ??=
          FlutterEdgeAi.initialize(inferenceEngines: const [LiteRtLmEngine()]);
      await _initialization;

      // Warm model reuse: keep loaded GPU model in memory across prompts!
      final needsReload = _activeModel == null ||
          _activeModel!.isClosed ||
          _loadedModelPath != path ||
          _loadedImage != (image != null) ||
          _loadedAudio != (audio != null);
      if (needsReload) {
        try {
          await _activeModel?.close();
        } catch (_) {}
        _activeModel = null;

        await FlutterEdgeAi.installModel(
          modelType: ModelType.gemma4,
          fileType: ModelFileType.litertlm,
        ).fromFile(path).install();

        if (_cancelled) throw StateError('Generation stopped.');

        // 1. Try Vulkan GPU acceleration first (matches Google AI Edge Gallery performance)
        try {
          _activeModel = await FlutterEdgeAi.getActiveModel(
            maxTokens: 4096,
            preferredBackend: PreferredBackend.gpu,
            preferredVisionBackend: PreferredBackend.gpu,
            supportImage: image != null,
            supportAudio: audio != null,
          );
          _preferredBackend = PreferredBackend.gpu;
        } catch (gpuErr) {
          _activeModel = await FlutterEdgeAi.getActiveModel(
            maxTokens: 4096,
            preferredBackend: PreferredBackend.cpu,
            supportImage: image != null,
            supportAudio: audio != null,
          );
          _preferredBackend = PreferredBackend.cpu;
        }
        _loadedModelPath = path;
        _loadedImage = image != null;
        _loadedAudio = audio != null;
      }

      if (_cancelled) throw StateError('Generation stopped.');

      // Close previous chat session before creating a new one
      try {
        await _chat?.close();
      } catch (_) {}

      // Count with a real session before adding any user text. Reserve room for
      // generated output, native chat-template tokens, and media embeddings.
      var instruction = systemPrompt ??
          'You are EdgeRAG. Be accurate and concise. Use clear Markdown.';
      final meter = await _activeModel!.createSession();
      String boundedPrompt;
      try {
        instruction = await fitPrompt(instruction, 320, meter.sizeInTokens);
        final systemTokens = await meter.sizeInTokens(instruction);
        final mediaReserve = image != null
            ? 1536
            : audio != null
                ? 1536
                : 0;
        boundedPrompt = await fitPrompt(prompt,
            4096 - 512 - 256 - mediaReserve - systemTokens, meter.sizeInTokens);
      } finally {
        await meter.close();
      }

      for (var attempt = 0; attempt < 2; attempt++) {
        var emitted = false;
        try {
          _chat = await _activeModel!.createChat(
              systemInstruction: instruction,
              supportImage: image != null,
              supportAudio: audio != null,
              maxOutputTokens: 512,
              temperature: 0.2,
              enableThinking: false);
          if (_cancelled) throw StateError('Generation stopped.');
          await _chat!.addQuery(Message(
              text: boundedPrompt,
              isUser: true,
              imageBytes: image == null ? null : await image.readAsBytes(),
              audioBytes: audio == null ? null : await audio.readAsBytes()));
          await for (final response in _chat!.generateChatResponseAsync()) {
            if (_cancelled) throw StateError('Generation stopped.');
            if (response is TextResponse && response.token.isNotEmpty) {
              emitted = true;
              yield response.token;
            }
          }
          if (!emitted) throw StateError('The model returned no text.');
          break;
        } catch (error) {
          final message = error.toString().toLowerCase();
          final contextOverflow = message.contains('token') &&
              (message.contains('too long') ||
                  message.contains('exceed') ||
                  message.contains('maximum'));
          if (attempt != 0 || emitted || _cancelled || !contextOverflow)
            rethrow;
          // Native media/template accounting can differ. Retry a fresh session
          // once with a smaller text budget; never concatenate partial answers.
          boundedPrompt =
              await fitPrompt(boundedPrompt, 384, _chat!.session.sizeInTokens);
          await _chat!.close();
          _chat = null;
        }
      }
    } finally {
      // Keep _activeModel in memory for subsequent instant responses!
      try {
        await _chat?.close();
      } catch (_) {}
      _chat = null;
      _busy = false;
    }
  }

  Future<String> generate({
    required String prompt,
    String? systemPrompt,
    File? image,
    File? audio,
  }) async {
    final buffer = StringBuffer();
    await for (final token in stream(
      prompt: prompt,
      systemPrompt: systemPrompt,
      image: image,
      audio: audio,
    )) {
      buffer.write(token);
    }
    return buffer.toString();
  }
}
