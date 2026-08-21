import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "lib"))
from claims import claim_id, project, validate_claim

import importlib.util
spec = importlib.util.spec_from_file_location("citation_audit", ROOT / "scripts" / "citation-audit.py")
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)


def make_claim(root, *, subject="northstar", predicate="assumes", obj="brl-5.50", klass="assumption", day="2026-06-01", source_id="email-june", relations=None):
    claim = {
        "profile": "client-decision",
        "classification": klass, "statement": f"{subject} {predicate} {obj}",
        "subject": subject, "predicate": predicate, "object": obj,
        "evidence_domain": "client",
        "valid_from": day, "valid_to": None,
        "source": {"id": source_id, "type": "email", "path": "raw/evidence.md", "anchor": "brl-assumption", "evidence_span": "BRL is 5.50.", "timestamp": day, "speaker": "Maria", "speaker_role": "client", "speaker_act": "assertion", "speaker_confidence": 0.98},
        "relations": relations or [],
    }
    if klass == "inference": claim["confidence"] = 0.8
    if klass == "derivation": claim["derivation"] = {"input_claim_ids": ["CLM-000000000000", "CLM-111111111111"], "operation": "subtract"}
    if klass == "unknown":
        claim.pop("object", None)
        claim["unknown"] = {"question": "What is unknown?", "inspected_scope": ["email-june"], "reason": "not stated"}
    claim["claim_id"] = claim_id(claim)
    return claim


class ClaimCoreTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.root = Path(self.tmp.name)
        (self.root / "raw").mkdir()
        (self.root / "raw/evidence.md").write_text("---\nsource_type: email\n---\n# BRL Assumption\nBRL is 5.50.\n", encoding="utf-8")

    def tearDown(self): self.tmp.cleanup()

    def errors(self, claim): return validate_claim(claim, self.root, module.resolve_anchor)

    def test_clean_claim_and_anchor_validate(self):
        self.assertEqual([], self.errors(make_claim(self.root)))

    def test_id_is_canonical_and_sensitive_to_identity(self):
        a = make_claim(self.root); b = dict(a); b["claim_id"] = "CLM-000000000000"
        self.assertRegex(claim_id(a), r"^CLM-[0-9A-F]{12}$")
        self.assertIn("claim_id mismatch", " ".join(self.errors(b)))

    def test_id_includes_public_profile(self):
        client = make_claim(self.root)
        project_claim = dict(client); project_claim["profile"] = "project-decision"
        self.assertNotEqual(claim_id(client), claim_id(project_claim))
        project_claim.pop("profile")
        project_claim["claim_id"] = claim_id(project_claim)
        self.assertIn("missing profile", " ".join(self.errors(project_claim)))

    def test_inference_derivation_unknown_contracts(self):
        inference = make_claim(self.root, klass="inference"); inference.pop("confidence"); inference["claim_id"] = claim_id(inference)
        derivation = make_claim(self.root, klass="derivation"); derivation.pop("derivation"); derivation["claim_id"] = claim_id(derivation)
        unknown = make_claim(self.root, klass="unknown"); unknown["object"] = "fabricated"; unknown["claim_id"] = claim_id(unknown)
        self.assertIn("inference requires", " ".join(self.errors(inference)))
        self.assertIn("derivation requires", " ".join(self.errors(derivation)))
        self.assertIn("must not contain object", " ".join(self.errors(unknown)))

    def test_controlled_domain_and_review_vocabulary(self):
        claim = make_claim(self.root); claim["evidence_domain"] = "everything"
        claim["review_triggers"] = ["invented-trigger"]
        claim["claim_id"] = claim_id(claim)
        errors = " ".join(self.errors(claim))
        self.assertIn("evidence_domain", errors); self.assertIn("review_triggers", errors)

    def test_attribution_and_date_are_strict(self):
        claim = make_claim(self.root); claim["source"].pop("speaker_role"); claim["source"]["timestamp"] = "yesterday"; claim["claim_id"] = claim_id(claim)
        errors = " ".join(self.errors(claim))
        self.assertIn("speaker_role", errors); self.assertIn("ISO timestamp", errors)

    def test_possibly_trap_cannot_become_client_assumption(self):
        claim = make_claim(self.root, klass="assumption")
        claim["statement"] = "Possibly."
        claim["source"]["speaker_act"] = "qualified-agreement"
        claim["claim_id"] = claim_id(claim)
        self.assertIn("may only classify as observation or unknown", " ".join(self.errors(claim)))

    def test_nonassertive_acts_are_observations_but_assertion_and_disagreement_remain_explicit(self):
        for speech_act in ("question", "hypothetical", "agreement", "qualified-agreement"):
            claim = make_claim(self.root, klass="observation")
            claim["source"]["speaker_act"] = speech_act
            claim["claim_id"] = claim_id(claim)
            self.assertEqual([], self.errors(claim), speech_act)
        for speech_act in ("assertion", "disagreement"):
            claim = make_claim(self.root, klass="fact")
            claim["source"]["speaker_act"] = speech_act
            claim["claim_id"] = claim_id(claim)
            self.assertEqual([], self.errors(claim), speech_act)

    def test_missing_and_ambiguous_anchor_fail(self):
        claim = make_claim(self.root); claim["source"]["anchor"] = "missing"; claim["claim_id"] = claim_id(claim)
        self.assertIn("anchor does not resolve", " ".join(self.errors(claim)))
        (self.root / "raw/evidence.md").write_text("# Same\na\n# Same!!!\nb\n", encoding="utf-8")
        claim["source"]["anchor"] = "same"; claim["claim_id"] = claim_id(claim)
        self.assertIn("anchor does not resolve", " ".join(self.errors(claim)))

    def test_explicit_temporal_projection(self):
        old = make_claim(self.root)
        new = make_claim(self.root, obj="brl-5.70", day="2026-08-01", source_id="email-aug", relations=[{"type":"supersedes", "target_claim_id":old["claim_id"]}])
        new["claim_id"] = claim_id(new)
        concern = make_claim(self.root, predicate="concern", obj="availability", day="2026-08-02", source_id="call-aug")
        contrary = make_claim(self.root, predicate="concern", obj="price", day="2026-08-02", source_id="note-aug", relations=[{"type":"contradicts", "target_claim_id":concern["claim_id"]}]); contrary["claim_id"] = claim_id(contrary)
        state = project([old, new, concern, contrary])
        self.assertEqual([old["claim_id"]], [c["claim_id"] for c in state["history"]])
        self.assertEqual({concern["claim_id"], contrary["claim_id"]}, {c["claim_id"] for c in state["unresolved"]})
        march = project([old, new], "2026-06-15")
        self.assertEqual([old["claim_id"]], [c["claim_id"] for c in march["current"]])

    def test_valid_to_closes_state_without_erasing_history(self):
        claim = make_claim(self.root)
        claim["valid_to"] = "2026-07-01"
        self.assertEqual([claim["claim_id"]], [c["claim_id"] for c in project([claim], "2026-08-01")["history"]])
        self.assertEqual([claim["claim_id"]], [c["claim_id"] for c in project([claim], "2026-06-15")["current"]])
        self.assertEqual([claim["claim_id"]], [c["claim_id"] for c in project([claim], "2026-07-01")["current"]])

    def test_reversed_validity_interval_fails(self):
        claim = make_claim(self.root)
        claim["valid_from"] = "2026-08-02T09:00:00Z"
        claim["valid_to"] = "2026-08-01"
        self.assertIn("valid_from must not be after valid_to", " ".join(self.errors(claim)))

    def test_historical_contradiction_is_not_current_unresolved(self):
        first = make_claim(self.root, predicate="concern", obj="availability")
        contrary = make_claim(self.root, predicate="concern", obj="price", source_id="note-june", relations=[{"type":"contradicts", "target_claim_id":first["claim_id"]}])
        contrary["claim_id"] = claim_id(contrary)
        replacement = make_claim(self.root, predicate="concern", obj="availability-current", day="2026-08-01", source_id="email-aug", relations=[{"type":"supersedes", "target_claim_id":first["claim_id"]}])
        replacement["claim_id"] = claim_id(replacement)
        state = project([first, contrary, replacement])
        self.assertNotIn(first["claim_id"], [c["claim_id"] for c in state["unresolved"]])
        self.assertIn(contrary["claim_id"], [c["claim_id"] for c in state["unresolved"]])
        self.assertEqual(1, len(state["contradictions"]))

    def test_iso_datetime_temporal_values(self):
        claim = make_claim(self.root)
        claim["valid_from"] = "2026-06-01T12:30:00Z"
        claim["valid_to"] = "2026-07-01T09:00:00+00:00"
        self.assertEqual([], self.errors(claim))
        self.assertEqual([claim["claim_id"]], [c["claim_id"] for c in project([claim], "2026-06-01")["current"]])
        self.assertEqual([claim["claim_id"]], [c["claim_id"] for c in project([claim], "2026-07-02")["history"]])

    def test_why_text_lookup_uses_flat_claim_fields(self):
        shard = self.root / "claims.jsonl"; claim = make_claim(self.root, obj="brl-5.70")
        claim["statement"] = "Northstar assumes BRL 5.70"
        shard.write_text(json.dumps(claim) + "\n", encoding="utf-8")
        command = [sys.executable, str(ROOT / "scripts/claim-why.py"), str(shard), "BRL 5.70"]
        result = json.loads(subprocess.check_output(command))
        self.assertEqual(claim["claim_id"], result["claim"]["claim_id"])

    def test_cli_is_byte_identical(self):
        shard = self.root / "claims.jsonl"; claim = make_claim(self.root)
        shard.write_text(json.dumps(claim) + "\n", encoding="utf-8")
        command = [sys.executable, str(ROOT / "scripts/claim-state.py"), str(shard)]
        self.assertEqual(subprocess.check_output(command), subprocess.check_output(command))


if __name__ == "__main__": unittest.main()
