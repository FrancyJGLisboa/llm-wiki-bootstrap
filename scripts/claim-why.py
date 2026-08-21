#!/usr/bin/env python3
"""Return an inspectable evidence and relation chain for one claim."""
import argparse, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from claims import ClaimError, discover, load_claims, public

def main():
    p=argparse.ArgumentParser(); p.add_argument("input"); p.add_argument("claim")
    a=p.parse_args()
    try: claims=load_claims(discover(Path(a.input)))
    except ClaimError as exc: print(f"setup error: {exc}",file=sys.stderr); return 2
    by={c["claim_id"]:c for c in claims}; selected=by.get(a.claim)
    if selected is None:
        needle=a.claim.lower()
        matches=[c for c in claims if needle in " ".join(str(c.get(field,"")) for field in ("statement","subject","predicate","object")).lower()]
        if len(matches)!=1:
            print(json.dumps({"error":"claim not uniquely resolved","matches":[c["claim_id"] for c in matches]},sort_keys=True)); return 1
        selected=matches[0]
    incoming=[]
    for claim in claims:
        for relation in claim.get("relations",[]):
            if relation["target_claim_id"]==selected["claim_id"]: incoming.append({"claim":claim["claim_id"],"type":relation["type"]})
    inputs=[]
    for cid in (selected.get("derivation") or {}).get("input_claim_ids",[]):
        if cid in by: inputs.append(public(by[cid]))
    result={"claim":public(selected),"evidence":selected.get("source"),"incoming_relations":sorted(incoming,key=lambda x:(x["type"],x["claim"])),"derivation_inputs":inputs}
    print(json.dumps(result,sort_keys=True,indent=2,ensure_ascii=False)); return 0
if __name__ == "__main__": raise SystemExit(main())
