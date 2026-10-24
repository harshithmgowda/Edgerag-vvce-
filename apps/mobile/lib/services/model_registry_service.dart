import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/ai_model_profile.dart';
import 'gemini_service.dart';
import 'nvidia_service.dart';

class ModelRegistryService {
  static final ModelRegistryService _instance = ModelRegistryService._internal();
  factory ModelRegistryService() => _instance;
  ModelRegistryService._internal();

  final List<AiModelProfile> _registry = [
    AiModelProfile(
      id: 'gemma-4-e2b-it',
      displayName: 'Google Gemma 4 E2B IT',
      category: ModelCategory.multimodalGeneral,
      family: 'Gemma 4',
      format: ModelFormat.litertLm,
      engine: ModelInferenceEngine.edgeAiLiteRt,
      inputModalities: [Modality.text, Modality.image, Modality.audio, Modality.structuredJson],
      outputModalities: [Modality.text],
      supportsFunctionCalling: true,
      languageSupport: 'Multilingual (EN, ES, DE, FR, ZH, JA, HI)',
      minPlatform: 'Android 8.0+ (API 26+), arm64-v8a',
      estimatedRamMb: 1800,
      fileSizeBytes: 2280000000, // ~2.1 GB
      downloadUrl: 'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm',
      version: 'v1.0.0',
      sha256Checksum: 'Verify against the model publisher before import',
      hardwareBackend: 'Vulkan GPU / NPU / CPU (LiteRT-LM)',
      description: 'Google’s official on-device multimodal model for text, images, and audio reasoning.',
      isInstalled: false,
    ),
    AiModelProfile(
      id: 'qwen2.5-0.5b-instruct',
      displayName: 'Qwen 2.5 0.5B Instruct',
      category: ModelCategory.agenticReasoner,
      family: 'Qwen 2.5',
      format: ModelFormat.gguf,
      engine: ModelInferenceEngine.llamaCppFllama,
      inputModalities: [Modality.text, Modality.structuredJson],
      outputModalities: [Modality.text],
      supportsFunctionCalling: true,
      languageSupport: 'Multilingual (EN, ZH, ES, FR, DE, RU, JA)',
      minPlatform: 'Android 7.0+ (API 24+), arm64-v8a',
      estimatedRamMb: 650,
      fileSizeBytes: 491400032, // 468.6 MB
      downloadUrl: 'https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF',
      version: 'q4_k_m',
      sha256Checksum: 'Verify against the model publisher before import',
      hardwareBackend: 'arm64-v8a Clang Ninja with i8mm matrix acceleration',
      description: 'Ultra-compact offline reasoning engine with high speed and low memory on Pixel devices.',
    ),
    AiModelProfile(
      id: 'phi-3-mini-4k',
      displayName: 'Phi-3 Mini 4K Instruct',
      category: ModelCategory.agenticReasoner,
      family: 'Phi-3',
      format: ModelFormat.gguf,
      engine: ModelInferenceEngine.llamaCppFllama,
      inputModalities: [Modality.text, Modality.structuredJson],
      outputModalities: [Modality.text],
      supportsFunctionCalling: true,
      languageSupport: 'English & Technical Vocab',
      minPlatform: 'Android 8.0+, arm64-v8a',
      estimatedRamMb: 2400,
      fileSizeBytes: 2350000000,
      downloadUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf',
      version: 'q4_k_m',
      sha256Checksum: 'Verify against the model publisher before import',
      hardwareBackend: 'arm64-v8a NEON / Vulkan',
      description: 'Microsoft’s 3.8B parameter high-precision reasoning engine for technical manuals.',
    ),
    AiModelProfile(
      id: 'whisper-base-asr',
      displayName: 'Android Speech Recognition',
      category: ModelCategory.speechToText,
      family: 'Android speech service',
      format: ModelFormat.systemNative,
      engine: ModelInferenceEngine.speechRecognition,
      inputModalities: [Modality.audio],
      outputModalities: [Modality.text],
      supportsFunctionCalling: false,
      languageSupport: '99 Languages Auto-Detect',
      minPlatform: 'Android 8.0+',
      estimatedRamMb: 250,
      fileSizeBytes: 145000000,
      downloadUrl: 'https://huggingface.co/openai/whisper-base',
      version: 'v2024',
      sha256Checksum: 'Verify against the model publisher before import',
      hardwareBackend: 'Android Speech Subsystem / On-Device ASR',
      description: 'Live dictation using the installed Android speech service. Offline language availability depends on the device.',
    ),
    AiModelProfile(
      id: 'android-system-tts',
      displayName: 'System Neural TTS Voice',
      category: ModelCategory.textToSpeech,
      family: 'Android TTS',
      format: ModelFormat.systemNative,
      engine: ModelInferenceEngine.systemTts,
      inputModalities: [Modality.text],
      outputModalities: [Modality.audio],
      supportsFunctionCalling: false,
      languageSupport: 'System Default / Multilingual',
      minPlatform: 'Android Native',
      estimatedRamMb: 80,
      fileSizeBytes: 0,
      downloadUrl: 'system://android.speech.tts',
      version: 'system-built-in',
      sha256Checksum: 'system-native',
      hardwareBackend: 'Hardware Audio Synthesizer',
      description: 'Native low-latency voice synthesizer for hands-free troubleshooting assistant.',
      isInstalled: true, // Always ready on Android
    ),
    AiModelProfile(
      id: 'minilm-l6-v2-dense',
      displayName: 'all-MiniLM-L6-v2 Vectors',
      category: ModelCategory.denseEmbedding,
      family: 'MiniLM',
      format: ModelFormat.systemNative,
      engine: ModelInferenceEngine.cosineMatrix,
      inputModalities: [Modality.text],
      outputModalities: [Modality.structuredJson],
      supportsFunctionCalling: false,
      languageSupport: 'English & Technical Identifiers',
      minPlatform: 'All Android Devices',
      estimatedRamMb: 120,
      fileSizeBytes: 80000000,
      downloadUrl: 'local://knowledge.sqlite',
      version: 'v2',
      sha256Checksum: '384d-cosine-normalized',
      hardwareBackend: 'Embedded SQLite BLOB B-Tree',
      description: 'Precomputed package vectors. Mobile text retrieval currently uses lexical ranking.',
      isInstalled: false, // No on-device embedding runtime registered
    ),
    AiModelProfile(
      id: 'nvidia-nim-llama32-vision',
      displayName: 'NVIDIA NIM (Llama 3.2 11B Vision)',
      category: ModelCategory.cloudFallback,
      family: 'Llama 3.2 Vision',
      format: ModelFormat.restCloudApi,
      engine: ModelInferenceEngine.cloudProvider,
      inputModalities: [Modality.text, Modality.image, Modality.videoFrames],
      outputModalities: [Modality.text],
      supportsFunctionCalling: true,
      languageSupport: 'Multilingual Global',
      minPlatform: 'Wi-Fi / Hotspot connected',
      estimatedRamMb: 0,
      fileSizeBytes: 0,
      downloadUrl: 'https://integrate.api.nvidia.com/v1',
      version: 'meta/llama-3.2-11b-vision-instruct',
      sha256Checksum: 'api-authenticated',
      hardwareBackend: 'Cloud TensorRT-LLM Ultra-Fast (850ms)',
      description: 'High-capability multimodal cloud reasoning for complex schematic and diagram inspection.',
      isInstalled: false, // Verified from stored configuration during scan
    ),
    AiModelProfile(
      id: 'google-gemini-2flash',
      displayName: 'Google Gemini 2.0 Flash',
      category: ModelCategory.cloudFallback,
      family: 'Gemini',
      format: ModelFormat.restCloudApi,
      engine: ModelInferenceEngine.cloudProvider,
      inputModalities: [Modality.text, Modality.image, Modality.audio, Modality.videoFrames],
      outputModalities: [Modality.text],
      supportsFunctionCalling: true,
      languageSupport: 'Multilingual Global',
      minPlatform: 'Internet Connected',
      estimatedRamMb: 0,
      fileSizeBytes: 0,
      downloadUrl: 'https://generativelanguage.googleapis.com',
      version: 'gemini-2.0-flash',
      sha256Checksum: 'api-authenticated',
      hardwareBackend: 'Google Cloud TPU v5',
      description: 'Native multimodal cloud reasoner for long audio notes and dense document analysis.',
      isInstalled: false, // Verified from stored configuration during scan
    ),
  ];

