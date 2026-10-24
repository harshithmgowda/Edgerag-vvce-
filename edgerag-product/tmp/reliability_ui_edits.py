exec((__import__('pathlib').Path(__file__).parent / 'reliability_edits.py').read_text().split("edit('apps/mobile")[0])
edit('apps/hq-web/app/chat/page.tsx', "import { api }", "import { SourcePreview } from '@/components/SourcePreview';\nimport { api }")
edit('apps/hq-web/app/chat/page.tsx', 'type Source = { chunk_id:string;', 'type Source = { manual_id:string; manual_revision?:string; package_version?:string; chunk_id:string;')
edit('apps/hq-web/app/chat/page.tsx', 'provider?:string };', 'provider?:string; evidence?:string };')
edit('apps/hq-web/app/chat/page.tsx', 'provider:payload.provider_used}', 'provider:payload.provider_used,evidence:payload.evidence_status}')
edit('apps/hq-web/app/chat/page.tsx', '<p>{s.snippet}</p></details>', '<p><mark>{s.snippet}</mark></p><p className="text-xs">Revision {s.manual_revision || "unknown"} · Package {s.package_version || "unknown"}</p>{s.manual_id&&<SourcePreview manualId={s.manual_id} page={s.page_number} excerpt={s.snippet}/>}</details>')
edit('apps/hq-web/app/chat/page.tsx', "{m.provider&&<span>{m.provider}</span>}", "{m.provider&&<span>{m.provider}</span>}{m.evidence&&<span>{m.evidence==='SUPPORTED'?'Supporting sources found':m.evidence==='INSUFFICIENT'?'More evidence needed':'Review answer against sources'}</span>}")
edit('services/api/app/ai/agent.py', '            rows = conn.execute("""', '            columns = {r[1] for r in conn.execute("PRAGMA table_info(manuals)")}\n            revision = "m.revision" if "revision" in columns else "NULL"\n            rows = conn.execute(f"""')
edit('services/api/app/ai/agent.py', 'c.chunk_text, m.revision', 'c.chunk_text, {revision}')
edit('apps/mobile/lib/models/models.dart', '  final double similarityScore;', '  final double similarityScore;\n  final String? manualRevision;\n  final String? packageVersion;')
edit('apps/mobile/lib/models/models.dart', '    this.similarityScore = 0.0,', '    this.similarityScore = 0.0,\n    this.manualRevision,\n    this.packageVersion,')
edit('apps/mobile/lib/services/knowledge_retrieval.dart', 'embedding:const [],similarityScore:1', 'embedding:c.embedding,manualRevision:c.manualRevision,packageVersion:c.packageVersion,similarityScore:1')
edit('apps/mobile/lib/services/knowledge_retrieval.dart', 'embedding:const [], similarityScore:calculatedScore', 'embedding:c.embedding, manualRevision:c.manualRevision, packageVersion:c.packageVersion, similarityScore:calculatedScore')
edit('apps/mobile/lib/services/database_service.dart', "import 'knowledge_retrieval.dart';", "import 'knowledge_retrieval.dart';\nimport 'semantic_encoder.dart';\nimport 'dart:typed_data';")
edit('apps/mobile/lib/services/database_service.dart', "      final rows = await db.rawQuery('''\n        SELECT", "      final columns = await db.rawQuery('PRAGMA table_info(manuals)');\n      final revision = columns.any((c) => c['name'] == 'revision') ? 'm.revision' : 'NULL';\n      final installed = await (await appDb).query('installed_packages', where: 'equipment_id = ?', whereArgs: [equipmentId]);\n      final rows = await db.rawQuery('''\n        SELECT")
edit('apps/mobile/lib/services/database_service.dart', 'c.page_number, c.chunk_text\n        FROM chunks', 'c.page_number, c.chunk_text, $revision AS revision\n        FROM chunks')
edit('apps/mobile/lib/services/database_service.dart', "        similarityScore: 0,", "        similarityScore: 0,\n        manualRevision: row['revision'] as String?,\n        packageVersion: installed.isEmpty ? null : installed.first['version'] as String?,")
edit('apps/mobile/lib/services/database_service.dart', '      return rankKnowledgeChunks(chunks, query, limit: limit);', """      final lexical = rankKnowledgeChunks(chunks, query, limit: chunks.length);
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
      return lexical.take(limit).toList();""")
edit('apps/mobile/lib/services/agent_controller.dart', 'embedding:const [], similarityScore:(c[\'similarity_score\'] as num).toDouble()', "embedding:const [], manualRevision:c['manual_revision'], packageVersion:c['package_version'], similarityScore:(c['similarity_score'] as num).toDouble()")
edit('apps/mobile/lib/services/agent_controller.dart', "executionTrace:List<String>.from(data['execution_trace']),", "evidenceStatus:data['evidence_status'] as String? ?? 'NEEDS_REVIEW', executionTrace:List<String>.from(data['execution_trace']),")
edit('apps/mobile/lib/screens/model_manager_screen.dart', "import '../services/model_registry_service.dart';", "import '../services/model_registry_service.dart';\nimport '../services/semantic_encoder.dart';\nimport '../services/local_ai_service.dart';")
edit('apps/mobile/lib/screens/model_manager_screen.dart', '  Future<void> _deleteModel', """  Future<void> _importEncoder() async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['zip']);
    if (picked?.files.single.path == null || !mounted) return;
    setState(() => _isLoading = true);
    try {
      await SemanticEncoder.importBundle(picked!.files.single.path!);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('MiniLM installed. Tokenizer and vector parity checks passed.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Encoder import failed: $e')));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _testOffline() async {
    setState(() => _isLoading = true);
    final watch = Stopwatch()..start();
    var answer = '';
    try {
      await for (final token in LocalAiService().generateLocalResponseStream(question: 'Reply with: Local inference works.', chunks: const []).timeout(const Duration(seconds: 90))) { answer += token; }
      if (answer.trim().isEmpty) throw StateError('Model returned no output');
      if (mounted) showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Local inference completed'), content: Text('${watch.elapsedMilliseconds} ms\\n\\n$answer\\n\\nThis checks local generation, not answer accuracy. Repeat in airplane mode.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
    } catch (e) {
      await LocalAiService().cancel();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Local inference failed: $e')));
    } finally { if (mounted) setState(() => _isLoading = false); }
  }

  Future<void> _deleteModel""")
edit('apps/mobile/lib/screens/model_manager_screen.dart', '                  // Storage Health Card', "                  OutlinedButton.icon(onPressed: _importEncoder, icon: const Icon(Icons.manage_search), label: const Text('Import matching MiniLM encoder')),\n                  OutlinedButton.icon(onPressed: _testOffline, icon: const Icon(Icons.offline_bolt), label: const Text('Test local inference')),\n                  // Storage Health Card")
edit('apps/mobile/android/app/build.gradle.kts', '            signingConfig = signingConfigs.getByName("debug")', '            signingConfig = signingConfigs.getByName("debug")\n            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")')
