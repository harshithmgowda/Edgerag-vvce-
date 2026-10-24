from setuptools import setup, find_packages

setup(
    name="edgerag-core",
    version="1.0.0",
    description="EdgeRAG Deterministic PDF Extraction, Chunking, Embedding, and Package Builder",
    packages=find_packages(),
    install_requires=[
        "PyMuPDF>=1.24.0",
        "onnxruntime>=1.20.0",
        "tokenizers>=0.20.0",
        "rapidocr-onnxruntime>=1.2.3",
        "numpy>=1.24.0",
    ],
)
