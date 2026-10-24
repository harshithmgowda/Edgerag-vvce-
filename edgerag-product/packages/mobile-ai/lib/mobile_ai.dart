import 'dart:math';

/// EdgeRAG Mobile AI On-Device Vector Similarity & Embedding Normalizer
class MobileVectorEngine {
  /// Computes dot-product cosine similarity between two 384-dimensional normalized vectors
  static double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
    }
    return dot;
  }

  /// Projects input query text into a normalized 384-dimensional feature vector
  static List<double> projectQuery(String text) {
    const dimension = 384;
    final vector = List<double>.filled(dimension, 0.0);
    final normalized = text.toLowerCase().trim();
    final tokens = normalized.split(RegExp(r'\s+'));

    for (int i = 0; i < tokens.length; i++) {
      final token = tokens[i];
      for (int charIdx = 0; charIdx < token.length; charIdx++) {
        final code = token.codeUnitAt(charIdx);
        final bucket = (code * 31 + charIdx * 17 + i * 13) % dimension;
        vector[bucket] += 1.0 / (charIdx + 1);
      }
    }

    double norm = 0.0;
    for (int i = 0; i < dimension; i++) {
      norm += vector[i] * vector[i];
    }
    norm = sqrt(norm);

    if (norm > 0.0) {
      for (int i = 0; i < dimension; i++) {
        vector[i] /= norm;
      }
    }

    return vector;
  }
}
