import 'dart:async';
import 'edge_runtime.dart';
import 'model_registry_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:fllama/fllama.dart';
import 'package:fllama/fllama_type.dart';
import '../models/models.dart';

class LocalAiService {
  static final LocalAiService _instance = LocalAiService._internal();
  factory LocalAiService() => _instance;
  LocalAiService._internal();

  bool _isModelReady = false;
  String _modelName = 'Google Gemma 4 E2B IT';
  String? _activeModelPath;

  bool get isModelReady => _isModelReady;
  String get modelName => _modelName;
  String? get modelPath => _activeModelPath;

  Future<void> checkModelReadiness() async {
    _isModelReady = false;
    _activeModelPath = null;
    final registry = ModelRegistryService();
    await registry.scanInstalledModels();

    // Priority 1: Check if Google Gemma 4 E2B IT is installed in the registry
    final gemma = registry.getModel('gemma-4-e2b-it');
    if (gemma?.isInstalled == true && gemma?.installedPath != null && await File(gemma!.installedPath!).exists()) {
      _activeModelPath = gemma.installedPath;
      _modelName = 'Google Gemma 4 E2B IT';
      _isModelReady = true;
      return;
    }

    // Priority 2: Direct scan for Google Gemma 4 E2B IT across candidate paths and extensions
    final gemmaFileNames = [
      'gemma-4-E2B-it.litertlm',
      'gemma-4-e2b-it.litertlm',
      'gemma-4-e2b-it.bin',
      'gemma-4-E2B-it.bin',
      'gemma-2b-it.litertlm',
      'gemma-2b-it.bin',
    ];
    final gemmaCandidateDirs = <String>[];
    try {
      final docs = await getApplicationDocumentsDirectory();
      gemmaCandidateDirs.add(p.join(docs.path, 'models'));
      gemmaCandidateDirs.add(docs.path);
    } catch (_) {}

    try {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        gemmaCandidateDirs.add(p.join(ext.path, 'models'));
        gemmaCandidateDirs.add(ext.path);
      }
    } catch (_) {}

    gemmaCandidateDirs.addAll([
      '/data/data/com.edgerag.mobile/app_flutter/models',
      '/data/data/com.edgerag.mobile/app_flutter',
      '/data/user/0/com.edgerag.mobile/app_flutter/models',
      '/data/user/0/com.edgerag.mobile/app_flutter',
      '/sdcard/Android/data/com.edgerag.mobile/files/models',
      '/storage/emulated/0/Android/data/com.edgerag.mobile/files/models',
      '/sdcard/Android/data/com.google.ai.edge.gallery/files/Gemma_4_E2B_it/6e5c4f1e395deb959c494953478fa5cec4b8008f',
      '/storage/emulated/0/Download',
      '/sdcard/Download',
    ]);

    for (final dir in gemmaCandidateDirs) {
      for (final fname in gemmaFileNames) {
        final f = File(p.join(dir, fname));
        if (await f.exists()) {
          _activeModelPath = f.path;
          _modelName = 'Google Gemma 4 E2B IT';
          _isModelReady = true;
          return;
        }
      }
    }

    // Priority 3: Other installed models in registry (e.g. Qwen 2.5, Phi-3)
    var activeModel = registry.getModel(registry.activeChatModelId);
    if (activeModel?.installedPath != null && await File(activeModel!.installedPath!).exists()) {
      _activeModelPath = activeModel.installedPath;
      _modelName = activeModel.displayName;
      _isModelReady = true;
      return;
    }

    for (final m in registry.allModels) {
      if (m.isInstalled && m.installedPath != null && await File(m.installedPath!).exists()) {
        _activeModelPath = m.installedPath;
        _modelName = m.displayName;
        _isModelReady = true;
        return;
      }
    }

