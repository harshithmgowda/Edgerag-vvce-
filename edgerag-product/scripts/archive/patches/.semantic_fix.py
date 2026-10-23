from pathlib import Path
r=Path.cwd();p=r/'packages/rag-core/src/embedder.py';p.write_text('''"""MiniLM semantic embeddings using local ONNX weights and the matching tokenizer."""
import os
import struct
from pathlib import Path
from functools import lru_cache

class VectorEmbedder:
    def __init__(self, model_name="all-MiniLM-L6-v2", dimension=384):
        if model_name != "all-MiniLM-L6-v2" or dimension != 384:
            raise ValueError("This encoder requires all-MiniLM-L6-v2 with 384 dimensions")
        import onnxruntime as ort
        from tokenizers import Tokenizer
        configured = os.environ.get("EDGERAG_EMBEDDING_DIR")
        cache = Path(os.environ.get("HF_HOME", str(Path.home()/".cache/huggingface"))) / "hub/models--sentence-transformers--all-MiniLM-L6-v2/snapshots"
        candidates = [Path(configured)] if configured else list(cache.glob("*"))
        self.directory = next((p for p in candidates if (p/"onnx/model.onnx").is_file() and (p/"tokenizer.json").is_file()), None)
        if self.directory is None:
            raise RuntimeError("MiniLM assets missing. Set EDGERAG_EMBEDDING_DIR to a directory with tokenizer.json and onnx/model.onnx.")
        options = ort.SessionOptions()
        options.intra_op_num_threads = 4
        self.session = ort.InferenceSession(str(self.directory/"onnx/model.onnx"), sess_options=options, providers=["CPUExecutionProvider"])
        self.tokenizer = Tokenizer.from_file(str(self.directory/"tokenizer.json"))
        self.tokenizer.enable_truncation(max_length=256)
        self.tokenizer.enable_padding()
        self.dimension = dimension

    def chunk_tokenizer(self):
        from tokenizers import Tokenizer
        tokenizer = Tokenizer.from_file(str(self.directory/"tokenizer.json"))
        tokenizer.no_truncation()
        tokenizer.no_padding()
        return tokenizer

    @lru_cache(maxsize=8192)
    def embed_text(self, text):
        import numpy as np
        encoded = self.tokenizer.encode(text)
        values = {"input_ids": np.array([encoded.ids], dtype=np.int64),
            "attention_mask": np.array([encoded.attention_mask], dtype=np.int64),
            "token_type_ids": np.array([encoded.type_ids], dtype=np.int64)}
        output = self.session.run(None, {i.name: values[i.name] for i in self.session.get_inputs()})[0]
        if output.ndim == 3:
            mask = values["attention_mask"][...,None]
            vector = (output*mask).sum(axis=1) / np.maximum(mask.sum(axis=1),1)
        else:
            vector = output
        vector = vector[0]
        vector = vector / max(float(np.linalg.norm(vector)), 1e-12)
        if len(vector) != self.dimension:
            raise ValueError("Unexpected embedding dimension")
        return vector.tolist()

    def embed_to_bytes(self, text):
        return struct.pack("<384f", *self.embed_text(text))

@lru_cache(maxsize=1)
def get_embedder():
    return VectorEmbedder()
''',encoding='utf-8')
p=r/'packages/rag-core/src/chunker.py';s=p.read_text().replace('def __init__(self, target_tokens=224, overlap_tokens=32):','def __init__(self, target_tokens=224, overlap_tokens=32, tokenizer=None):').replace('        self.target_tokens = target_tokens','        self.tokenizer = tokenizer\n        self.target_tokens = target_tokens');s=s.replace('    @staticmethod\n    def spans(text):\n        return list(re.finditer', '''    def spans(self, text):
        if self.tokenizer is not None:
            class Span:
                def __init__(self, a, b): self.a, self.b = a, b
                def start(self): return self.a
                def end(self): return self.b
                def group(self): return text[self.a:self.b]
            return [Span(a,b) for a,b in self.tokenizer.encode(text, add_special_tokens=False).offsets if b>a]
        return list(re.finditer''');p.write_text(s)
