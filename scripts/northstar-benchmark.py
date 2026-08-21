#!/usr/bin/env python3
"""Leakage-conscious scorer and BM25 retrieval instrument for Northstar."""
from __future__ import annotations
import argparse, collections, datetime, json, math, pathlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
BENCH = ROOT / "benchmarks" / "northstar"
ARMS = {"compiled", "long-context", "bm25"}
TOKEN = re.compile(r"[a-z0-9]+")

def load(path):
    return json.loads(pathlib.Path(path).read_text(encoding="utf-8"))

def tokens(text):
    return TOKEN.findall(text.lower())

def bm25(question, docs, top_k=5):
    q = collections.Counter(tokens(question)); n = len(docs)
    lengths = [len(d[2]) for d in docs]; avg = sum(lengths) / max(n, 1)
    dfs = collections.Counter(t for _, _, ts in docs for t in set(ts))
    scored = []
    for (sid, path, ts), dl in zip(docs, lengths):
        tf = collections.Counter(ts); score = 0.0
        for term in q:
            freq = tf[term]
            if not freq: continue
            idf = math.log(1 + (n - dfs[term] + .5) / (dfs[term] + .5))
            score += idf * freq * 2.2 / (freq + 1.2 * (1 - .75 + .75 * dl / avg))
        scored.append((score, sid, path))
    return [{"source_id": sid, "path": path, "score": round(score, 6)}
            for score, sid, path in sorted(scored, reverse=True)[:top_k]]

def instrument(out, top_k):
    manifest = load(BENCH / "manifest.json"); gold = load(BENCH / "gold/cases.json")
    docs = []
    for item in manifest["sources"]:
        p = BENCH / item["path"]
        docs.append((item["id"], item["path"], tokens(p.read_text(encoding="utf-8"))))
    payload = {"kind":"deterministic_retrieval_instrument","arm":"bm25",
               "score_status":"not_an_answer_quality_measurement","top_k":top_k,
               "generated_at":datetime.datetime.now(datetime.timezone.utc).isoformat(),
               "results":[{"id":c["id"],"retrieved":bm25(c["question"],docs,top_k)}
                          for c in gold["cases"]]}
    pathlib.Path(out).write_text(json.dumps(payload, indent=2)+"\n")
    print(f"BM25 instrument: {len(payload['results'])} queries; no model scores claimed")

def prepare(arm, workspace, out, top_k):
    """Prepare model-neutral tasks; this is not execution and contains no answers."""
    workspace = pathlib.Path(workspace).resolve()
    gold = load(BENCH / "gold/cases.json")
    manifest = load(BENCH / "manifest.json")
    docs=[]
    for item in manifest["sources"]:
        p=BENCH/item["path"]
        docs.append((item["id"], item["path"], tokens(p.read_text(encoding="utf-8"))))
    if arm == "compiled":
        shared=[str(p.relative_to(workspace)) for base in (workspace/"context/claims",workspace/"context/decisions") if base.exists() for p in base.rglob("*") if p.is_file()]
    elif arm == "long-context":
        shared=[str(p.relative_to(workspace)) for p in (workspace/"raw").rglob("*") if p.is_file()]
    else: shared=[]
    tasks=[]
    for case in gold["cases"]:
        if arm == "compiled":
            material="Use only compiled context under context/ and its referenced raw evidence."
        elif arm == "long-context":
            material="Use all evidence files under raw/ as the complete context."
        else:
            selected=bm25(case["question"],docs,top_k)
            names=", ".join("raw/"+pathlib.Path(x["path"]).name for x in selected)
            material=f"Use only these deterministic BM25 candidates: {names}."
        files=shared if arm != "bm25" else ["raw/"+pathlib.Path(x["path"]).name for x in selected]
        prompt=(f"{material}\nQuestion: {case['question']}\n"
                "Return JSON with answer, status, refused, semantic assertion_keys, citations as [{source_id,anchor}], and (compiled arm only) supporting CLM-* claim_ids. "
                "Use UNKNOWN/refused=true when evidence is insufficient; do not guess.")
        tasks.append({"id":case["id"],"question":case["question"],"prompt":prompt,"material_files":sorted(files)})
    payload={"kind":"northstar_prediction_tasks","status":"UNMEASURED","arm":arm,
             "workspace":str(workspace),"top_k":top_k if arm=="bm25" else None,"tasks":tasks}
    pathlib.Path(out).write_text(json.dumps(payload,indent=2)+"\n",encoding="utf-8")
    print(f"prepared {len(tasks)} {arm} tasks: UNMEASURED (no model executed)")