  // Selected models per task - Gemma 4 E2B IT is default primary multimodal model
  String _activeChatModelId = 'gemma-4-e2b-it';
  String _activeVisionModelId = 'gemma-4-e2b-it';
  String _activeAudioModelId = 'gemma-4-e2b-it';
  String _activeTtsModelId = 'android-system-tts';

  String get activeChatModelId => _activeChatModelId;
  String get activeVisionModelId => _activeVisionModelId;
  String get activeAudioModelId => _activeAudioModelId;
  String get activeTtsModelId => _activeTtsModelId;

  List<AiModelProfile> get allModels => List.unmodifiable(_registry);

  AiModelProfile? getModel(String id) {
    try {
      return _registry.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<void> setActiveModelForTask(String task, String modelId) async {
    final model = getModel(modelId);
    final supported = task == 'tts' ? modelId == 'android-system-tts'
      : model?.isInstalled == true && (task == 'chat'
        ? model?.format == ModelFormat.gguf || model?.format == ModelFormat.litertLm
        : model?.format == ModelFormat.litertLm);
    if (!supported) throw StateError('Install a compatible model for this task first.');
    final prefs = await SharedPreferences.getInstance();
    switch (task) {
      case 'chat':
        _activeChatModelId = modelId;
        await prefs.setString('active_chat_model', modelId);
        break;
      case 'vision':
        _activeVisionModelId = modelId;
        await prefs.setString('active_vision_model', modelId);
        break;
      case 'audio':
        _activeAudioModelId = modelId;
        await prefs.setString('active_audio_model', modelId);
        break;
      case 'tts':
        _activeTtsModelId = modelId;
        await prefs.setString('active_tts_model', modelId);
        break;
    }
  }

  /// Scan storage to verify actual installed model files on device
  Future<void> scanInstalledModels() async {
    getModel('google-gemini-2flash')!.isInstalled = (await GeminiService().getApiKey())?.isNotEmpty == true;
    getModel('nvidia-nim-llama32-vision')!.isInstalled = (await NvidiaService().getApiKey()).isNotEmpty;
    final candidateDirs = <Directory>[];

    try {
      final docsDir = await getApplicationDocumentsDirectory();
      candidateDirs.add(Directory(p.join(docsDir.path, 'models')));
      candidateDirs.add(docsDir);
    } catch (_) {}

    try {
      final extDir = await getExternalStorageDirectory();
      if (extDir != null) {
        candidateDirs.add(Directory(p.join(extDir.path, 'models')));
        candidateDirs.add(extDir);
      }
    } catch (_) {}

    candidateDirs.addAll([
      Directory('/data/data/com.edgerag.mobile/app_flutter/models'),
      Directory('/data/data/com.edgerag.mobile/app_flutter'),
      Directory('/data/user/0/com.edgerag.mobile/app_flutter/models'),
      Directory('/data/user/0/com.edgerag.mobile/app_flutter'),
      Directory('/sdcard/Android/data/com.edgerag.mobile/files/models'),
      Directory('/storage/emulated/0/Android/data/com.edgerag.mobile/files/models'),
      Directory('/sdcard/Android/data/com.google.ai.edge.gallery/files/Gemma_4_E2B_it/6e5c4f1e395deb959c494953478fa5cec4b8008f'),
      Directory('/sdcard/Download/models'),
      Directory('/sdcard/Download'),
      Directory('/storage/emulated/0/Download/models'),
      Directory('/storage/emulated/0/Download'),
      Directory('/sdcard/models'),
      Directory('/storage/emulated/0/models'),
    ]);

    final foundFiles = <String, File>{};

    // Direct check for standard internal model files with highest priority
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      for (final fname in [
        'gemma-4-E2B-it.litertlm',
        'gemma-4-e2b-it.litertlm',
        'gemma-4-e2b-it.bin',
        'gemma-4-E2B-it.bin',
      ]) {
        final directGemma = File(p.join(docsDir.path, 'models', fname));
        if (await directGemma.exists()) {
          foundFiles['gemma-4-e2b-it.litertlm'] = directGemma;
          break;
        }
      }
      for (final qname in [
        'qwen2.5-0.5b-instruct-q4_k_m.gguf',
        'qwen2.5-0.5b-instruct.gguf',
      ]) {
        final directQwen = File(p.join(docsDir.path, 'models', qname));
        if (await directQwen.exists()) {
          foundFiles['qwen2.5-0.5b-instruct-q4_k_m.gguf'] = directQwen;
          break;
        }
      }
    } catch (_) {}

    for (final dir in candidateDirs) {
      try {
        if (await dir.exists()) {
          final entries = await dir.list().toList();
          for (final entry in entries) {
            if (entry is File) {
              final filename = p.basename(entry.path).toLowerCase();
              if (await entry.exists()) {
                foundFiles.putIfAbsent(filename, () => entry);
              }
            }
          }
        }
      } catch (_) {}
    }

    // Update profiles based on discovered files
    for (final model in _registry) {
      if (model.format == ModelFormat.restCloudApi || model.id == 'android-system-tts' || model.id == 'minilm-l6-v2-dense') {
        continue;
      }

      bool found = false;
      String? matchedPath;

      if (model.id == 'gemma-4-e2b-it') {
        for (final entry in foundFiles.entries) {
          final k = entry.key;
          final isCache = k.contains('cache') || k.contains('adapter') || k.contains('encoder');
          if (!isCache && (k.endsWith('.litertlm') || k.contains('gemma'))) {
            found = true;
            matchedPath = entry.value.path;
            break;
          }
        }
      } else if (model.id == 'qwen2.5-0.5b-instruct') {
        for (final entry in foundFiles.entries) {
          if (entry.key.contains('qwen') || (entry.key.endsWith('.gguf') && !entry.key.contains('phi'))) {
            found = true;
            matchedPath = entry.value.path;
            break;
          }
        }
      } else if (model.id == 'phi-3-mini-4k') {
        for (final entry in foundFiles.entries) {
          if (entry.key.contains('phi-3') && entry.key.endsWith('.gguf')) {
            found = true;
            matchedPath = entry.value.path;
            break;
          }
        }
      } else if (model.id == 'whisper-base-asr') {
        for (final entry in foundFiles.entries) {
          if (entry.key.contains('whisper') || entry.key.contains('moonshine')) {
            found = true;
            matchedPath = entry.value.path;
            break;
          }
        }
      }

      if (found && matchedPath != null && await File(matchedPath).exists()) {
        model.isInstalled = true;
        model.installedPath = matchedPath;
      } else {
        model.isInstalled = false;
        model.installedPath = null;
      }
    }

    // Load saved preferences with auto-fallback to an installed model
    try {
      final prefs = await SharedPreferences.getInstance();
      _activeChatModelId = prefs.getString('active_chat_model') ?? 'gemma-4-e2b-it';
      _activeVisionModelId = prefs.getString('active_vision_model') ?? 'gemma-4-e2b-it';
      _activeAudioModelId = prefs.getString('active_audio_model') ?? 'gemma-4-e2b-it';
      _activeTtsModelId = prefs.getString('active_tts_model') ?? 'android-system-tts';

      // Prioritize Google Gemma 4 E2B IT over all other local models when installed
      final gemma = getModel('gemma-4-e2b-it');
      if (gemma?.isInstalled == true) {
        _activeChatModelId = 'gemma-4-e2b-it';
        _activeVisionModelId = 'gemma-4-e2b-it';
        _activeAudioModelId = 'gemma-4-e2b-it';
        await prefs.setString('active_chat_model', 'gemma-4-e2b-it');
        await prefs.setString('active_vision_model', 'gemma-4-e2b-it');
        await prefs.setString('active_audio_model', 'gemma-4-e2b-it');
      } else {
        // Auto-validate: if current activeChatModel is not installed, select first installed model!
        final active = getModel(_activeChatModelId);
        if (active?.isInstalled != true) {
          final installedChat = _registry.where((m) => m.isInstalled && (m.format == ModelFormat.litertLm || m.format == ModelFormat.gguf)).firstOrNull;
          if (installedChat != null) {
            _activeChatModelId = installedChat.id;
            await prefs.setString('active_chat_model', installedChat.id);
          }
        }
      }
    } catch (_) {}
  }

  /// Toggle in-app activation of Gemma 4 E2B IT
  Future<void> toggleGemmaActivation(bool active) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gemma_4_activated', active);
    await scanInstalledModels();
    final gemma = getModel('gemma-4-e2b-it');
    if (active && gemma?.isInstalled != true) {
      throw StateError('Install the Gemma .litertlm file before activating it.');
    }
    if (active) {
      await setActiveModelForTask('chat', 'gemma-4-e2b-it');
      await setActiveModelForTask('vision', 'gemma-4-e2b-it');
      await setActiveModelForTask('audio', 'gemma-4-e2b-it');
    }
  }

