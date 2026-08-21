import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO / "scripts" / "lib"))
from claims import claim_id  # noqa: E402


def make_claim(source_id, statement, subject, predicate, obj=None, *, classification="fact", valid_from="2026-06-01", relations=None, triggers=None, speaker="Maria Silva", act="assertion"):
    claim = {
        "profile": "client-decision", "claim_id": "pending", "classification": classification,
        "statement": statement, "subject": subject, "predicate": predicate,
        "evidence_domain": "client", "valid_from": valid_from, "valid_to": None,
        "source": {"id": source_id, "type": "email-export", "path": f"raw/{source_id}.md", "timestamp": valid_from + "T10:00:00Z", "anchor": "evidence", "evidence_span": statement, "speaker": speaker, "speaker_role": "client", "speaker_act": act, "speaker_confidence": 1.0},
        "relations": relations or [], "review_triggers": triggers or [],
    }
    if obj is not None:
        claim["object"] = obj
    if classification == "unknown":
        claim["unknown"] = {"question": statement, "inspected_scope": [source_id], "reason": "not present in evidence"}
    claim["claim_id"] = claim_id(claim)
    return claim


class ClientContextTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        (self.root / "raw").mkdir()
        (self.root / "context/claims/by-source").mkdir(parents=True)
        (self.root / "context/decisions/northstar-feeds").mkdir(parents=True)

        old_fx = make_claim("june-email", "Northstar assumes BRL/USD 5.50.", "northstar-feeds", "assumes", "BRL/USD 5.50", classification="assumption", valid_from="2026-06-01")
        new_fx = make_claim("aug-email", "Northstar assumes BRL/USD approximately 5.70.", "northstar-feeds", "assumes", "BRL/USD 5.70", classification="assumption", valid_from="2026-08-19", relations=[{"type": "supersedes", "target_claim_id": old_fx["claim_id"]}])
        decision = make_claim("aug-call", "Q1 soymeal coverage is under active consideration.", "northstar-feeds", "considering", "q1-soymeal-coverage", valid_from="2026-08-13")
        variable = make_claim("research-note", "The decision depends on Brazil crush.", "northstar-feeds", "depends-on", "brazil-crush", valid_from="2026-06-01", speaker="Ana Costa")
        concern_old = make_claim("july-call", "Northstar reports low concern about physical availability.", "northstar-feeds", "monitors", "physical-availability-low", valid_from="2026-07-01")
        concern_new = make_claim("aug-call-2", "Northstar reports elevated concern about physical availability.", "northstar-feeds", "monitors", "physical-availability-elevated", valid_from="2026-08-19", relations=[{"type": "updates", "target_claim_id": concern_old["claim_id"]}])
        covered = make_claim("july-coverage", "Northstar is fully covered through December.", "northstar-feeds", "exposed-to", "q4-open-0", valid_from="2026-07-15")
        open_claim = make_claim("aug-coverage", "Northstar still has 20% of Q4 open.", "northstar-feeds", "exposed-to", "q4-open-20", valid_from="2026-08-10", relations=[{"type": "contradicts", "target_claim_id": covered["claim_id"]}], triggers=["contradiction"])
        unknown = make_claim("aug-call-3", "What is Northstar's maximum acceptable open exposure?", "northstar-feeds", "questions", classification="unknown", valid_from="2026-08-19")
        qualified = make_claim("aug-call-4", "Maria said possibly in response to the analyst's demand scenario.", "northstar-feeds", "responds-to", "china-demand-down-5", classification="observation", valid_from="2026-08-19", act="qualified-agreement")
        self.claims = [old_fx, new_fx, decision, variable, concern_old, concern_new, covered, open_claim, unknown, qualified]
        for claim in self.claims:
            (self.root / claim["source"]["path"]).write_text("# Evidence\n\n" + claim["source"]["evidence_span"] + "\n", encoding="utf-8")
        with (self.root / "context/claims/by-source/fixture.jsonl").open("w", encoding="utf-8") as handle:
            for claim in self.claims:
                handle.write(json.dumps(claim, sort_keys=True) + "\n")
        projection = {
            "decision_id": "DEC-q1-soymeal-coverage", "subject": "northstar-feeds", "description": "Increase Q1 soymeal coverage",
            "status": "evaluating", "owner": None, "decision_window": "2026-Q1", "time_horizon": "Q1",
            "commodities": ["soymeal"], "geographies": ["Brazil"], "assets": [], "variables": ["brazil-crush", "BRL/USD"],
            "assumptions": [new_fx["claim_id"]], "constraints": [], "triggers": [], "risks": [], "open_questions": [unknown["claim_id"]],
            "supporting_claim_ids": [c["claim_id"] for c in self.claims],
            "current_state": {"valid_from": "2026-08-13", "valid_to": None, "status": "evaluating", "claim_ids": [decision["claim_id"]]},
            "historical_states": [{"valid_from": "2026-06-01", "valid_to": "2026-08-12", "status": "monitoring", "claim_ids": [variable["claim_id"]]}],
        }
        (self.root / "context/decisions/northstar-feeds/q1-soymeal.json").write_text(json.dumps(projection), encoding="utf-8")
        self.ids = {"old_fx": old_fx["claim_id"], "new_fx": new_fx["claim_id"], "decision": decision["claim_id"], "qualified": qualified["claim_id"]}

    def tearDown(self):
        self.temp.cleanup()

    def invoke(self, *args):
        result = subprocess.run([sys.executable, str(REPO / "scripts/client-context.py"), "--root", str(self.root), *args, "--json"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def test_brief_is_evidence_grounded_and_does_not_promote_qualified_agreement(self):
        result = self.invoke("brief", "northstar-feeds")
        self.assertIn("brazil-crush", result["exposures_and_material_variables"])
        self.assertEqual([self.ids["new_fx"]], [c["claim_id"] for c in result["active_assumptions"]])
        self.assertTrue(all(c["citation"].startswith("raw/") for c in result["evidence"]))
        self.assertNotIn(self.ids["qualified"], [c["claim_id"] for c in result["active_assumptions"]])
        self.assertTrue(result["contradictions"])

    def test_delta_uses_explicit_temporal_relations(self):
        result = self.invoke("delta", "northstar-feeds", "--since", "2026-06-30")
        self.assertIn(self.ids["old_fx"], [c["claim_id"] for c in result["SUPERSEDED"]])
        self.assertTrue(result["CHANGED"])
        self.assertTrue(result["UNRESOLVED"])
        self.assertEqual(["NEW", "CHANGED", "SUPERSEDED", "UNRESOLVED", "UNCHANGED BUT MATERIAL"], list(result))

    def test_as_of_and_why_unknown(self):
        decisions = self.invoke("decisions", "northstar-feeds", "--as-of", "2026-06-30")
        self.assertEqual("monitoring", decisions["decisions"][0]["status"])
        why = self.invoke("why", "northstar-feeds", self.ids["new_fx"])
        self.assertEqual("SUPPORTED", why["status"])
        self.assertEqual("Maria Silva", why["evidence_chain"][0]["speaker"])
        self.assertEqual("current", why["temporal_state"])
        self.assertEqual([self.ids["old_fx"]], [c["claim_id"] for c in why["previous_related_claims"]])
        absent = self.invoke("why", "northstar-feeds", "maximum tolerance is 25 percent")
        self.assertEqual("UNKNOWN", absent["status"])
        unknown = next(c for c in self.claims if c["classification"] == "unknown")
        explained_unknown = self.invoke("why", "northstar-feeds", unknown["claim_id"])
        self.assertEqual("UNKNOWN", explained_unknown["status"])
        self.assertEqual(["aug-call-3"], explained_unknown["inspected_scope"])
        self.assertIn("not present", explained_unknown["reason"])
        self.assertEqual(unknown["claim_id"], explained_unknown["evidence"]["claim_id"])

    def test_as_of_handles_mixed_date_and_datetime_states(self):
        path = self.root / "context/decisions/northstar-feeds/q1-soymeal.json"
        decision = json.loads(path.read_text(encoding="utf-8"))
        decision["historical_states"][0]["valid_to"] = "2026-08-12T23:59:59Z"
        decision["current_state"]["valid_from"] = "2026-08-13T09:30:00-03:00"
        path.write_text(json.dumps(decision), encoding="utf-8")
        before = self.invoke("decisions", "northstar-feeds", "--as-of", "2026-08-12T18:00:00Z")
        after = self.invoke("decisions", "northstar-feeds", "--as-of", "2026-08-13T13:00:00Z")
        self.assertEqual("monitoring", before["decisions"][0]["status"])
        self.assertEqual("evaluating", after["decisions"][0]["status"])

    def test_review_and_lint_are_transparent(self):
        review = self.invoke("review", "northstar-feeds")
        self.assertGreater(review["count"], 0)
        self.assertTrue(all(item["reason"] for item in review["items"]))
        lint = self.invoke("lint", "northstar-feeds")
        self.assertEqual(100.0, lint["citation_resolution"]["percentage"])
        (self.root / "raw/research-note.md").write_text("source remains present but anchor is absent\n", encoding="utf-8")
        lint_bad_anchor = self.invoke("lint", "northstar-feeds")
        self.assertEqual(90.0, lint_bad_anchor["citation_resolution"]["percentage"])
        self.assertIn("unknown_decision_owners", lint)
        self.assertNotIn("score", lint)


if __name__ == "__main__":
    unittest.main()
