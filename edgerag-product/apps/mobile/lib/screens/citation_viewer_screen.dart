import 'package:flutter/material.dart';
import '../models/models.dart';
import '../widgets/manual_page_preview.dart';

class CitationViewerScreen extends StatelessWidget {
  final ChunkModel chunk;

  const CitationViewerScreen({super.key, required this.chunk});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Citation: Page ${chunk.pageNumber}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(chunk.manualTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Page ${chunk.pageNumber}',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: Colors.blue.shade800),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Retrieval score: ${chunk.similarityScore.toStringAsFixed(2)}',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text('Revision ${chunk.manualRevision ?? "unknown"} · Package ${chunk.packageVersion ?? "unknown"}', style: const TextStyle(fontSize: 11)),
              const Text('Supporting passage · retrieval score is not answer confidence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF475569))),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: SingleChildScrollView(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ManualPagePreview(chunk: chunk), SelectableText(
                      chunk.chunkText,
                      style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF1E293B)),
                    )]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
