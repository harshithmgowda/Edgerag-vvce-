from pathlib import Path
root=Path.cwd()
p=root/'packages/rag-core/src/chunker.py'
p.write_text('''import re
from typing import List, Dict, Any

class TokenAwareChunker:
    """Split at paragraph/sentence boundaries, retaining layout and page provenance.

    The dependency-free budget counts words/punctuation and long-word pieces;
    it is a conservative estimate, not a model-specific tokenizer count.
    """
    def __init__(self, target_tokens=224, overlap_tokens=32):
        if target_tokens <= 0 or not 0 <= overlap_tokens < target_tokens:
            raise ValueError("Require 0 <= overlap_tokens < target_tokens")
        self.target_tokens = target_tokens
        self.overlap_tokens = overlap_tokens

    @staticmethod
    def spans(text):
        return list(re.finditer(r"\\w{1,4}|[^\\w\\s]", text, re.UNICODE))

    def chunk_pages(self, pages: List[Dict[str, Any]], manual_id: str, equipment_id: str):
        chunks = []
        for page in pages:
            text = page.get("text", "").replace("\\r\\n", "\\n").strip()
            if not text:
                continue
            tokens = self.spans(text)
            start = 0
            index = 0
            while start < len(tokens):
                end = min(start + self.target_tokens, len(tokens))
                if end < len(tokens):
                    # Prefer natural boundaries in the latter half of the window.
                    lower = start + self.target_tokens // 2
                    for candidate in range(end, lower, -1):
                        gap = text[tokens[candidate-1].end():tokens[candidate].start()]
                        last = tokens[candidate-1].group()
                        if "\\n" in gap or (last in ".!?;" and gap):
                            end = candidate
                            break
                    # Never split a word unless a single word exceeds the budget.
                    while end > start + 1 and tokens[end-1].end() == tokens[end].start() and tokens[end-1].group().isalnum() and tokens[end].group().isalnum():
                        end -= 1
                content = text[tokens[start].start():tokens[end-1].end()].strip()
                chunks.append({"id": f"chunk_{manual_id}_{page['page_number']:03d}_{index:03d}",
                    "manual_id": manual_id, "equipment_id": equipment_id,
                    "page_number": page["page_number"], "chunk_index": index,
                    "token_count": end-start, "chunk_text": content})
                if end == len(tokens):
                    break
                next_start = max(start + 1, end - self.overlap_tokens)
                while next_start < end and tokens[next_start-1].end() == tokens[next_start].start():
                    next_start += 1
                start = next_start
                index += 1
        return chunks
''',encoding='utf-8')
p=root/'services/api/app/workers/tasks.py';s=p.read_text()
a=s.index('def _simple_chunk_text');b=s.index('def _generate_384d_embedding',a)
s=s[:a]+'''def _simple_chunk_text(text: str, chunk_size: int = 224, overlap: int = 32):
    from src.chunker import TokenAwareChunker
    return [c["chunk_text"] for c in TokenAwareChunker(chunk_size, overlap).chunk_pages(
        [{"page_number": 1, "text": text}], "", "")]


'''+s[b:]
s=s.replace('page.get_text("text").strip()', 'page.get_text("text", sort=True).strip()')
s=s.replace('                extracted_pages.append((1, f"{manual.title} - Technical specifications and safety instructions for {equipment.name}."))\n                total_doc_pages = 1','                raise ValueError("PDF extraction failed; no knowledge package was published")')
s=s.replace('                reader = pypdf.PdfReader(pdf_path)', '                extracted_pages = []\n                reader = pypdf.PdfReader(pdf_path)')
s=s.replace('        manual.page_count = total_doc_pages','        if not extracted_pages:\n            raise ValueError("PDF has no extractable text. OCR is required before indexing.")\n\n        manual.page_count = total_doc_pages')
s=s.replace('"model_name": settings.EMBEDDING_MODEL_NAME','"model_name": "legacy-character-projection-v1"')
s=s.replace('encoder_model=settings.EMBEDDING_MODEL_NAME','encoder_model="legacy-character-projection-v1"')
# Unique package files prevent one manual replacing another at the same storage path.
s=s.replace('f"equipment-knowledge-{equipment.id[:8]}-v1.zip"','f"equipment-knowledge-{equipment.id[:8]}-{job.id}.zip"')
p.write_text(s,encoding='utf-8')
p=root/'services/api/requirements.txt';s=p.read_text();s+='\n-e ../../packages/rag-core\n';p.write_text(s)
p=root/'packages/rag-core/src/extractor.py';s=p.read_text().replace('page.get_text("text").strip()', 'page.get_text("text", sort=True).strip()');s=s.replace('                reader = pypdf.PdfReader(pdf_path)','                pages = []\n                reader = pypdf.PdfReader(pdf_path)');a=s.index('                # Fallback if unreadable binary');s=s[:a]+'''                raise ValueError(f"Unable to extract PDF: {os.path.basename(pdf_path)}") from e
''';p.write_text(s)
