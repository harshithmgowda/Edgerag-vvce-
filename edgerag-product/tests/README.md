# 🧪 Track 5: QA, Benchmarking & Evaluations (`tests/`)

**Assigned Responsibility**: Shared (QA Lead / AI Lead / All Members)  
**Tech Stack**: Pytest, Python 3.11+, Rigorous Ground-Truth Benchmark Suite  
**Git Scope**: `test(eval): <description>` or `test(unit): <description>`  
**Primary Report**: [`docs/EVALUATION_REPORT.md`](../docs/EVALUATION_REPORT.md)

---

## 🎯 Benchmark Objectives

To give judges empirical evidence that EdgeRAG is reliable, genuinely adaptive, and air-gap ready, we test 25 verified benchmark questions across 4 categories:
1. **Exact Error Codes** (7 queries): Verification that alphanumeric codes (`E-104`, `ERR-4029`, `F02`) achieve 100% retrieval hit rate.
2. **Paraphrased Symptoms** (6 queries): Testing that differing terminology (*"water stays inside"* $\rightarrow$ *"Drainage troubleshooting"*) succeeds via semantic embedding + query rewriting.
3. **Multi-Passage Synthesis** (6 queries): Testing cross-section reasoning (e.g. electrical LOTO on p. 25 + hydraulic torque on p. 22).
4. **Out-of-Scope Safety Refusal** (6 queries): Guaranteeing that queries missing manual evidence are safely refused rather than hallucinated.

---

## 📁 Folder Structure

```
tests/
├── eval/
│   └── eval_benchmark.py     # 25-Question Ground-Truth Benchmark Suite
├── unit/
│   ├── test_rag_pipeline.py  # Unit tests for reasoner, verifier, and legacy package scoping
│   └── test_rag_quality.py   # Unit tests for OCR blank page skip, hybrid scoring & evidence gating
└── README.md                 # This track guide
```

---

## 🚀 Running the Test Suites

### 1. Run All Unit Tests
```bash
pytest tests/unit
```

### 2. Run the 25-Question Benchmark & Generate Report
```bash
python tests/eval/eval_benchmark.py
```
This automatically updates [`docs/EVALUATION_REPORT.md`](../docs/EVALUATION_REPORT.md) with measured scores:
- **Retrieval Hit Rate (Top-1 & Top-3)**
- **Answer Correctness**
- **Source Support Accuracy**
- **Appropriate Refusal Rate**
- **Offline Completion Rate**

---

## 📤 Git Commit & Contribution Guide

When making changes to tests and benchmarks:

```bash
git checkout -b test/benchmark-expansion
# Add new questions to tests/eval/eval_benchmark.py
git add tests/
git commit -m "test(eval): add 5 additional industrial motor vibration test queries"
git push origin test/benchmark-expansion
```
