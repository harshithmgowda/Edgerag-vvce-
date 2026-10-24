enum Modality {
  text,
  image,
  audio,
  videoFrames,
  structuredJson,
}

enum ModelFormat {
  litertLm,
  gguf,
  systemNative,
  restCloudApi,
}

enum ModelInferenceEngine {
  edgeAiLiteRt,
  llamaCppFllama,
  systemTts,
  speechRecognition,
  cosineMatrix,
  cloudProvider,
}

enum ModelCategory {
  multimodalGeneral,
  agenticReasoner,
  visionLanguage,
  speechToText,
  textToSpeech,
  denseEmbedding,
  cloudFallback,
}

class AiModelProfile {
  final String id;
  final String displayName;
  final ModelCategory category;
  final String family;
  final ModelFormat format;
  final ModelInferenceEngine engine;
  final List<Modality> inputModalities;
  final List<Modality> outputModalities;
  final bool supportsFunctionCalling;
  final String languageSupport;
  final String minPlatform;
  final int estimatedRamMb;
  final int fileSizeBytes;
  final String downloadUrl;
  final String version;
  final String sha256Checksum;
  final String hardwareBackend;
  final String description;

  // Dynamic state
  bool isInstalled;
  String? installedPath;
  bool isCompatible;

  AiModelProfile({
    required this.id,
    required this.displayName,
    required this.category,
    required this.family,
    required this.format,
    required this.engine,
    required this.inputModalities,
    required this.outputModalities,
    required this.supportsFunctionCalling,
    required this.languageSupport,
    required this.minPlatform,
    required this.estimatedRamMb,
    required this.fileSizeBytes,
    required this.downloadUrl,
    required this.version,
    required this.sha256Checksum,
    required this.hardwareBackend,
    required this.description,
    this.isInstalled = false,
    this.installedPath,
    this.isCompatible = true,
  });

  String get fileSizeDisplay {
    if (fileSizeBytes <= 0) return 'Cloud / Native';
    final mb = fileSizeBytes / (1024 * 1024);
    if (mb >= 1024) {
      return '${(mb / 1024).toStringAsFixed(2)} GB';
    }
    return '${mb.toStringAsFixed(0)} MB';
  }

  String get ramDisplay => '$estimatedRamMb MB RAM';
}