  /// Get real model count for a specific category
  int getModelCountForCategory(String categoryKey) {
    switch (categoryKey) {
      case 'chat':
      case 'ai_chat':
        return _registry.where((m) => m.outputModalities.contains(Modality.text) && (m.isInstalled || m.format == ModelFormat.restCloudApi)).length;
      case 'agent':
      case 'agent_skills':
        return _registry.where((m) => m.supportsFunctionCalling && (m.isInstalled || m.format == ModelFormat.restCloudApi)).length;
      case 'image':
      case 'ask_image':
        return _registry.where((m) => m.inputModalities.contains(Modality.image) && (m.isInstalled || m.format == ModelFormat.restCloudApi)).length;
      case 'audio':
      case 'audio_scribe':
        return _registry.where((m) => m.inputModalities.contains(Modality.audio) && (m.isInstalled || m.format == ModelFormat.restCloudApi)).length;
      case 'video':
      case 'video_insights':
        return _registry.where((m) => (m.inputModalities.contains(Modality.videoFrames) || m.inputModalities.contains(Modality.image)) && (m.isInstalled || m.format == ModelFormat.restCloudApi)).length;
      case 'scanner':
      case 'document_scanner':
        return _registry.where((m) => m.inputModalities.contains(Modality.image) && (m.isInstalled || m.format == ModelFormat.restCloudApi)).length;
      case 'voice':
      case 'voice_assistant':
        return _registry.where((m) => (m.category == ModelCategory.speechToText || m.category == ModelCategory.textToSpeech)).length;
      case 'manager':
      case 'model_manager':
        return _registry.length;
      default:
        return 0;
    }
  }