def score(pred_path, out):
    pred = load(pred_path); gold = load(BENCH / "gold/cases.json")
    if pred.get("arm") not in ARMS: raise SystemExit("prediction arm must be compiled, long-context, or bm25")
    if not pred.get("model") or not pred.get("generated_at"): raise SystemExit("predictions require model and generated_at")
    answers = {a["id"]:a for a in pred.get("answers",[])}
    rows=[]
    for case in gold["cases"]:
        got=answers.get(case["id"],{}); text=str(got.get("answer","")).lower()
        expected=case["answer"]; terms=expected.get("contains",[])
        content=sum(t.lower() in text for t in terms)/max(len(terms),1)
        refused=bool(got.get("refused",False)); refusal=(refused == bool(expected.get("refuse",False)))
        status_ok=got.get("status") == ("refused" if expected.get("refuse",False) else "answered")
        assertions=set(got.get("assertion_keys",[])); wanted_assertions=set(expected.get("assertion_keys",[])); forbidden=set(expected.get("forbidden_assertion_keys",[]))
        assertion_recall=len(assertions & wanted_assertions)/max(len(wanted_assertions),1)
        assertion_precision=(len(assertions & wanted_assertions)/len(assertions)) if assertions else (1.0 if not wanted_assertions else 0.0)
        assertion_score=assertion_recall*assertion_precision*(0.0 if assertions & forbidden else 1.0)
        wanted={(e["source_id"],e["anchor"]) for e in case.get("evidence",[])}
        cited={(e.get("source_id"),e.get("anchor")) for e in got.get("citations",[]) if isinstance(e,dict)}
        citation_recall=(len(wanted & cited)/len(wanted)) if wanted else (1.0 if not cited else 0.0)
        citation_precision=(len(wanted & cited)/len(cited)) if cited else (1.0 if not wanted else 0.0)
        provenance=2*citation_precision*citation_recall/(citation_precision+citation_recall) if citation_precision+citation_recall else 0.0
        catalog=set(pred.get("compiled_claim_ids",[])); supplied=set(got.get("claim_ids",[]))
        claim_resolution=(sum(bool(re.fullmatch(r"CLM-[0-9A-F]{12}",x)) and x in catalog for x in supplied)/len(supplied)) if supplied else (0.0 if pred["arm"]=="compiled" and not expected.get("refuse") else 1.0)
        rows.append({"id":case["id"],"category":case["category"],"content_recall":round(content,4),
                     "status_correct":status_ok,"refusal_correct":refusal,"assertion_score":round(assertion_score,4),
                     "citation_precision":round(citation_precision,4),"citation_recall":round(citation_recall,4),"citation_f1":round(provenance,4),
                     "compiled_claim_resolution":round(claim_resolution,4) if pred["arm"]=="compiled" else None})
    summary={k:round(sum(float(r[k]) for r in rows)/len(rows),4)
             for k in ("content_recall","status_correct","refusal_correct","assertion_score","citation_precision","citation_recall","citation_f1")}
    if pred["arm"]=="compiled": summary["compiled_claim_resolution"]=round(sum(r["compiled_claim_resolution"] for r in rows)/len(rows),4)
    result={"status":"MEASURED","measurement":"gold-key lexical/provenance instrument",
            "arm":pred["arm"],"model":pred["model"],"case_count":len(rows),"metrics":summary,"cases":rows}
    pathlib.Path(out).write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(result["metrics"],sort_keys=True))

def main():
    p=argparse.ArgumentParser(); sub=p.add_subparsers(dest="cmd",required=True)
    b=sub.add_parser("bm25-instrument"); b.add_argument("--out",required=True); b.add_argument("--top-k",type=int,default=5)
    s=sub.add_parser("score"); s.add_argument("--predictions",required=True); s.add_argument("--out",required=True)
    q=sub.add_parser("prepare"); q.add_argument("--arm",choices=sorted(ARMS),required=True); q.add_argument("--workspace",required=True); q.add_argument("--out",required=True); q.add_argument("--top-k",type=int,default=5)
    a=p.parse_args()
    if a.cmd=="bm25-instrument": instrument(a.out,a.top_k)
    elif a.cmd=="prepare": prepare(a.arm,a.workspace,a.out,a.top_k)
    else: score(a.predictions,a.out)
if __name__ == "__main__": main()
