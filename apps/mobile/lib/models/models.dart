enum NetworkState {
  offlineAirgap,
  hqLanHotspot,
  publicInternetOnly,
  fullyConnected,
}

enum AiMode {
  offlineOnly,
  onlineAi,
  smartAuto,
}

enum IncidentSeverity {
  low,
  medium,
  high,
  critical,
}

enum SyncStatus {
  pending,
  synced,
  failed,
}

class EquipmentModel {
  final String id;
  final String name;
  final String modelNumber;
  final String manufacturer;
  final String serialNumber;
  final String? description;

  EquipmentModel({
    required this.id,
    required this.name,
    required this.modelNumber,
    required this.manufacturer,
    required this.serialNumber,
    this.description,
  });

  factory EquipmentModel.fromJson(Map<String, dynamic> json) {
    return EquipmentModel(
      id: json['id'],
      name: json['name'],
      modelNumber: json['model_number'],
      manufacturer: json['manufacturer'],
      serialNumber: json['serial_number'],
      description: json['description'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'model_number': modelNumber,
    'manufacturer': manufacturer,
    'serial_number': serialNumber,
    'description': description,
  };
}

class KnowledgePackageModel {
  final String id;
  final String equipmentId;
  final String version;
  final String packageFileName;
  final int fileSizeBytes;
  final String sha256Hash;
  final int chunkCount;
  final String encoderModel;
  final int vectorDimension;

  KnowledgePackageModel({
    required this.id,
    required this.equipmentId,
    required this.version,
    required this.packageFileName,
    required this.fileSizeBytes,
    required this.sha256Hash,
    required this.chunkCount,
    required this.encoderModel,
    required this.vectorDimension,
  });

  factory KnowledgePackageModel.fromJson(Map<String, dynamic> json) {
    return KnowledgePackageModel(
      id: json['id'],
      equipmentId: json['equipment_id'],
      version: json['version'],
      packageFileName: json['package_file_name'],
      fileSizeBytes: json['file_size_bytes'],
      sha256Hash: json['sha256_hash'],
      chunkCount: json['chunk_count'],
      encoderModel: json['encoder_model'] ?? 'all-MiniLM-L6-v2',
      vectorDimension: json['vector_dimension'] ?? 384,
    );
  }
}

class ChunkModel {
  final String id;
  final String manualId;
  final String manualTitle;
  final int pageNumber;
  final String chunkText;
  final List<double> embedding;
  final double similarityScore;
  final String? manualRevision;
  final String? packageVersion;

  ChunkModel({
    required this.id,
    required this.manualId,
    required this.manualTitle,
    required this.pageNumber,
    required this.chunkText,
    required this.embedding,
    this.similarityScore = 0.0,
    this.manualRevision,
    this.packageVersion,
  });
}

class IncidentModel {
  final String id; // Permanent RFC-4122 V4 UUID
  final String equipmentId;
  final String title;
  final String description;
  final IncidentSeverity severity;
  final DateTime recordedOfflineAt;
  final int? linkedManualPage;
  final String? citationChunkId;
  SyncStatus syncStatus;
  DateTime? syncedAt;

  IncidentModel({
    required this.id,
    required this.equipmentId,
    required this.title,
    required this.description,
    required this.severity,
    required this.recordedOfflineAt,
    this.linkedManualPage,
    this.citationChunkId,
    this.syncStatus = SyncStatus.pending,
    this.syncedAt,
  });

  Map<String, dynamic> toJsonForSync() => {
    'id': id,
    'equipment_id': equipmentId,
    'title': title,
    'description': description,
    'severity': severity.name.toUpperCase(),
    'recorded_offline_at': recordedOfflineAt.toUtc().toIso8601String(),
    'linked_manual_page': linkedManualPage,
    'citation_chunk_id': citationChunkId,
  };

  Map<String, dynamic> toDbMap() => {
    'id': id,
    'equipment_id': equipmentId,
    'title': title,
    'description': description,
    'severity': severity.name,
    'recorded_offline_at': recordedOfflineAt.toIso8601String(),
    'linked_manual_page': linkedManualPage,
    'citation_chunk_id': citationChunkId,
    'sync_status': syncStatus.name,
    'synced_at': syncedAt?.toIso8601String(),
  };

  factory IncidentModel.fromDbMap(Map<String, dynamic> map) {
    return IncidentModel(
      id: map['id'],
      equipmentId: map['equipment_id'],
      title: map['title'],
      description: map['description'],
      severity: IncidentSeverity.values.firstWhere(
        (e) => e.name == map['severity'],
        orElse: () => IncidentSeverity.medium,
      ),
      recordedOfflineAt: DateTime.parse(map['recorded_offline_at']),
      linkedManualPage: map['linked_manual_page'],
      citationChunkId: map['citation_chunk_id'],
      syncStatus: SyncStatus.values.firstWhere(
        (e) => e.name == map['sync_status'],
        orElse: () => SyncStatus.pending,
      ),
      syncedAt: map['synced_at'] != null ? DateTime.parse(map['synced_at']) : null,
    );
  }
}

class ChatMessageModel {
  final String id;
  final String conversationId;
  final bool isUser;
  final String content;
  final DateTime timestamp;
  final List<ChunkModel> citations;
  final String providerUsed;
  final String evidenceStatus;

  ChatMessageModel({
    required this.id,
    required this.conversationId,
    required this.isUser,
    required this.content,
    required this.timestamp,
    this.citations = const [],
    this.providerUsed = 'Offline Local LLM',
    this.evidenceStatus = 'MANUAL_SUPPORTED',
  });
}

class ConversationModel {
  final String id;
  final String equipmentId;
  final String title;
  final DateTime createdAt;
  final DateTime lastUpdatedAt;

  ConversationModel({
    required this.id,
    required this.equipmentId,
    required this.title,
    required this.createdAt,
    required this.lastUpdatedAt,
  });
}
