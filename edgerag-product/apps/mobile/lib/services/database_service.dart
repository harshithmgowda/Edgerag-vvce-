import 'knowledge_retrieval.dart';
import 'semantic_encoder.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../models/models.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _appDb;
  final Map<String, Database> _knowledgeDbCache = {};

  // =========================================================================
  // Database A: Writable Application Storage (app_data.db)
  // =========================================================================
  Future<Database> get appDb async {
    if (_appDb != null) return _appDb!;
    _appDb = await _initAppDb();
    return _appDb!;
  }

  Future<Database> _initAppDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'app_data.db');

    final appDbInstance = await openDatabase(
      dbPath,
      version: 3,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createExclusions(db);
        if (oldVersion < 3) await db.execute('ALTER TABLE installed_packages ADD COLUMN db_path TEXT');
      },
      onCreate: (db, version) async {
        await _createExclusions(db);
        // Incidents & Outbox table
        await db.execute('''
          CREATE TABLE incidents (
            id TEXT PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            title TEXT NOT NULL,
            description TEXT NOT NULL,
            severity TEXT NOT NULL,
            recorded_offline_at TEXT NOT NULL,
            linked_manual_page INTEGER,
            citation_chunk_id TEXT,
            sync_status TEXT NOT NULL,
            synced_at TEXT
          )
        ''');

        // Saved Conversations table
        await db.execute('''
          CREATE TABLE conversations (
            id TEXT PRIMARY KEY,
            equipment_id TEXT NOT NULL,
            title TEXT NOT NULL,
            created_at TEXT NOT NULL,
            last_updated_at TEXT NOT NULL
          )
        ''');

        // Messages table
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            conversation_id TEXT NOT NULL,
            is_user INTEGER NOT NULL,
            content TEXT NOT NULL,
            provider_used TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            FOREIGN KEY (conversation_id) REFERENCES conversations (id) ON DELETE CASCADE
          )
        ''');

        // Package Installation Records
        await db.execute('''
          CREATE TABLE installed_packages (
            equipment_id TEXT PRIMARY KEY,
            package_id TEXT NOT NULL,
            version TEXT NOT NULL,
            chunk_count INTEGER NOT NULL,
            installed_at TEXT NOT NULL,
            db_path TEXT
          )
        ''');
      },
    );

    _appDb = appDbInstance;
    // New installations begin empty; only real downloaded manuals are used.

    return appDbInstance;
  }

  Future<void> _ensureStarterData(Database db) async {
    try {
      final rows = await db.query('installed_packages', where: 'equipment_id = ?', whereArgs: ['pump-01']);
      final docsDir = await getApplicationDocumentsDirectory();
      final targetPath = p.join(docsDir.path, 'knowledge_pump-01.db');
      final fileExists = await File(targetPath).exists();

      if (rows.isEmpty || !fileExists) {
        await seedStarterKnowledge(db);
      }

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('cached_equipment') == null) {
        final starterEquipment = [
          {
            'id': 'pump-01',
            'name': 'WARMAN AH Centrifugal Slurry Pump',
            'modelNumber': 'WARMAN-6x4D-AH',
            'serialNumber': 'WM-2024-8841',
            'location': 'Slurry Processing Bay 2',
            'status': 'OPERATIONAL',
            'lastInspected': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
          },
        ];
        await prefs.setString('cached_equipment', jsonEncode(starterEquipment));
        if (prefs.getString('active_equipment_id') == null) {
          await prefs.setString('active_equipment_id', 'pump-01');
          await prefs.setString('active_equipment_name', 'WARMAN AH Centrifugal Slurry Pump');
          await prefs.setString('active_equipment_model', 'WARMAN-6x4D-AH');
        }
      }
    } catch (e) {
      // Non-fatal starter seed warning
    }
  }

  /// Create starter SQLite manual database for pump-01 if absent
  Future<void> seedStarterKnowledge([Database? appDbConn]) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'knowledge_pump-01.db');
    await closeKnowledgeDb('pump-01');

    final db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (kdb, v) async {
        await kdb.execute('CREATE TABLE IF NOT EXISTS manuals (id TEXT PRIMARY KEY, title TEXT NOT NULL, equipment_id TEXT NOT NULL, file_hash TEXT, page_count INTEGER)');
        await kdb.execute('CREATE TABLE IF NOT EXISTS chunks (id TEXT PRIMARY KEY, manual_id TEXT NOT NULL, page_number INTEGER NOT NULL, chunk_text TEXT NOT NULL, token_count INTEGER)');
        await kdb.execute('CREATE TABLE IF NOT EXISTS embeddings (id TEXT PRIMARY KEY, chunk_id TEXT NOT NULL, embedding BLOB)');
      },
    );

    await db.transaction((txn) async {
      await txn.insert('manuals', {
        'id': 'man_pump_01',
        'title': 'WARMAN AH Centrifugal Slurry Pump Technical Operations Manual',
        'equipment_id': 'pump-01',
        'file_hash': 'sha256-warman-ah-2024',
        'page_count': 4,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      final starterChunks = [
        {
          'id': 'CHUNK-01',
          'manual_id': 'man_pump_01',
          'page_number': 1,
          'chunk_text': 'Section 1.2: Air Bleeding and Priming Procedure. To bleed entrapped air from the casing, locate the bleed vent on top of the pump volute casing. Slowly rotate bleed valve counterclockwise until slurry liquid discharges without air bubbles. Tighten the bleed screw to 35 Nm. Never run dry as mechanical seal faces will sustain immediate thermal shock.',
          'token_count': 64,
        },
        {
          'id': 'CHUNK-02',
          'manual_id': 'man_pump_01',
          'page_number': 2,
          'chunk_text': 'Section 2.1: Bearing Housing Maintenance and Temperature Thresholds. Lubricate bearing cartridge using ISO VG 220 heavy industrial gear oil or lithium complex EP2 grease. Maximum continuous operating bearing temperature is 75°C (167°F). A high-temperature warning alarm is triggered at 85°C. Check grease seals monthly for contamination.',
          'token_count': 59,
        },
        {
          'id': 'CHUNK-03',
          'manual_id': 'man_pump_01',
          'page_number': 2,
          'chunk_text': 'Section 2.4: Vibration Analysis and Impeller Front Clearance. Standard permissible overall vibration level is 4.5 mm/s RMS at full operating speed. Impeller axial clearance between the front shroud and throatbush must be calibrated to 0.50 mm to 0.80 mm to maintain maximum hydraulic efficiency and avoid abrasive scouring.',
          'token_count': 57,
        },
        {
          'id': 'CHUNK-04',
          'manual_id': 'man_pump_01',
          'page_number': 3,
          'chunk_text': 'Section 3.2: Error Code E-04 (Drive Motor Thermal Overload / Overheating). Error code E-04 indicates motor winding temperature has exceeded 130°C. Immediate corrective action: 1) Stop the pump immediately. 2) Inspect slurry suction line for foreign object blockage or pipe choking. 3) Verify shaft spins freely by hand. 4) Allow minimum 20 minutes cooling period before pressing the manual reset switch.',
          'token_count': 72,
        },
        {
          'id': 'CHUNK-05',
          'manual_id': 'man_pump_01',
          'page_number': 3,
          'chunk_text': 'Section 3.5: Error Code E-01 (Cavitation Alarm) and Inverter Fault F07800. E-01 signifies insufficient Net Positive Suction Head (NPSH), resulting in violent vapor pocket collapse. Fault code F07800 indicates VFD inverter trip due to locked rotor or high slurry density exceeding motor rated torque. Check feed sump level immediately.',
          'token_count': 60,
        },
        {
          'id': 'CHUNK-06',
          'manual_id': 'man_pump_01',
          'page_number': 4,
          'chunk_text': 'Section 4.1: Technical Operating Envelopes and Dial Pressure Ranges. Safe discharge pressure gauge reading: 25 to 60 PSI (1.7 to 4.1 bar). Operating speed range: 900 to 1450 RPM. Gland packing must maintain a steady weep rate of 10 to 20 drops per minute for shaft sleeve cooling. Gland follower nuts must be tightened evenly.',
          'token_count': 62,
        },
      ];

      for (final chunk in starterChunks) {
        await txn.insert('chunks', chunk, conflictAlgorithm: ConflictAlgorithm.replace);
        await txn.insert('embeddings', {
          'id': 'emb_${chunk['id']}',
          'chunk_id': chunk['id'],
          'embedding': null,
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });

    await db.close();

    final appDbInstance = appDbConn ?? _appDb ?? await appDb;
    await appDbInstance.insert('installed_packages', {
      'equipment_id': 'pump-01',
      'package_id': 'pkg-warman-ah-starter',
      'version': '1.0.0',
      'chunk_count': 6,
      'installed_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // Incident Operations
  Future<void> saveIncident(IncidentModel incident) async {
    final db = await appDb;
    await db.insert(
      'incidents',
      incident.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<IncidentModel>> getPendingIncidents() async {
    final db = await appDb;
    final maps = await db.query(
      'incidents',
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.name],
    );
    return maps.map((m) => IncidentModel.fromDbMap(m)).toList();
  }

  Future<List<IncidentModel>> getAllIncidents() async {
    final db = await appDb;
    final maps = await db.query('incidents', orderBy: 'recorded_offline_at DESC');
    return maps.map((m) => IncidentModel.fromDbMap(m)).toList();
  }

  Future<void> markIncidentsSynced(List<String> incidentIds, DateTime syncedAt) async {
    final db = await appDb;
    final batch = db.batch();
    for (final id in incidentIds) {
      batch.update(
        'incidents',
        {
          'sync_status': SyncStatus.synced.name,
          'synced_at': syncedAt.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  // =========================================================================
  // Database B: Knowledge Storage (knowledge_{equipment_id}.db)
  // =========================================================================
  Future<Database?> getKnowledgeDb(String equipmentId) async {
    if (_knowledgeDbCache.containsKey(equipmentId)) {
      return _knowledgeDbCache[equipmentId]!;
    }

    final local = await appDb;
    final installed = await local.query('installed_packages', where: 'equipment_id = ?', whereArgs: [equipmentId]);
    if (installed.isEmpty) return null;
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = installed.first['db_path'] as String? ?? p.join(docsDir.path, 'knowledge_$equipmentId.db');

    if (!await File(dbPath).exists()) {
      return null;
    }

    final db = await openDatabase(dbPath, readOnly: true);
    final exclusions = await local.query('knowledge_exclusions', where: 'equipment_id = ?', whereArgs: [equipmentId]);
    // Views can be created on a read-only connection without writable temp inserts.
    // Escape literals read from our application database, never interpolate raw input.
    String literal(Object? value) => "'${value.toString().replaceAll("'", "''")}'";
    final hiddenRows = exclusions.isEmpty ? "SELECT '' AS kind, '' AS entity_id WHERE 0"
      : exclusions.map((row) => 'SELECT ${literal(row['kind'])} AS kind, ${literal(row['entity_id'])} AS entity_id').join(' UNION ALL ');
    await db.execute('CREATE TEMP VIEW hidden_knowledge AS $hiddenRows');
    await db.execute("CREATE TEMP VIEW chunks AS SELECT c.* FROM main.chunks c WHERE NOT EXISTS (SELECT 1 FROM hidden_knowledge h WHERE (h.kind = 'chunk' AND h.entity_id = c.id) OR (h.kind = 'manual' AND h.entity_id = c.manual_id))");
    await db.execute("CREATE TEMP VIEW manuals AS SELECT m.* FROM main.manuals m WHERE NOT EXISTS (SELECT 1 FROM hidden_knowledge h WHERE h.kind = 'manual' AND h.entity_id = m.id)");
    _knowledgeDbCache[equipmentId] = db;
    return db;
  }

  Future<void> closeKnowledgeDb(String equipmentId) async {
    if (_knowledgeDbCache.containsKey(equipmentId)) {
      await _knowledgeDbCache[equipmentId]?.close();
      _knowledgeDbCache.remove(equipmentId);
    }
  }

  /// Query chunks and vector embeddings from Database B
  Future<List<ChunkModel>> searchKnowledgeChunks(String equipmentId, String query, {int limit = 6}) async {
    final db = await getKnowledgeDb(equipmentId);
    if (db == null) return [];
    try {
      final columns = await db.rawQuery('PRAGMA table_info(manuals)');
      final revision = columns.any((c) => c['name'] == 'revision') ? 'm.revision' : 'NULL';
      final installed = await (await appDb).query('installed_packages', where: 'equipment_id = ?', whereArgs: [equipmentId]);
      final rows = await db.rawQuery('''
        SELECT c.id, c.manual_id, m.title AS manual_title, c.page_number, c.chunk_text, $revision AS revision
        FROM chunks c
        JOIN manuals m ON c.manual_id = m.id
      ''');
      final chunks = rows.map((row) => ChunkModel(
        id: row['id'] as String,
        manualId: row['manual_id'] as String,
        manualTitle: row['manual_title'] as String,
        pageNumber: row['page_number'] as int,
        chunkText: row['chunk_text'] as String,
        embedding: const [],
        similarityScore: 0,
        manualRevision: row['revision'] as String?,
        packageVersion: installed.isEmpty ? null : installed.first['version'] as String?,
      )).toList();
      final lexical = rankKnowledgeChunks(chunks, query, limit: chunks.length);
      try {
        final meta = await db.query('metadata', where: 'key = ?', whereArgs: ['encoder_fingerprint']);
        final fingerprint = meta.isEmpty ? '' : meta.first['value'] as String;
        final vector = await SemanticEncoder.embed(query, fingerprint);
        if (vector != null) {
          final rows = await db.query('embeddings');
          final vectors = <String, List<double>>{};
          for (final row in rows) {
            final raw = row['embedding_bytes'];
            if (raw is Uint8List && raw.length == 1536) {
              final bytes = ByteData.sublistView(raw);
              vectors[row['chunk_id'] as String] = List.generate(384, (i) => bytes.getFloat32(i*4, Endian.little));
            }
          }
          return rankHybridKnowledge(chunks, lexical, vectors, vector, limit: limit);
        }
      } catch (_) { /* Old packages or unavailable encoder use explicit lexical fallback. */ }
      return lexical.take(limit).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> _createExclusions(Database db) => db.execute(
    'CREATE TABLE IF NOT EXISTS knowledge_exclusions (equipment_id TEXT NOT NULL, kind TEXT NOT NULL, entity_id TEXT NOT NULL, PRIMARY KEY(equipment_id, kind, entity_id))');

  Future<bool> hasExclusions(String equipmentId) async =>
    (await (await appDb).query('knowledge_exclusions', where: 'equipment_id = ?', whereArgs: [equipmentId], limit: 1)).isNotEmpty;

  Future<void> excludeKnowledge(String equipmentId, String kind, String id) async {
    if (kind != 'chunk' && kind != 'manual') throw ArgumentError('Unsupported knowledge type');
    await (await appDb).insert('knowledge_exclusions', {'equipment_id': equipmentId,
      'kind': kind, 'entity_id': id}, conflictAlgorithm: ConflictAlgorithm.ignore);
    await closeKnowledgeDb(equipmentId);
  }

  Future<void> removePackage(String equipmentId) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+$').hasMatch(equipmentId)) throw ArgumentError('Invalid equipment ID');
    await closeKnowledgeDb(equipmentId);
    // Remove registration first: even a failed file deletion cannot leave data retrievable.
    await (await appDb).delete('installed_packages', where: 'equipment_id = ?', whereArgs: [equipmentId]);
    final docs = await getApplicationDocumentsDirectory();
    final file = File(p.join(docs.path, 'knowledge_$equipmentId.db'));
    if (await file.exists()) await file.delete();
  }

  Future<void> removeEquipmentLocally(String equipmentId) async {
    await removePackage(equipmentId);
    final db = await appDb;
    await db.transaction((tx) async {
      await tx.delete('conversations', where: 'equipment_id = ?', whereArgs: [equipmentId]);
      await tx.delete('incidents', where: 'equipment_id = ?', whereArgs: [equipmentId]);
    });
    final prefs = await SharedPreferences.getInstance();
    final rows = jsonDecode(prefs.getString('cached_equipment') ?? '[]') as List;
    rows.removeWhere((row) => row['id'] == equipmentId);
    await prefs.setString('cached_equipment', jsonEncode(rows));
    if (prefs.getString('active_equipment_id') == equipmentId) {
      for (final key in ['active_equipment_id', 'active_equipment_name', 'active_equipment_model']) { await prefs.remove(key); }
    }
  }

}
