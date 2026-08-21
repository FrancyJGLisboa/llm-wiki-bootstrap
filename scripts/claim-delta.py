#!/usr/bin/env python3
"""Compare two deterministic temporal claim projections."""
import argparse, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from claims import ClaimError, discover, load_claims, project

def main():
    p=argparse.ArgumentParser(); p.add_argument("input"); p.add_argument("--since", required=True); p.add_argument("--as-of")
    a=p.parse_args()
    try:
        claims=load_claims(discover(Path(a.input))); before=project(claims,a.since); after=project(claims,a.as_of)
    except ClaimError as exc: print(f"setup error: {exc}",file=sys.stderr); return 2
    old={c["claim_id"] for c in before["current"]}; new={c["claim_id"] for c in after["current"]}
    by={c["claim_id"]:c for c in claims}
    result={"since":a.since,"as_of":a.as_of or "latest","new":[by[x] for x in sorted(new-old)],"no_longer_current":[by[x] for x in sorted(old-new)],"unchanged":[by[x] for x in sorted(old&new)],"unresolved":after["unresolved"]}
    for values in result.values():
        if isinstance(values,list):
            for value in values:
                if isinstance(value,dict): value.pop("_location",None)
    print(json.dumps(result,sort_keys=True,indent=2,ensure_ascii=False)); return 0
if __name__ == "__main__": raise SystemExit(main())
