import re
from typing import List, Dict, Any

class TokenAwareChunker:
    """Split at paragraph/sentence boundaries, retaining layout and page provenance.

    The dependency-free budget counts words/punctuation and long-word pieces;
    it is a conservative estimate, not a model-specific tokenizer count.
    """
    def __init__(self, target_tokens=224, overlap_tokens=32, tokenizer=None):
        if target_tokens <= 0 or not 0 <= overlap_tokens < target_tokens:
            raise ValueError("Require 0 <= overlap_tokens < target_tokens")
        self.tokenizer = tokenizer
        self.target_tokens = target_tokens
        self.overlap_tokens = overlap_tokens

    def spans(self, text):
        if self.tokenizer is not None:
            class Span:
                def __init__(self, a, b): self.a, self.b = a, b
                def start(self): return self.a
                def end(self): return self.b
                def group(self): return text[self.a:self.b]
            return [Span(a,b) for a,b in self.tokenizer.encode(text, add_special_tokens=False).offsets if b>a]
        return list(re.finditer(r"\w{1,4}|[^\w\s]", text, re.UNICODE))

    def chunk_pages(self, pages: List[Dict[str, Any]], manual_id: str, equipment_id: str):
        chunks = []
        for page in pages:
            text = page.get("text", "").replace("\r\n", "\n").strip()
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
                        if "\n" in gap or (last in ".!?;" and gap):
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
