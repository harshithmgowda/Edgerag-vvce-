import 'dart:math';
import '../models/models.dart';

const _stop = 'a an the is are was were be been to of for in on and or with what which how do does can i me my please explain tell about this that it from by give simple example examples describe detail detailed briefly briefly show using used would could should need want understand step steps please document documents manual explain explanation main key concept';
List<String> retrievalTerms(String text) => RegExp(r'[a-z0-9]+(?:[-.][a-z0-9]+)*')
    .allMatches(text.toLowerCase()).map((m) => m.group(0)!)
    .where((t) => !_stop.split(' ').contains(t)).toList();

bool hasSufficientEvidence(List<ChunkModel> chunks, String question) {
  if (chunks.isEmpty) return false;
  if (RegExp(r'\b(summary|summarize|overview|topics covered)\b', caseSensitive: false).hasMatch(question)) return true;
  final terms = retrievalTerms(question);
  final codes = terms.where((t) => RegExp(r'\d').hasMatch(t)).toList();
  for (final chunk in chunks) {
    final chunkTerms = retrievalTerms(chunk.chunkText);
    // Technical error codes and part numbers must appear in evidence
    if (codes.isNotEmpty && !codes.every((code) => chunkTerms.contains(code))) {
      continue;
    }
    // High-relevance match passes sufficiency check
    if (chunk.similarityScore >= 0.40) {
      return true;
    }
  }
  return false;
}

String rewriteKnowledgeQuery(String query, int attempt, {String? equipmentModel}) {
  var expanded = query.toLowerCase().replaceAll('’', "'");
  const expansions = {
    'not draining': 'drainage blockage filter hose pump',
    'water stays': 'drainage troubleshooting blockage drain pump waste water',
    'does not start': 'power supply door switch fuse circuit breaker start',
    "won't start": 'power supply door switch fuse circuit breaker start',
    'overheating': 'overheating temperature cooling thermal fan heat sink',
    'vibration': 'vibration unbalance balance alignment mounting damper',
    'rpm': 'rpm rotational speed motor velocity',
    'psi': 'psi pressure bar regulator gauge valve',
    'shuts off': 'shutdown overload trip thermal cut-off safety limit',
    'leaking': 'leak seal gasket o-ring hose fitting',
  };
  for (final entry in expansions.entries) { expanded = expanded.replaceAll(entry.key, entry.value); }
  if (attempt == 2) {
    return expanded;
  }
  final modelPart = (equipmentModel != null && equipmentModel.isNotEmpty) ? '$equipmentModel ' : '';
  final termsList = retrievalTerms(expanded).toSet().join(' ');
  return '$modelPart$termsList'.trim();
}

List<ChunkModel> rankKnowledgeChunks(List<ChunkModel> chunks, String query, {int limit = 6}) {
  if (RegExp(r'\b(summarize|summary|overview|main topics|topics covered)\b', caseSensitive:false).hasMatch(query)) {
    final sorted = [...chunks]..sort((a,b) { final manual=a.manualId.compareTo(b.manualId); return manual!=0?manual:a.pageNumber.compareTo(b.pageNumber); });
    final selected=<ChunkModel>[];
    for(var i=0;i<limit&&i<sorted.length;i++) {
      final c=sorted[(i*sorted.length/limit).floor()];
      selected.add(ChunkModel(id:c.id,manualId:c.manualId,manualTitle:c.manualTitle,pageNumber:c.pageNumber,chunkText:c.chunkText,embedding:c.embedding,manualRevision:c.manualRevision,packageVersion:c.packageVersion,similarityScore:1));
    }
    return selected;
  }
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
    if (matched.isEmpty) continue;
    final coverage = matched.length / terms.length;
    var score = 0.0;
    for (final t in matched) {
      final f = doc[t]!;
      score += log(1+(docs.length-df[t]!+.5)/(df[t]!+.5))*f*2.2/(f+1.2*(.25+.75*lengths[i]/average));
    }
    final c = chunks[i];
    final calculatedScore = coverage;
    ranked.add((chunk: ChunkModel(id:c.id, manualId:c.manualId, manualTitle:c.manualTitle,
      pageNumber:c.pageNumber, chunkText:c.chunkText, embedding:c.embedding, manualRevision:c.manualRevision, packageVersion:c.packageVersion, similarityScore:calculatedScore), score:score*calculatedScore));
  }
  ranked.sort((a,b) { final order=b.score.compareTo(a.score); return order != 0 ? order : a.chunk.id.compareTo(b.chunk.id); });
  final seen = <String>{};
  return ranked.where((r) => seen.add('${r.chunk.manualId}\n${r.chunk.chunkText}')).take(limit).map((r)=>r.chunk).toList();
}

List<ChunkModel> rankHybridKnowledge(List<ChunkModel> chunks, List<ChunkModel> lexical,
    Map<String,List<double>> vectors, List<double> query, {int limit = 6}) {
  final positions = {for (var i=0; i<lexical.length; i++) lexical[i].id: i};
  final matches = {for (final chunk in lexical) chunk.id: chunk.similarityScore};
  final ranked = <({ChunkModel chunk, double rank})>[];
  for (final chunk in chunks) {
    final vector = vectors[chunk.id];
    if (vector == null || vector.length != query.length || vector.any((v)=>!v.isFinite)) continue;
    var cosine = 0.0;
    for (var i=0; i<query.length; i++) { cosine += vector[i]*query[i]; }
    final coverage = matches[chunk.id] ?? 0;
    if (coverage < .30 && cosine < .35) continue;
    final position = positions[chunk.id];
    final rank = .6 * max(0, cosine) + .4 * (position == null ? 0 : 1/(position+1));
    ranked.add((chunk: ChunkModel(id: chunk.id, manualId: chunk.manualId, manualTitle: chunk.manualTitle,
      pageNumber: chunk.pageNumber, chunkText: chunk.chunkText, embedding: const [],
      manualRevision: chunk.manualRevision, packageVersion: chunk.packageVersion,
      similarityScore: max(cosine, coverage)), rank: rank));
  }
  ranked.sort((a,b)=>b.rank.compareTo(a.rank));
  final result = <ChunkModel>[];
  for (final item in ranked) {
    final words = retrievalTerms(item.chunk.chunkText).toSet();
    if (result.any((c) { final other = retrievalTerms(c.chunkText).toSet();
      return words.intersection(other).length/max(1,words.union(other).length) > .85; })) continue;
    result.add(item.chunk);
    if (result.length == limit) break;
  }
  return result;
}
