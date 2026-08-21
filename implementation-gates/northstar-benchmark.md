# Gates: Northstar Benchmark

Scope: A public, synthetic, leakage-resistant 24-source decision-context benchmark with structured gold and honest baselines.

- [x] G1: Manifest contains exactly 24 unique synthetic sources in the agreed modality distribution.
  CHECK: bash scripts/verify-northstar-benchmark.sh
  EXPECT: corpus: 24 sources PASS
  EVIDENCE: `tests/northstar/test_northstar.py::NorthstarTest.test_manifest_distribution_and_files` verifies 8 email, 5 transcript, 4 research, 3 spreadsheet, and 4 analyst-note logical sources, unique IDs, source frontmatter, and files.

- [x] G2: Gold covers every required benchmark category and intentional UNKNOWN cases.
  CHECK: bash scripts/verify-northstar-benchmark.sh
  EXPECT: gold categories: PASS
  EVIDENCE: `benchmarks/northstar/gold/cases.json` has one independently stored case for each of the 12 required categories, including speaker refusal and unknown maximum exposure; `test_gold_categories` verifies the exact set.

- [x] G3: Compilation staging contains no gold, expected answer, or reserved metadata.
  CHECK: bash scripts/verify-northstar-benchmark.sh
  EXPECT: leakage gate: PASS
  EVIDENCE: `scripts/stage-northstar.sh` resolves only manifest paths below `sources/`; the verifier stages into a temporary directory and scans for gold keys, the reserved sentinel, and forbidden directories.

- [x] G4: Runner records compiled, long-context, and BM25 arms with measured/estimated/hypothetical separation.
  CHECK: bash scripts/verify-northstar-benchmark.sh
  EXPECT: baseline arms: PASS
  EVIDENCE: `scripts/northstar-benchmark.py` accepts only the three named arms and labels supplied-prediction scores `MEASURED`; deterministic BM25 output is labelled `not_an_answer_quality_measurement`. No estimated, hypothetical, or model score is generated. `scripts/verify-northstar-benchmark.sh` exercises both paths.