  /// Get installed count for a specific category
  int getInstalledCountForCategory(String categoryKey) {
    switch (categoryKey) {
      case 'chat':
      case 'ai_chat':
        return _registry.where((m) => m.isInstalled && m.outputModalities.contains(Modality.text)).length;
      case 'agent':
      case 'agent_skills':
        return _registry.where((m) => m.isInstalled && m.supportsFunctionCalling).length;
      case 'image':
      case 'ask_image':
        return _registry.where((m) => m.isInstalled && m.inputModalities.contains(Modality.image)).length;
      case 'audio':
      case 'audio_scribe':
        return _registry.where((m) => m.isInstalled && m.inputModalities.contains(Modality.audio)).length;
      case 'video':
      case 'video_insights':
        return _registry.where((m) => m.isInstalled && (m.inputModalities.contains(Modality.videoFrames) || m.inputModalities.contains(Modality.image))).length;
      case 'scanner':
      case 'document_scanner':
        return _registry.where((m) => m.isInstalled && m.inputModalities.contains(Modality.image)).length;
      case 'voice':
      case 'voice_assistant':
        return _registry.where((m) => m.isInstalled && (m.category == ModelCategory.speechToText || m.category == ModelCategory.textToSpeech)).length;
      case 'manager':
      case 'model_manager':
        return _registry.where((m) => m.isInstalled).length;
      default:
        return 0;
    }
  }

  /// Delete an installed model file safely
  Future<bool> deleteModel(String modelId) async {
    final model = getModel(modelId);
    if (model == null || model.installedPath == null) return false;

    try {
      final file = File(model.installedPath!);
      if (await file.exists()) {
        await file.delete();
      }
      model.isInstalled = false;
      model.installedPath = null;
      return true;
    } catch (e) {
      debugPrint('Error deleting model: $e');
      return false;
    }
  }
}
