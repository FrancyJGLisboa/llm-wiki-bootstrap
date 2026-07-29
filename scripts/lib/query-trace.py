#!/usr/bin/env python3
"""query-trace.py <stream.json> [--counts <out>]

Extract the final answer text from a `claude -p --output-format stream-json
--verbose` transcript, and count what the agent READ to produce it. The reads
count is the scale eval's cost metric: retrieval that stays cheap as the wiki
grows reads O(hops) files, not O(corpus).

stdout: the answer text (the `result` event's text; falls back to concatenated
assistant text; falls back to the raw file so API-error markers stay visible
to retr_answer_broken).

--counts <out>: writes one line, e.g.
  reads_wiki=4 reads_raw=2 reads_other=1 greps=3
where reads_* are Read tool calls bucketed by path, and greps counts Grep /
Glob tool calls plus Bash commands that shell out to grep/rg (an agent that
greps the tree into context instead of Reading must not look free).
"""
import json
import sys


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__, file=sys.stderr)
        return 2
    path = sys.argv[1]
    counts_out = None
    if "--counts" in sys.argv:
        counts_out = sys.argv[sys.argv.index("--counts") + 1]

    try:
        with open(path, encoding="utf-8", errors="replace") as fh:
            raw = fh.read()
    except OSError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1

    result_text = None
    assistant_text = []
    reads_wiki = reads_raw = reads_other = greps = 0

    for line in raw.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") == "result" and isinstance(ev.get("result"), str):
            result_text = ev["result"]
        content = (ev.get("message") or {}).get("content")
        if not isinstance(content, list):
            continue
        for block in content:
            if not isinstance(block, dict):
                continue
            if block.get("type") == "text" and ev.get("type") == "assistant":
                assistant_text.append(block.get("text", ""))
            if block.get("type") != "tool_use":
                continue
            name = block.get("name", "")
            inp = block.get("input") or {}
            if name == "Read":
                fp = str(inp.get("file_path", ""))
                if "/wiki/" in fp or fp.endswith("index.md"):
                    reads_wiki += 1
                elif "/raw/" in fp:
                    reads_raw += 1
                else:
                    reads_other += 1
            elif name in ("Grep", "Glob"):
                greps += 1
            elif name == "Bash":
                cmd = str(inp.get("command", ""))
                if "grep" in cmd or "rg " in cmd:
                    greps += 1

    answer = result_text if result_text is not None else "\n".join(assistant_text)
    if not answer.strip():
        answer = raw  # keep API-error markers visible to the grader
    sys.stdout.write(answer)

    if counts_out:
        with open(counts_out, "w", encoding="utf-8") as fh:
            fh.write(
                f"reads_wiki={reads_wiki} reads_raw={reads_raw} "
                f"reads_other={reads_other} greps={greps}\n"
            )
    return 0


if __name__ == "__main__":
    sys.exit(main())
