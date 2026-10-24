import 'package:flutter_test/flutter_test.dart';
import 'package:edgerag_mobile/models/models.dart';
import 'package:edgerag_mobile/services/knowledge_retrieval.dart';

ChunkModel chunk(String id, String text) => ChunkModel(id:id, manualId:'manual',
  manualTitle:'Manual', pageNumber:1, chunkText:text, embedding:[], similarityScore:0);
void main() {
  test('Ranks relevant topic, rejects unrelated and empty questions', () {
    final docs = [chunk('a','Oil maintenance and safety inspection'),
      chunk('b','Dijkstra shortest path uses tentative distances'),
      chunk('c','E-104 means coolant failure')];
    expect(rankKnowledgeChunks(docs, 'Explain Dijkstra shortest path').first.id, 'b');
    expect(rankKnowledgeChunks(docs, 'What does E-104 mean').first.id, 'c');
    expect(rankKnowledgeChunks(docs, 'photosynthesis chlorophyll'), isEmpty);
    expect(rankKnowledgeChunks(docs, 'what is the'), isEmpty);
  });
  test('Duplicate excerpts do not consume context budget', () {
    expect(rankKnowledgeChunks([chunk('a','Dijkstra paths'),chunk('b','Dijkstra paths')], 'Dijkstra'), hasLength(1));
  });
}
