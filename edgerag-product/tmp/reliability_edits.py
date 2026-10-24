from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
def edit(name, old, new):
    p = ROOT / name
    text = p.read_text(encoding='utf-8')
    assert old in text, (name, old[:100])
    p.write_text(text.replace(old, new), encoding='utf-8')

edit('apps/mobile/lib/services/knowledge_retrieval.dart', 'max(0.60, coverage)', 'coverage')
edit('apps/mobile/lib/services/agent_controller.dart', "import 'database_service.dart';", "import 'database_service.dart';\nimport 'knowledge_retrieval.dart';")
edit('apps/mobile/lib/services/agent_controller.dart', 'const maxAttempts = 1;', 'const maxAttempts = 3;\n    final searchBase = currentQuery;')
edit('apps/mobile/lib/services/agent_controller.dart', 'retrievedChunks.isNotEmpty && retrievedChunks.first.similarityScore >= 0.50', 'hasSufficientEvidence(retrievedChunks, searchBase)')
edit('apps/mobile/lib/services/agent_controller.dart', 'currentQuery = _rewriteQuery(currentQuery, attempts);', 'currentQuery = rewriteKnowledgeQuery(searchBase, attempts + 1);')
edit('apps/mobile/lib/services/agent_controller.dart', "    // Filter chunks with relevance", """    if (!hasSufficientEvidence(retrievedChunks, searchBase)) {
      const answer = 'I could not find enough supporting manual evidence. Please provide the exact error code, symptom, or model number, or download the relevant manual. I will not guess a procedure.';
      onTokenStream?.call(answer);
      trace.add('[EVIDENCE] Insufficient after $attempts attempts; generation skipped.');
      return AgentResult(answer: answer, citations: [], providerUsed: 'Evidence check',
        executionTrace: trace.events, isSuccess: false, evidenceStatus: 'INSUFFICIENT');
    }
    // Filter chunks with relevance""")
edit('apps/mobile/lib/services/agent_controller.dart', 'c.similarityScore >= 0.25', 'c.similarityScore >= 0.50')
edit('apps/mobile/lib/services/agent_controller.dart', "  String _rewriteQuery(String query, int attempt) => query;\n", '')
edit('apps/mobile/lib/services/agent_controller.dart', '  final bool isSuccess;', "  final bool isSuccess;\n  final String evidenceStatus;")
edit('apps/mobile/lib/services/agent_controller.dart', '    this.isSuccess = true,', "    this.isSuccess = true,\n    this.evidenceStatus = 'NEEDS_REVIEW',")
edit('apps/mobile/lib/services/agent_controller.dart', '      isSuccess: generatedText.trim().isNotEmpty,', "      isSuccess: generatedText.trim().isNotEmpty,\n      evidenceStatus: verifiedCitations.isEmpty ? 'NEEDS_REVIEW' : 'SUPPORTED',")
edit('apps/mobile/lib/services/agent_controller.dart', '      if (!cloudSuccess) {', "      if (!cloudSuccess) {\n        generatedText = '';\n        onReset?.call();")
edit('apps/mobile/lib/services/database_service.dart', 'version: 2,', 'version: 3,')
edit('apps/mobile/lib/services/database_service.dart', 'if (oldVersion < 2) await _createExclusions(db);', "if (oldVersion < 2) await _createExclusions(db);\n        if (oldVersion < 3) await db.execute('ALTER TABLE installed_packages ADD COLUMN db_path TEXT');")
edit('apps/mobile/lib/services/database_service.dart', 'installed_at TEXT NOT NULL', 'installed_at TEXT NOT NULL,\n            db_path TEXT')
edit('apps/mobile/lib/services/database_service.dart', '    await _ensureStarterData(appDbInstance);', '    // New installations begin empty; only real downloaded manuals are used.')
edit('apps/mobile/lib/services/database_service.dart', "    if ((await local.query('installed_packages', where: 'equipment_id = ?', whereArgs: [equipmentId])).isEmpty) return null;\n    final docsDir = await getApplicationDocumentsDirectory();\n    final dbPath = p.join(docsDir.path, 'knowledge_$equipmentId.db');", "    final installed = await local.query('installed_packages', where: 'equipment_id = ?', whereArgs: [equipmentId]);\n    if (installed.isEmpty) return null;\n    final docsDir = await getApplicationDocumentsDirectory();\n    final dbPath = installed.first['db_path'] as String? ?? p.join(docsDir.path, 'knowledge_$equipmentId.db');")
edit('apps/mobile/lib/services/sync_service.dart', "'staged_knowledge_${package.equipmentId}.db'", "'staged_knowledge_${package.id}.db'")
edit('apps/mobile/lib/services/sync_service.dart', "    // 4. Atomic Database Activation", """    final manifestEntry = archive.findFile('manifest.json');
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

    // 4. Immutable file, then a transactional active pointer. Old file stays usable on failure.""")
edit('apps/mobile/lib/services/sync_service.dart', "final targetDbPath = p.join(docsDir.path, 'knowledge_${package.equipmentId}.db');", "final targetDbPath = p.join(docsDir.path, 'knowledge_${package.equipmentId}_${package.id}.db');")
edit('apps/mobile/lib/services/sync_service.dart', "    if (await File(targetDbPath).exists()) {\n      await File(targetDbPath).delete();\n    }\n    await File(stagingSqlitePath).rename(targetDbPath);", "    if (!await File(targetDbPath).exists()) {\n      final candidate = File('$targetDbPath.partial');\n      await File(stagingSqlitePath).copy(candidate.path);\n      await candidate.rename(targetDbPath);\n    } else if (sha256.convert(await File(targetDbPath).readAsBytes()).toString() != dbHash) {\n      throw StateError('Existing package file differs from verified download');\n    }")
edit('apps/mobile/lib/services/sync_service.dart', "        'package_id': package.id,", "        'package_id': package.id,\n        'db_path': targetDbPath,")
edit('services/api/app/workers/tasks.py', '        pkg_record = KnowledgePackageModel(\n', '        pkg_record = KnowledgePackageModel(\n            id=manifest_data["package_id"],\n')
edit('services/api/app/api/v1/endpoints/manuals.py', 'object_name=f"{equipment_id}_{file.filename}",', 'object_name=f"{equipment_id}_{__import__(\'uuid\').uuid4()}.pdf",')
