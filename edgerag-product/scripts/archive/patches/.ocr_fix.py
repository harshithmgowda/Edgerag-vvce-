from pathlib import Path
p=Path('packages/rag-core/src/extractor.py');p.write_text('''import os
from functools import lru_cache

@lru_cache(maxsize=1)
def _ocr_engine():
    from rapidocr_onnxruntime import RapidOCR
    return RapidOCR()

class PdfExtractor:
    """Preserve PDF page provenance and OCR image-only pages locally."""
    @staticmethod
    def extract_pages(pdf_path):
        if not os.path.exists(pdf_path):
            raise FileNotFoundError(f"PDF not found: {pdf_path}")
        try:
            import fitz
        except ImportError as exc:
            raise RuntimeError("PyMuPDF is required for PDF extraction; install the API requirements") from exc
        pages = []
        scanned = 0
        ocr_pages = 0
        try:
            with fitz.open(pdf_path) as document:
                for number, page in enumerate(document, 1):
                    text = page.get_text("text", sort=True).strip()
                    visual = bool(page.get_images() or page.get_drawings())
                    needs_ocr = len(text) < 25 and visual
                    used_ocr = False
                    if needs_ocr:
                        import numpy as np
                        pixmap = page.get_pixmap(matrix=fitz.Matrix(2,2), colorspace=fitz.csRGB, alpha=False)
                        pixels = np.frombuffer(pixmap.samples, dtype=np.uint8).reshape(pixmap.height,pixmap.width,3)
                        result, _ = _ocr_engine()(pixels[:,:,::-1].copy())
                        lines = [str(item[1]).strip() for item in (result or []) if float(item[2]) >= .5]
                        if lines:
                            text = "\\n".join(lines)
                            used_ocr = True
                            needs_ocr = False
                            ocr_pages += 1
                        else:
                            scanned += 1
                    pages.append({"page_number": number, "text": text, "char_count": len(text),
                        "is_empty": not text, "ocr_needed": needs_ocr, "ocr_used": used_ocr})
        except Exception as exc:
            raise ValueError(f"Unable to extract {os.path.basename(pdf_path)}: {type(exc).__name__}") from exc
        return pages, {"total_pages": len(pages), "extractable_pages": sum(not p["is_empty"] for p in pages),
            "scanned_pages_count": scanned, "ocr_pages_count": ocr_pages}
''',encoding='utf-8')
p=Path('packages/rag-core/setup.py');s=p.read_text().replace('"sentence-transformers>=3.0.0",','"onnxruntime>=1.20.0",\n        "tokenizers>=0.20.0",\n        "rapidocr-onnxruntime>=1.2.3",');p.write_text(s)
p=Path('services/api/requirements.txt');s=p.read_text().replace('sentence-transformers==3.1.1','onnxruntime>=1.20.0\ntokenizers>=0.20.0\nrapidocr-onnxruntime>=1.2.3').replace('PyMuPDF==1.24.11','PyMuPDF>=1.26,<3').replace('numpy==1.26.4','numpy>=1.26,<3');p.write_text(s)