p=r/'services/api/app/workers/tasks.py';s=p.read_text();a=s.index('def _generate_384d_embedding');b=s.index('def execute_processing_pipeline',a);s=s[:a]+'''def _generate_384d_embedding(text: str) -> bytes:
    from src.embedder import get_embedder
    return get_embedder().embed_to_bytes(text)


'''+s[b:];s=s.replace('        chunker = TokenAwareChunker(settings.MAX_CHUNK_TOKENS, settings.CHUNK_OVERLAP_TOKENS)', '        from src.embedder import get_embedder\n        encoder = get_embedder()\n        chunker = TokenAwareChunker(settings.MAX_CHUNK_TOKENS, settings.CHUNK_OVERLAP_TOKENS, tokenizer=encoder.chunk_tokenizer())');s=s.replace('"legacy-character-projection-v1"','"all-MiniLM-L6-v2"');s=s.replace('        # Create Knowledge SQLite database','        if os.path.exists(sqlite_file):\n            os.remove(sqlite_file)\n        # Create Knowledge SQLite database');s=s.replace('        cur = conn.cursor()','        cur = conn.cursor()\n        cur.execute("CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)")\n        cur.execute("INSERT INTO metadata VALUES (?, ?)", ("embedding_backend", "minilm-onnx-meanpool-v1"))');p.write_text(s)
p=r/'services/api/app/ai/retrieval.py';s=p.read_text()+'''

def rank_hybrid(chunks, query, vectors, query_vector, limit=6):
    lexical = rank_chunks(chunks, query, limit=len(chunks))
    lex = {c["chunk_id"]: c for c in lexical}
    scale = max((c["retrieval_score"] for c in lexical), default=1) or 1
    ranked = []
    for chunk, vector in zip(chunks, vectors):
        cosine = sum(a*b for a,b in zip(vector, query_vector))
        hit = lex.get(chunk["chunk_id"])
        if hit is None and cosine < .40:
            continue
        score = .6 * max(0, cosine) + .4 * (hit["retrieval_score"]/scale if hit else 0)
        ranked.append(dict(chunk, similarity_score=cosine, retrieval_score=score))
    ranked.sort(key=lambda c: (-c["retrieval_score"], c["chunk_id"]))
    result = []
    for candidate in ranked:
        words = set(terms(candidate["chunk_text"]))
        if any(len(words & set(terms(c["chunk_text"]))) / max(1,len(words | set(terms(c["chunk_text"])))) > .85 for c in result):
            continue
        result.append(candidate)
        if len(result) == limit:
            break
    return result
''';p.write_text(s)
p=r/'services/api/app/ai/agent.py';s=p.read_text();s=s.replace('    from app.ai.retrieval import rank_chunks','    from app.ai.retrieval import rank_chunks, rank_hybrid');s=s.replace('        try:\n            rows = conn.execute', '''        vectors = None
        try:
            rows = conn.execute''');s=s.replace('        finally:\n            conn.close()', '''            tables = {r[0] for r in conn.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if "metadata" in tables:
                backend = conn.execute("SELECT value FROM metadata WHERE key='embedding_backend'").fetchone()
                if backend and backend[0] == "minilm-onnx-meanpool-v1":
                    import struct
                    blobs = dict(conn.execute("SELECT chunk_id, embedding_bytes FROM embeddings"))
                    if all(row[0] in blobs and len(blobs[row[0]]) == 1536 for row in rows):
                        vectors = [struct.unpack("<384f", blobs[row[0]]) for row in rows]
        finally:
            conn.close()''');s=s.replace('    return rank_chunks(chunks, query, limit)','''    if vectors is not None:
        try:
            from src.embedder import get_embedder
            return rank_hybrid(chunks, query, vectors, get_embedder().embed_text(query), limit)
        except (ImportError, RuntimeError):
            pass  # Explicit lexical fallback for hosts without the encoder assets.
    return rank_chunks(chunks, query, limit)''');s=s.replace('if chunks and chunks[0]["similarity_score"] >= 0.50:', 'if chunks:');s=s.replace('Relevance threshold satisfied (Top score:', 'Relevant evidence retrieved (Top score:').replace(' >= 0.50)', ')');s=s.replace('Ranking manual passages by BM25 and query coverage:', 'Ranking manual passages with hybrid retrieval:');p.write_text(s,encoding='utf-8')
