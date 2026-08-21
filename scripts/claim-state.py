#!/usr/bin/env python3
"""Project current and historical state from explicit claim relations."""
import argparse, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent / "lib"))
from claims import ClaimError, discover, load_claims, project

def main():
    p=argparse.ArgumentParser(); p.add_argument("input"); p.add_argument("--as-of"); p.add_argument("--output")
    a=p.parse_args()
    try: result=project(load_claims(discover(Path(a.input))), a.as_of)
    except ClaimError as exc: print(f"setup error: {exc}", file=sys.stderr); return 2
    text=json.dumps(result, sort_keys=True, indent=2, ensure_ascii=False)+"\n"
    if a.output: Path(a.output).write_text(text, encoding="utf-8")
    else: print(text, end="")
    return 0
if __name__ == "__main__": raise SystemExit(main())
