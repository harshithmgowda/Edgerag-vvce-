import os
import tempfile
import uuid
from packages.rag_core.src.chunker import TokenAwareChunker
from packages.rag_core.src.embedder import VectorEmbedder
from packages.rag_core.src.builder import KnowledgePackageBuilder

def test_chunking_and_embedding_pipeline():
    sample_pages = [
        {
            "page_number": 1,
            "text": "The Siemens S7-1500 controller features high performance CPU processing with integrated PROFINET diagnostics. Ensure power supply is isolated before service.",
            "is_empty": False
        },
        {
            "page_number": 2,
            "text": "Error code ERR-4029 indicates power rail voltage fluctuation beyond +/- 5% threshold. Inspect circuit breaker CB-104 and verify incoming terminal voltage.",
            "is_empty": False
        }
    ]

    manual_id = str(uuid.uuid4())
    equipment_id = str(uuid.uuid4())

    # 1. Chunking
    chunker = TokenAwareChunker(target_tokens=50, overlap_tokens=10)
    chunks = chunker.chunk_pages(sample_pages, manual_id=manual_id, equipment_id=equipment_id)
    assert len(chunks) >= 2
    assert chunks[0]["page_number"] == 1
    assert chunks[1]["page_number"] == 2

    # 2. Embeddings
    embedder = VectorEmbedder()
    embeddings = [embedder.embed_to_bytes(c["chunk_text"]) for c in chunks]
    assert len(embeddings) == len(chunks)
    assert len(embeddings[0]) == 384 * 4  # 384 floats * 4 bytes = 1536 bytes

    # 3. Knowledge Package Compilation
    with tempfile.TemporaryDirectory() as temp_dir:
        result = KnowledgePackageBuilder.build_package(
            output_dir=temp_dir,
            package_id=str(uuid.uuid4()),
            equipment_id=equipment_id,
            equipment_name="Siemens S7-1500 PLC",
            version="v1",
            manual_id=manual_id,
            manual_title="S7-1500 Diagnostic Manual",
            manual_revision="Rev 2.0",
            page_count=2,
            chunks=chunks,
            embeddings=embeddings,
        )

        assert os.path.exists(result["zip_path"])
        assert result["file_size_bytes"] > 0
        assert len(result["sha256_hash"]) == 64
        assert result["manifest"]["chunk_count"] == len(chunks)
        assert result["manifest"]["embedding_spec"]["dimension"] == 384