    // Priority 4: Direct scan for Qwen 2.5 or any GGUF in app documents directory
    try {
      final docs = await getApplicationDocumentsDirectory();
      final qwenDirect = File(p.join(docs.path, 'models', 'qwen2.5-0.5b-instruct-q4_k_m.gguf'));
      if (await qwenDirect.exists()) {
        _activeModelPath = qwenDirect.path;
        _modelName = 'Qwen 2.5 0.5B Instruct';
        _isModelReady = true;
        return;
      }
      final modelsDir = Directory(p.join(docs.path, 'models'));
      if (await modelsDir.exists()) {
        final files = await modelsDir.list().toList();
        for (final entry in files) {
          if (entry is File && entry.path.endsWith('.gguf')) {
            _activeModelPath = entry.path;
            _modelName = p.basenameWithoutExtension(entry.path);
            _isModelReady = true;
            return;
          }
        }
      }
    } catch (_) {}
  }

  Future<void> cancel() async {
    await EdgeRuntime().cancel();
    if (_contextId != null) await Fllama.instance()!.stopCompletion(contextId: _contextId!);
  }

  double? _contextId;
  bool _generating = false;

  /// Run on-device inference via Google AI Edge LiteRT (Gemma) or llama.cpp (GGUF)
  Stream<String> generateLocalResponseStream({
    required String question,
    required List<ChunkModel> chunks,
    Function(String)? onStatus,
    String? systemPrompt,
  }) async* {
    if (_generating) throw StateError('A local response is already being generated.');
    await checkModelReadiness();
    if (!_isModelReady || _activeModelPath == null) {
      throw StateError('No local AI model found on device. Open Model Manager to verify installed models.');
    }

    final hasEvidence = chunks.isNotEmpty;
    final evidenceText = hasEvidence
        ? chunks.map((c) => '[Source ${c.id}] ${c.manualTitle}, Page ${c.pageNumber}:\n${c.chunkText}').join('\n\n')
        : '';

    final effectiveSystemPrompt = systemPrompt ?? (hasEvidence
        ? 'You are an expert on-device industrial engineering AI assistant running with Google AI Edge.\n'
          'Answer the question accurately and thoroughly using the provided manual evidence.\n'
          'Cite factual claims using exact [Source ID] tags.\n'
          'Use clear Markdown with section headings (###), bullet points, numbered steps, and clean indentation.\n'
          'Keep technical codes and values formatted in `backticks`.'
        : 'You are an expert on-device industrial engineering AI assistant running with Google AI Edge.\n'
          'Provide a clear, detailed, and professional engineering answer to the question.\n'
          'Use clear Markdown with section headings (###), bullet points, numbered procedural steps, and proper indentation.\n'
          'Highlight safety precautions, diagnostic checks, and best practices clearly.');

    final userPrompt = hasEvidence
        ? 'TECHNICAL EVIDENCE FROM EQUIPMENT MANUALS:\n$evidenceText\n\nQUESTION:\n$question'
        : question;

    // 1. LiteRT-LM (Google Gemma 4 E2B IT - matching Google AI Edge Gallery)
    final isLiteRt = _activeModelPath?.endsWith('.litertlm') == true ||
        _activeModelPath?.endsWith('.bin') == true ||
        _activeModelPath?.endsWith('.tflite') == true;
    if (isLiteRt) {
      onStatus?.call('Writing with $_modelName…');
      await for (final token in EdgeRuntime().stream(prompt: userPrompt, systemPrompt: effectiveSystemPrompt)) {
        yield token;
      }
      return;
    }

    // 2. GGUF via llama.cpp / Fllama
    _generating = true;
    final runtime = Fllama.instance()!;
    try {
      // Warm Context Reuse: Keep loaded model in memory so subsequent queries answer in milliseconds
      if (_contextId == null || _loadedModelPath != _activeModelPath) {
        if (_contextId != null) {
          try { await runtime.releaseContext(_contextId!); } catch (_) {}
          _contextId = null;
        }
        onStatus?.call('Warming up $_modelName…');
        final threads = Platform.numberOfProcessors >= 6 ? 6 : (Platform.numberOfProcessors >= 4 ? 4 : 2);
        final loaded = await runtime.initContext(
          _activeModelPath!,
          nCtx: 2048,
          nBatch: 512,
          nThreads: threads,
          useMlock: false,
        );
        _contextId = double.tryParse('${loaded?['contextId']}');
        if (_contextId == null) throw StateError('The GGUF model could not be loaded into memory.');
        _loadedModelPath = _activeModelPath;
      }

      String? prompt;
      try {
        prompt = await runtime.getFormattedChat(_contextId!, messages: [
          RoleContent(role: 'system', content: effectiveSystemPrompt),
          RoleContent(role: 'user', content: userPrompt),
        ]);
      } catch (_) {}

      prompt ??= "<|im_start|>system\n$effectiveSystemPrompt<|im_end|>\n<|im_start|>user\n$userPrompt<|im_end|>\n<|im_start|>assistant\n";

      onStatus?.call('Writing with $_modelName…');
      final tokens = StreamController<String>();
      var emitted = false;
      final subscription = runtime.onTokenStream?.listen((event) {
        if (event['function'] == 'completion') {
          final token = event['result']?['token']?.toString() ?? '';
          if (token.isNotEmpty && !tokens.isClosed) { emitted = true; tokens.add(token); }
        }
      });
      final completion = runtime.completion(
        _contextId!,
        prompt: prompt,
        temperature: .2,
        nPredict: 384,
        penaltyRepeat: 1.1,
        emitRealtimeCompletion: true,
        stop: [
          '<|im_end|>',
          '<|endoftext|>',
          '<|end|>',
          '<|eot_id|>',
          '\n\nUser:',
          '\n\nQuestion:',
          '### Question:',
        ],
      );
      unawaited(completion.then((response) {
        final answer = response?['text']?.toString().trim() ?? '';
        if (!emitted && answer.isNotEmpty) tokens.add(answer);
        if (!emitted && answer.isEmpty) tokens.addError(StateError('Local model returned an empty answer.'));
      }, onError: (Object error, StackTrace stack) { tokens.addError(error, stack); }).whenComplete(() async {
        await subscription?.cancel();
        await tokens.close();
      }));
      yield* tokens.stream;
    } finally {
      _generating = false;
    }
  }

  String? _loadedModelPath;

  /// Explicitly release model from memory if needed
  Future<void> release() async {
    if (_contextId != null) {
      try {
        await Fllama.instance()?.releaseContext(_contextId!);
      } catch (_) {}
      _contextId = null;
      _loadedModelPath = null;
    }
  }

  Future<String> generateOfflineResponse({required String prompt, String? systemPrompt,
      List<ChunkModel> chunks = const []}) async {
    final buffer = StringBuffer();
    await for (final token in generateLocalResponseStream(question: prompt, chunks: chunks,
        systemPrompt: systemPrompt)) { buffer.write(token); }
    if (buffer.isEmpty) throw StateError('The local model returned no answer.');
    return buffer.toString();
  }
}
