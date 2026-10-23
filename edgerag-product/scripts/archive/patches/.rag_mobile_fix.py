from pathlib import Path
r=Path.cwd(); p=r/'apps/mobile/lib/services/knowledge_retrieval.dart'
p.write_text('''import 'dart:math';
import '../models/models.dart';

const _stop = 'a an the is are was were be been to of for in on and or with what which how do does can i me my please explain tell about this that it from by';
List<String> retrievalTerms(String text) => RegExp(r'[a-z0-9]+(?:[-.][a-z0-9]+)*')
    .allMatches(text.toLowerCase()).map((m) => m.group(0)!)
    .where((t) => !_stop.split(' ').contains(t)).toList();

List<ChunkModel> rankKnowledgeChunks(List<ChunkModel> chunks, String query, {int limit = 6}) {
  final terms = retrievalTerms(query).toSet();
  if (terms.isEmpty || chunks.isEmpty) return [];
  final docs = chunks.map((c) {
    final counts = <String, int>{};
    for (final t in retrievalTerms(c.chunkText)) { counts[t] = (counts[t] ?? 0) + 1; }
    return counts;
  }).toList();
  final lengths = docs.map((d) => d.values.fold<int>(0, (a,b) => a+b)).toList();
  final average = max(1.0, lengths.reduce((a,b) => a+b) / docs.length);
  final df = <String, int>{};
  for (final d in docs) { for (final t in d.keys) { df[t] = (df[t] ?? 0)+1; } }
  final ranked = <({ChunkModel chunk, double score})>[];
  for (var i=0; i<chunks.length; i++) {
    final doc = docs[i];
    final matched = terms.intersection(doc.keys.toSet());
    final coverage = matched.length / terms.length;
    if (coverage < .25) continue;
    var score = 0.0;
    for (final t in matched) {
      final f = doc[t]!;
      score += log(1+(docs.length-df[t]!+.5)/(df[t]!+.5))*f*2.2/(f+1.2*(.25+.75*lengths[i]/average));
    }
    final c = chunks[i];
    ranked.add((chunk: ChunkModel(id:c.id, manualId:c.manualId, manualTitle:c.manualTitle,
      pageNumber:c.pageNumber, chunkText:c.chunkText, embedding:const [], similarityScore:coverage), score:score*coverage));
  }
  ranked.sort((a,b) { final order=b.score.compareTo(a.score); return order != 0 ? order : a.chunk.id.compareTo(b.chunk.id); });
  final seen = <String>{};
  return ranked.where((r) => seen.add('${r.chunk.manualId}\\n${r.chunk.chunkText}')).take(limit).map((r)=>r.chunk).toList();
}
''')
p=r/'apps/mobile/lib/services/database_service.dart';s=p.read_text();s="import 'knowledge_retrieval.dart';\n"+s;a=s.index('  Future<List<ChunkModel>> searchKnowledgeChunks');b=s.index('  // Fast dot-product',a)
s=s[:a]+'''  Future<List<ChunkModel>> searchKnowledgeChunks(String equipmentId, String query, {int limit = 6}) async {
    final db = await getKnowledgeDb(equipmentId);
    if (db == null) return [];
    final rows = await db.rawQuery(\'''SELECT c.id, c.manual_id, m.title AS manual_title,
      c.page_number, c.chunk_text FROM chunks c JOIN manuals m ON c.manual_id = m.id
      WHERE c.equipment_id = ?\''', [equipmentId]);
    final chunks = rows.map((row) => ChunkModel(
      id: row['id'] as String, manualId: row['manual_id'] as String,
      manualTitle: row['manual_title'] as String, pageNumber: row['page_number'] as int,
      chunkText: row['chunk_text'] as String, embedding: const [], similarityScore: 0,
    )).toList();
    return rankKnowledgeChunks(chunks, query, limit: limit);
  }

''' + s[b:];a=s.index('  // Fast dot-product');s=s[:a]+'}\n';s=s.replace("import 'dart:typed_data';\n",'');p.write_text(s)
p=r/'apps/mobile/lib/services/agent_controller.dart';s=p.read_text();s=s.replace("      final queryVector = _localAi.embedQuery(currentQuery);",'');s=s.replace('queryVector, limit: 4','currentQuery, limit: 6');s=s.replace('Generating 384-d vector','Preparing lexical retrieval');s=s.replace('Executing cosine similarity search','Executing BM25 and query coverage search');s=s.replace('if (retrievedChunks.isEmpty) {','if (retrievedChunks.isEmpty || retrievedChunks.first.similarityScore < .25) {',1);s=s.replace('No technical manual documentation has been downloaded for this equipment yet. Please connect to the Headquarters Hotspot to download the knowledge package.','No sufficiently relevant manual evidence was found. Try the exact topic or error code, or sync the correct manual from Headquarters.');a=s.index('  String _rewriteQuery');b=s.index('  List<ChunkModel> _verifyCitations',a);s=s[:a]+'''  String _rewriteQuery(String query, int attempt) => query;

'''+s[b:];s=s.replace("answer.contains('Page ${chunk.pageNumber}') || ",'');s=s.replace('return verified.isNotEmpty ? verified : availableChunks.take(2).toList();','return verified;');s=s.replace('isSuccess: true,','isSuccess: verifiedCitations.isNotEmpty,');s=s.replace('Offline Grounded Synthesizer','Local GGUF Model');p.write_text(s)
