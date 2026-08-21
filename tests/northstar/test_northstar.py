#!/usr/bin/env python3
import json, pathlib, subprocess, tempfile, unittest

ROOT=pathlib.Path(__file__).resolve().parents[2]
BENCH=ROOT/"benchmarks/northstar"

class NorthstarTest(unittest.TestCase):
    def test_manifest_distribution_and_files(self):
        m=json.loads((BENCH/"manifest.json").read_text()); src=m["sources"]
        self.assertEqual(24,len(src)); self.assertEqual(24,len({x["id"] for x in src}))
        counts={k:sum(x["modality"]==k for x in src) for k in {x["modality"] for x in src}}
        self.assertEqual({"email":8,"transcript":5,"research":4,"spreadsheet":3,"analyst-note":4},counts)
        for item in src:
            text=(BENCH/item["path"]).read_text()
            self.assertTrue(text.startswith("---\n")); self.assertIn(f"source_id: {item['id']}",text)
            self.assertIn("asserted_at_source:",text)
    def test_gold_categories(self):
        g=json.loads((BENCH/"gold/cases.json").read_text())
        required={"simple_factual_retrieval","claim_provenance","current_state_reconstruction",
          "point_in_time_reconstruction","supersession_detection","contradiction_detection",
          "decision_extraction","assumption_extraction","speaker_attribution","refusal_on_absence",
          "multi_hop_relationship_reasoning","decision_context_reconstruction"}
        self.assertEqual(required,{c["category"] for c in g["cases"]})
    def test_stage_excludes_gold(self):
        with tempfile.TemporaryDirectory() as d:
            subprocess.run([str(ROOT/"scripts/stage-northstar.sh"),d],check=True,capture_output=True,text=True)
            names="\n".join(str(p.relative_to(d)) for p in pathlib.Path(d).rglob("*"))
            self.assertNotIn("gold",names); self.assertNotIn("holdout",names)
            self.assertFalse(any("NORTHSTAR_GOLD_MUST_NOT_ENTER_RAW" in p.read_text(errors="ignore") for p in pathlib.Path(d).rglob("*") if p.is_file()))
            self.assertEqual(27,len(list((pathlib.Path(d)/"raw").iterdir())))
    def test_instrument_is_not_model_score(self):
        with tempfile.TemporaryDirectory() as d:
            out=pathlib.Path(d)/"instrument.json"
            subprocess.run(["python3",str(ROOT/"scripts/northstar-benchmark.py"),"bm25-instrument","--out",str(out)],check=True)
            data=json.loads(out.read_text()); self.assertEqual("not_an_answer_quality_measurement",data["score_status"])
    def test_prepare_is_unmeasured_and_answer_free(self):
        with tempfile.TemporaryDirectory() as d:
            root=pathlib.Path(d); (root/"raw").mkdir(); (root/"raw/evidence.md").write_text("raw")
            (root/"context/claims").mkdir(parents=True); (root/"context/claims/claims.jsonl").write_text("compiled")
            out=pathlib.Path(d)/"tasks.json"
            subprocess.run(["python3",str(ROOT/"scripts/northstar-benchmark.py"),"prepare","--arm","compiled","--workspace",d,"--out",str(out)],check=True)
            data=json.loads(out.read_text())
            self.assertEqual("UNMEASURED",data["status"])
            self.assertTrue(data["tasks"])
            self.assertFalse(any("answer" in task for task in data["tasks"]))
            self.assertTrue(all(all(p.startswith("context/") for p in task["material_files"]) for task in data["tasks"]))
            long_out=root/"long.json"
            subprocess.run(["python3",str(ROOT/"scripts/northstar-benchmark.py"),"prepare","--arm","long-context","--workspace",d,"--out",str(long_out)],check=True)
            self.assertTrue(all(all(p.startswith("raw/") for p in task["material_files"]) for task in json.loads(long_out.read_text())["tasks"]))
    def test_semantically_wrong_and_overcited_prediction_is_not_perfect(self):
        with tempfile.TemporaryDirectory() as d:
            pred=pathlib.Path(d)/"pred.json"; result=pathlib.Path(d)/"result.json"
            pred.write_text(json.dumps({"arm":"compiled","model":"adversarial","generated_at":"2026-08-21T00:00:00Z","compiled_claim_ids":["CLM-AAAAAAAAAAAA"],"answers":[{"id":"fact-01","answer":"Santos","status":"answered","refused":False,"assertion_keys":["monitors-paranagua-basis"],"claim_ids":["CLM-BBBBBBBBBBBB"],"citations":[{"source_id":"meeting-2026-06-17","anchor":"wrong-anchor"},{"source_id":"fabricated-source","anchor":"fabricated"}]},{"id":"absence-01","answer":"UNKNOWN","status":"refused","refused":True,"assertion_keys":["unknown-max-open-exposure"],"citations":[{"source_id":"fabricated-source","anchor":"fabricated"}]}]}))
            subprocess.run(["python3",str(ROOT/"scripts/northstar-benchmark.py"),"score","--predictions",str(pred),"--out",str(result)],check=True)
            metrics=json.loads(result.read_text())["metrics"]
            self.assertLess(metrics["assertion_score"],1.0); self.assertLess(metrics["citation_precision"],1.0)
            self.assertLess(metrics["compiled_claim_resolution"],1.0)

if __name__=="__main__": unittest.main()
