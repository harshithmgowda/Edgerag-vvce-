"""MiniLM semantic embeddings using local ONNX weights and the matching tokenizer."""
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

    @lru_cache(maxsize=1)
    def fingerprint(self):
        import hashlib
        hashes = [hashlib.sha256((self.directory / name).read_bytes()).hexdigest()
                  for name in ('onnx/model.onnx', 'tokenizer.json')]
        return hashlib.sha256(''.join(hashes).encode()).hexdigest()

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
