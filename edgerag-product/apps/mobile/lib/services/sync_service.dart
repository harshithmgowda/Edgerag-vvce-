import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import 'database_service.dart';
import 'network_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  final _dbService = DatabaseService();
  final _netService = NetworkService();
  http.Client? _activeDownloadClient;
  bool _downloadAborted = false;

  void cancelDownload() {
    _downloadAborted = true;
    _activeDownloadClient?.close();
  }

  /// Check available updates on Headquarters server
  Future<List<KnowledgePackageModel>> checkUpdates(String deviceId) async {
    final url = Uri.parse('${_netService.hqBaseUrl}/sync/check');
    
    // Fetch currently installed package versions from Database A
    final db = await _dbService.appDb;
    final rows = await db.query('installed_packages');
    final installedMap = <String, String>{};
    for (final r in rows) {
      installedMap[r['equipment_id'] as String] = r['version'] as String;
    }

    final payload = {
      'device_id': deviceId,
      'installed_packages': installedMap,
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to check sync updates: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final updates = (data['available_updates'] as List)
        .map((item) => KnowledgePackageModel.fromJson(item))
        .toList();

    return updates;
  }

  /// Download and atomically install a knowledge package
  Future<void> downloadAndInstallPackage(
    KnowledgePackageModel package, {
    Function(double progress)? onProgress,
  }) async {
    final downloadUrl = Uri.parse('${_netService.hqBaseUrl}/packages/${package.id}/download');
    final cacheDir = await getTemporaryDirectory();
    final stagingZipPath = p.join(cacheDir.path, 'staging_${package.id}.zip');

    _downloadAborted = false;
    final client = http.Client();
    _activeDownloadClient = client;

    try {
      // 1. Download stream to staging file
      final request = http.Request('GET', downloadUrl);
      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode} for package download');
      }

      final totalBytes = package.fileSizeBytes;
      int receivedBytes = 0;
      final fileSink = File(stagingZipPath).openWrite();

      await for (final chunk in response.stream) {
        if (_downloadAborted) {
          await fileSink.close();
          final zipFile = File(stagingZipPath);
          if (await zipFile.exists()) await zipFile.delete();
          throw StateError('Download cancelled; existing knowledge database retained intact.');
        }
        fileSink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0 && onProgress != null) {
          onProgress(receivedBytes / totalBytes);
        }
      }
      await fileSink.flush();
      await fileSink.close();

    // 2. Cryptographic SHA-256 Checksum Validation
    final downloadedBytes = await File(stagingZipPath).readAsBytes();
    final computedHash = sha256.convert(downloadedBytes).toString();

    if (computedHash.toLowerCase() != package.sha256Hash.toLowerCase()) {
      await File(stagingZipPath).delete();
      throw Exception('Security Checksum Failed! Expected: ${package.sha256Hash}, Computed: $computedHash');
    }

    // 3. Safe ZIP Extraction (Path Traversal / Zip-Slip Defense)
    final archive = ZipDecoder().decodeBytes(downloadedBytes);
    final docsDir = await getApplicationDocumentsDirectory();
    final stagingSqlitePath = p.join(cacheDir.path, 'staged_knowledge_${package.id}.db');

    bool foundSqlite = false;

    for (final file in archive) {
      final filename = file.name;

      // Zip-Slip security check
      if (filename.contains('..') || filename.startsWith('/') || filename.startsWith('\\')) {
        throw Exception('Path Traversal Security Violation detected in ZIP entry: $filename');
      }

      if (filename == 'knowledge.sqlite') {
        final content = file.content as List<int>;
        await File(stagingSqlitePath).writeAsBytes(content, flush: true);
        foundSqlite = true;
      }
    }

    if (!foundSqlite) {
      throw Exception('Corrupted knowledge package: missing knowledge.sqlite database inside bundle.');
    }

    final manifestEntry = archive.findFile('manifest.json');
    if (manifestEntry == null) throw StateError('Missing package manifest');
    final manifest = jsonDecode(utf8.decode(manifestEntry.content as List<int>)) as Map<String, dynamic>;
    if (manifest['schema_version'] != '1.0.0' || manifest['equipment_id'] != package.equipmentId ||
        manifest['version'] != package.version || manifest['chunk_count'] != package.chunkCount) {
      throw StateError('Package identity or schema mismatch');
    }
    final dbHash = sha256.convert(await File(stagingSqlitePath).readAsBytes()).toString();
    if (dbHash != manifest['sqlite_checksum_sha256']) throw StateError('Database checksum mismatch');
    final stagedDb = await openDatabase(stagingSqlitePath, readOnly: true, singleInstance: false);
    try {
      if ((await stagedDb.rawQuery('PRAGMA quick_check')).first.values.first != 'ok') throw StateError('Invalid database');
      final count = Sqflite.firstIntValue(await stagedDb.rawQuery('SELECT COUNT(*) FROM chunks'));
      final wrongEquipment = Sqflite.firstIntValue(await stagedDb.rawQuery('SELECT COUNT(*) FROM chunks WHERE equipment_id != ?', [package.equipmentId]));
      if (count != package.chunkCount || wrongEquipment != 0) throw StateError('Invalid package contents');
    } finally { await stagedDb.close(); }

    // 4. Immutable file, then a transactional active pointer. Old file stays usable on failure.
    final targetDbPath = p.join(docsDir.path, 'knowledge_${package.equipmentId}_${package.id}.db');
    
    // Close any cached connection to existing DB
    await _dbService.closeKnowledgeDb(package.equipmentId);

    // Atomic move / replace
    if (!await File(targetDbPath).exists()) {
      final candidate = File('$targetDbPath.partial');
      await File(stagingSqlitePath).copy(candidate.path);
      await candidate.rename(targetDbPath);
    } else if (sha256.convert(await File(targetDbPath).readAsBytes()).toString() != dbHash) {
      throw StateError('Existing package file differs from verified download');
    }

    // 5. Update Database A installation records
    final appDb = await _dbService.appDb;
    await appDb.insert(
      'installed_packages',
      {
        'equipment_id': package.equipmentId,
        'package_id': package.id,
        'db_path': targetDbPath,
        'version': package.version,
        'chunk_count': package.chunkCount,
        'installed_at': DateTime.now().toUtc().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Record successful installation in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_successful_sync', DateTime.now().toUtc().toIso8601String());
    await prefs.setString('installed_package_${package.equipmentId}', package.version);

    // Cleanup temp zip and staged files
    final zip = File(stagingZipPath);
    if (await zip.exists()) await zip.delete();
    final stagedSqliteFile = File(stagingSqlitePath);
    if (await stagedSqliteFile.exists()) await stagedSqliteFile.delete();
    } finally {
      client.close();
      _activeDownloadClient = null;
    }
  }

  /// Synchronize Offline Incidents Outbox to Headquarters
  Future<int> syncIncidents(String deviceId) async {
    final pending = await _dbService.getPendingIncidents();
    if (pending.isEmpty) return 0;

    final url = Uri.parse('${_netService.hqBaseUrl}/sync/incidents');
    final payload = {
      'device_id': deviceId,
      'sync_timestamp': DateTime.now().toUtc().toIso8601String(),
      'incidents': pending.map((i) => i.toJsonForSync()).toList(),
    };

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Incident sync rejected by server: ${response.body}');
    }

    final data = jsonDecode(response.body);
    final syncedIds = (data['synced_ids'] as List).cast<String>();

    await _dbService.markIncidentsSynced(syncedIds, DateTime.now());

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_successful_sync', DateTime.now().toUtc().toIso8601String());
    return syncedIds.length;
  }

  Future<String?> getLastSyncTimestamp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_successful_sync');
  }

  Future<Map<String, dynamic>?> getInstalledPackageInfo(String equipmentId) async {
    final db = await _dbService.appDb;
    final rows = await db.query('installed_packages', where: 'equipment_id = ?', whereArgs: [equipmentId]);
    return rows.isNotEmpty ? rows.first : null;
  }
}
