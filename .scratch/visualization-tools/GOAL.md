---
name: visualization-tools
status: ready-for-agent
created: 2026-05-26
revised: 2026-05-26 (post-adversarial-pass)
---

# Integrated open-source visualization tools for llm-wiki-bootstrap

> Add a small `scripts/visualize/` directory of opt-in wrappers that give the persona "wow"-grade visual affordances (graph view, slide rendering, diagram rendering, local browsing) without coupling the bootstrap to Obsidian or any closed-source tool.

## §1 Context

The bootstrap is viewer-agnostic (`README.md`: "No Obsidian dependency"). Users who don't have or don't want Obsidian have only mermaid code fences, the MCP server, and the Anki exporter for "visualization." For the persona (mid-technical knowledge worker — research analyst, journalist, librarian, PM, indie consultant; comfortable installing CLI tools, won't write code, has Claude Code installed), the wiki is text-only despite the LLM building a rich `[[wiki-link]]` connective tissue underneath.

This iteration ships **integrated, open-source** visualization wrappers — each opt-in, each wrapping a well-known OSS tool — under `scripts/visualize/`. The marquee deliverable is a **bespoke graph-view generator** in pure Python (stdlib only) so the persona gets the "wow" moment with zero npm install.

**Why this change is being made.** Closing the persona's perception gap: today the wiki looks like a folder of markdown; after this iteration, one command (`./scripts/visualize/graph.sh wiki/ > graph.html`) shows the connective structure visually.

**Intended outcome.** A `scripts/visualize/verify-visualizers.sh` umbrella that exits 0 — graph smoke ALWAYS runs (pure Python, no install required); slides/mermaid smokes skip-when-absent (the npx tool isn't installed) — while the prior `smoke-all.sh` and `verify-create-llm-wiki.sh` umbrellas both stay green.

## §2 Definition of done (one sentence)

Running `./scripts/visualize/verify-visualizers.sh && ./scripts/smoke-all.sh > /dev/null && ./scripts/verify-create-llm-wiki.sh > /dev/null` exits 0: the graph generator produces a structurally-correct HTML with the right node/edge count against a deterministic canary fixture; the slides/mermaid/serve wrapper scripts have proper shebangs and skip cleanly when their underlying npm tools are absent; and neither prior iteration's umbrella regresses.

## §3 Success checks (the oracle)

All 9 must be green. The /goal completion condition is:
`./scripts/visualize/verify-visualizers.sh && ./scripts/smoke-all.sh > /dev/null && ./scripts/verify-create-llm-wiki.sh > /dev/null`

> **Timing note (critical):** the §3 completion oracle (the three-command chain above) is evaluated **ONLY at step 8**. Earlier steps' sole gate is the narrow Verify predicate listed in that step's entry in §6. **R2 will be transiently red from step 2 through step 5** because new files exist in the dev repo before step 6 syncs the installer manifest. That transient red is **expected** and is **not a stop condition** for the /goal loop. The completion oracle treats steps 1–7 as build-up and step 8 as the gate.

### Visualizer checks (V1, V2, V2b, V3, V4, V5 — 6 total)

| # | Check | How to verify (shell predicate) |
|---|---|---|
| V1 | Graph script shape | `head -1 scripts/visualize/graph.sh \| grep -q '^#!/usr/bin/env bash' && [ -x scripts/visualize/graph.sh ] && head -1 scripts/visualize/graph-html.py \| grep -qE '^#!/usr/bin/env python3?\|^#!.*python3'` |
| V2 | **Graph generator works against the FLAT canary** (anti-gaming) | `graph-html.py` MUST emit a `<script id="graph-data" type="application/json">…</script>` block containing the node+link arrays. Run `./scripts/visualize/graph.sh tests/canary/graph-fixture/ > /tmp/g.html`; in /tmp/g.html: `grep -q 'd3'` AND `python3 -c "import re,json,sys; m=re.search(r'<script id=\"graph-data\"[^>]*>(.*?)</script>', open('/tmp/g.html').read(), re.S); d=json.loads(m.group(1)); sys.exit(0 if len(d['nodes'])==4 and len(d['links'])==4 else 1)"`. Uses dedicated `<script>` block (not a regex over the whole JSON) so the parse is robust to future JSON shape changes. |
| V2b | **Graph generator works against the NESTED canary** (anti-gaming via recursion) | Same as V2 but against `tests/canary/graph-fixture-nested/` which contains `root.md` + `sub/leaf.md` (2 nodes total, 1 link). The asserted counts are 2 nodes + 1 link. This forces the parser to be RECURSIVE — a `glob('*.md')` implementation that passes V2 will fail V2b because `sub/leaf.md` is unreachable without recursion. |
| V3 | Wrapper script shape | For each of `scripts/visualize/{slides,mermaid,serve}.sh`: `[ -x "$F" ]` AND `head -1 "$F" \| grep -q '^#!/usr/bin/env bash'` AND `bash -n "$F"` exits 0. |
| V4 | **Verify-visualizers harness exits 0 + anti-skip-gaming** | `./scripts/visualize/verify-visualizers.sh` exits 0. Inside: graph smokes (V2 + V2b) ALWAYS run (pure Python). For each of `marp-cli` and `mermaid-cli`: detect availability via `command -v npx && npx -y <pkg>@latest --version > /dev/null 2>&1`. **Anti-gaming guard:** if the tool IS available, the harness MUST run its smoke (and the captured output MUST NOT contain `skipped: <toolname>`). If the tool is absent, print exactly `skipped: <toolname> not installed (install: npx -y <pkg>@latest --version)` and don't fail. The verifier ALSO live-smokes `serve.sh`: invokes it with env `VISUALIZE_DRY_RUN=1` and asserts it exits 0 without binding a port (script must honor the dry-run env). |
| V5 | Docs cover all 4 visualizers + alternatives | `grep -q 'graph.sh' docs/VISUALIZATION.md && grep -q 'slides.sh' docs/VISUALIZATION.md && grep -q 'mermaid.sh' docs/VISUALIZATION.md && grep -q 'serve.sh' docs/VISUALIZATION.md && grep -qiE 'quartz\|mdbook\|silverbullet' docs/VISUALIZATION.md`. Note: ERE `\|` is a literal pipe character — use `grep -qiE 'quartz\|mdbook\|silverbullet' docs/VISUALIZATION.md` works ONLY if the doc contains the literal three-word string. Correct form: `grep -qiE 'quartz|mdbook|silverbullet' docs/VISUALIZATION.md` (no backslashes; ERE alternation). |

### Regression guards (R1–R3)

| # | Check | How to verify |
|---|---|---|
| R1 | Prior smoke umbrella stays green | `./scripts/smoke-all.sh > /dev/null` exits 0 |
| R2 | Prior installer umbrella stays green | `./scripts/verify-create-llm-wiki.sh` exits 0 (validates `installer-skeleton-manifest.txt` stays in sync with the new visualize/ files we append) |
| R3 | Dev-repo protected files intact | `[ -f raw/smoke-source.md ] && [ -f wiki/four-principles.md ] && [ -f wiki/quortex-protocol.md ] && [ -f scripts/smoke-all.sh ] && [ -f scripts/create-llm-wiki.sh ]` |

**Baseline counts (verbatim, captured 2026-05-26):**
- `./scripts/smoke-all.sh > /dev/null; echo $?` → 0
- `./scripts/verify-create-llm-wiki.sh > /dev/null; echo $?` → 0
- `ls scripts/*.sh | wc -l` → 10
- `ls scripts/visualize/ 2>/dev/null | wc -l` → 0 (directory doesn't exist yet)
- `cat scripts/installer-skeleton-manifest.txt | wc -l` → 31

## §4 Scope

**In scope** (the agent may freely create/modify):
- `scripts/visualize/` (new dir): `graph.sh`, `graph-html.py`, `slides.sh`, `mermaid.sh`, `serve.sh`, `verify-visualizers.sh`
- `tests/canary/graph-fixture/`: 4 small `.md` files with deterministic `[[link]]` structure (4 nodes, 4 edges)
- `docs/VISUALIZATION.md` (new)
- `scripts/installer-skeleton-manifest.txt`: append the 6 new visualize scripts + 1 doc + 4 canary fixtures so they ship to fresh installs
- `README.md`: one new section pointing at `docs/VISUALIZATION.md`
- `.scratch/visualization-tools/`: working notes

**Adjacent-creep boundary rule:** conservative default = **leave it; don't force it**. The visualize scripts must not modify any wiki content; they read-only consume the wiki and emit derived artifacts (HTML, PNG, slides) to stdout or user-named paths.

**Out of scope:** see §8.

## §5 Deliverable artifacts

| Path | Purpose | Notes |
|---|---|---|
| `scripts/visualize/graph-html.py` | Bespoke graph generator | Python 3, stdlib only. Walks an input dir's `*.md`, regex-parses `[[kebab-case]]` references, builds nodes (one per .md file) and links (one per non-self link, deduplicated by `(source,target)`). Emits ONE HTML file with `<script src="https://d3js.org/d3.v7.min.js">` (default) OR embedded D3 if `--inline` flag set. JSON nodes/links are embedded in a `<script>` block. ~150 lines. |
| `scripts/visualize/graph.sh` | Thin wrapper around `graph-html.py` | One positional arg `<wiki-dir>`; optional `--inline`, `--out <path>`. Defaults to stdout. Checks for python3 (hard fail if missing); calls `graph-html.py` and writes its stdout. |
| `scripts/visualize/slides.sh` | MARP wrapper | One positional arg `<wiki-page.md>`. Checks for `npx` (clear install hint if missing — same idiom as `scripts/mcp-server.sh`). Runs `npx -y @marp-team/marp-cli@latest <input> -o <output>` writing slides next to the source. |
| `scripts/visualize/mermaid.sh` | Mermaid CLI wrapper | One positional arg `<wiki-page.md>`. Checks for `npx`. Runs `npx -y @mermaid-js/mermaid-cli@latest -i <input> -o <output>` (mmdc auto-detects mermaid blocks). |
| `scripts/visualize/serve.sh` | Static dev server | Wraps `python3 -m http.server`. Optional positional arg `<dir>` (default: `.`). Prints "Serving on http://localhost:8000" and exec's the python module. |
| `scripts/visualize/verify-visualizers.sh` | Oracle | Always runs the graph smoke against `tests/canary/graph-fixture/`. For each of slides/mermaid: `if command -v npx && npx -y <pkg> --version > /dev/null 2>&1; then run smoke; else print 'skipped'; fi`. Each smoke writes to `mktemp`-created paths and asserts shape on the output. Exits 0 iff graph smoke passed AND any present-tool smoke passed. |
| `docs/VISUALIZATION.md` | User guide | Per-script usage, install hints (npx install commands inline), and a "Heavier alternatives" section listing Quartz, mdBook, SilverBullet with one-line each. ~80–120 lines. |
| `tests/canary/graph-fixture/page-a.md` | Flat canary 1 | Body contains `[[page-b]]` and `[[page-c]]`. Minimal frontmatter. |
| `tests/canary/graph-fixture/page-b.md` | Flat canary 2 | Body contains `[[page-c]]`. |
| `tests/canary/graph-fixture/page-c.md` | Flat canary 3 | Body contains `[[page-d]]`. |
| `tests/canary/graph-fixture/page-d.md` | Flat canary 4 | No outgoing `[[links]]`. Together: 4 nodes, 4 unique edges. Tests basic parsing. |
| `tests/canary/graph-fixture-nested/root.md` | Nested canary 1 | Body contains `[[leaf]]`. Lives at the top of the fixture. |
| `tests/canary/graph-fixture-nested/sub/leaf.md` | Nested canary 2 | No outgoing links. Lives in a subdir — recursion is required to find it. Together: 2 nodes, 1 unique edge. Tests recursive traversal (anti-gaming for hardcoded-counts AND for non-recursive `glob('*.md')` implementations). |

### Graph generator algorithm (`graph-html.py`)

```text
1. argparse: <input-dir> positional; --inline; --out (default: stdout)
2. Collect *.md files RECURSIVELY under input-dir using pathlib.Path.rglob('*.md')
   — recursion is REQUIRED to handle wiki/journal/*.md and any future subdirs.
3. For each file: derive node id = file STEM (basename without .md). If two files
   have the same stem in different subdirs, that's a collision; abort with a
   clear error rather than silently merging.
4. For each file: parse body, collect [[kebab-case]] references via regex
   r'\[\[([a-z0-9-]+)\]\]' (anchored ASCII slugs only — matches our wiki link
   convention; ignores anything fancier).
5. Build nodes = list of {id: stem} for every .md file. Sort by id (deterministic
   output).
6. Build links = list of {source, target} for each (file, reference) pair where:
   (a) reference != self (no self-links)
   (b) reference IS in the nodes set — **dangling links to non-existent pages
       are silently dropped** (do NOT create ghost nodes). Document this
       behavior in docs/VISUALIZATION.md.
   Dedup by (source, target). Sort by (source, target) for deterministic output.
7. Render HTML with:
   - <script src=https://d3js.org/d3.v7.min.js> by default,
     OR an inline <script>…minified d3 source…</script> when --inline is set
     (downloaded once at install time and cached in the repo, OR embedded as a
     small stub if downloading is out of scope — see §8).
   - **`<script id="graph-data" type="application/json">{"nodes": [...], "links": [...]}</script>`**
     — this dedicated, addressable JSON block is what V2/V2b parse. Keeps the
     parse robust to changes in the rest of the HTML and to nested-array
     surprises in future node-shape evolution.
   - A separate `<script>` block that reads `JSON.parse(document.getElementById('graph-data').textContent)`
     and feeds a d3.forceSimulation with nodes + links.
   - Minimal CSS for nodes (circles), edges (lines), labels (text).
8. Write the HTML to stdout (or --out path).
```

### Wrapper-script idioms

Slides + mermaid wrappers follow the `scripts/mcp-server.sh` pattern:

```bash
#!/usr/bin/env bash
set -euo pipefail
# … resolve args …
if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx not found on PATH. Install Node.js ≥18 (https://nodejs.org)." >&2
  echo "       Then re-run ./scripts/preflight.sh to confirm." >&2
  exit 1
fi
exec npx -y @<pkg>@latest <args>
```

## §6 Iteration loop (per-step cadence)

Steps are sequential. Each step ends with `feat(visualize): step N — <what>` commit.

**K=3 definition:** *K counts git commits in the current loop session that modify the SAME component file (any single file under `scripts/visualize/`, `tests/canary/graph-fixture/`, `docs/VISUALIZATION.md`). After 3 such commits without that step's check turning green, STOP and escalate. K is per-step; resets at the next step.*

### Steps

1. **Author BOTH canary fixtures** (flat + nested).
   - Flat: `tests/canary/graph-fixture/{page-a,page-b,page-c,page-d}.md` — 4 nodes, 4 edges.
   - Nested: `tests/canary/graph-fixture-nested/root.md` + `tests/canary/graph-fixture-nested/sub/leaf.md` — 2 nodes, 1 edge, requires recursion.
   - Verify:
     - Flat: 4 files exist; page-a contains `[[page-b]]` AND `[[page-c]]`; page-b contains `[[page-c]]`; page-c contains `[[page-d]]`.
     - Nested: `root.md` contains `[[leaf]]`; `sub/leaf.md` exists.
   - **Frozen rule:** after this step's commit, the filenames AND the exact set of `[[link]]` references are immutable. Frontmatter and non-link prose may be edited later as parser-side fixes. Any change to link topology → escalate per §7.
   - K=3.

2. **Author `scripts/visualize/graph-html.py`** (the Python generator).
   - Verify (no LLM): `python3 -c "import ast; ast.parse(open('scripts/visualize/graph-html.py').read())"` (syntax OK) AND running it against the **flat** fixture produces HTML with `d3` reference + a `<script id="graph-data" type="application/json">` block containing exactly 4 nodes + 4 unique links AND running it against the **nested** fixture produces a `<script id="graph-data">` block containing exactly 2 nodes + 1 link (proves recursion).
   - Narrow fix: Python parsing logic, regex, HTML template, JSON-block emission.
   - K=3.

3. **Author `scripts/visualize/graph.sh`** (the bash wrapper).
   - Verify: bash -n, executable, shebang, calls graph-html.py correctly.
   - Narrow fix: shell logic.
   - K=3.

4. **Author `scripts/visualize/{slides,mermaid,serve}.sh`** (npx + http.server wrappers).
   - Verify: each has bash shebang, executable, `bash -n` clean, contains its respective tool name (`marp-cli`/`mermaid-cli`/`http.server`). `serve.sh` MUST honor `VISUALIZE_DRY_RUN=1` env var (when set, prints "would serve <dir>" and exits 0 without binding the port) — this is what V4's live-smoke uses.
   - Narrow fix: shell logic.
   - K=3 per file.

5. **Author `scripts/visualize/verify-visualizers.sh`** (the oracle).
   - Verify (no full LLM): `bash -n`, executable; running it produces V2 + V2b graph-smoke green; slides/mermaid smokes either RUN cleanly (if tools available) or SKIP cleanly (if absent); `serve.sh` live-smoked via `VISUALIZE_DRY_RUN=1` and exits 0; **harness MUST run smokes (not print "skipped") when tools ARE available** (V4 anti-skip-gaming).
   - Narrow fix: harness logic, skip-when-absent guard, anti-skip-gaming guard.
   - K=3.

6. **Update `scripts/installer-skeleton-manifest.txt`** to include the new files (6 new viz scripts + 4 flat canary fixtures + 2 nested canary fixtures + 1 doc = 13 new lines).
   - Verify: `./scripts/verify-create-llm-wiki.sh` exits 0 (R2 — installer + tree-shape stays in sync).
   - Narrow fix: manifest content.
   - K=3.

7. **Author `docs/VISUALIZATION.md`**.
   - Verify: V5 (all 4 scripts mentioned + alternatives).
   - Narrow fix: doc content.
   - Frozen after this step's commit.
   - K=3.

8. **First real umbrella run**: `./scripts/visualize/verify-visualizers.sh && ./scripts/smoke-all.sh > /dev/null && ./scripts/verify-create-llm-wiki.sh > /dev/null`.
   - Verify: exit 0 (all 8 checks green).
   - **Narrow fix rules:**
     - **V2 red:** graph generator broken. Fix `graph-html.py` parsing/template. K=3.
     - **V4 red on graph smoke:** same as V2.
     - **V4 red on slides/mermaid (tool present but smoke failed):** wrapper invocation wrong. Fix the wrapper. K=3.
     - **V4 red on tool-absent (oracle exited non-zero when tool missing):** harness's skip-when-absent guard is wrong. Fix `verify-visualizers.sh`. K=3.
     - **R1/R2/R3 red:** STOP and escalate immediately. Baseline regression.
     - **R2 red specifically:** likely manifest didn't get the new files. Re-run step 6.

9. **Add the README pointer.** Single-line section "Visualize your wiki: see `docs/VISUALIZATION.md`."
   - Verify: `grep -q 'VISUALIZATION.md' README.md`.

## §7 Stop/escalate conditions

The agent must NOT push through any of these.

- **Gaming the oracle:** weakening any V-check predicate (especially V2's node-count assertion); deleting any R-check; making the canary fixture trivial so V2's node-count is degenerate; padding `docs/VISUALIZATION.md` with grep-bait strings; making `verify-visualizers.sh` print "pass" without running the smoke; embedding fake JSON in the graph HTML output instead of parsing the real fixture.
- **Existing smoke or installer regression:** if `./scripts/smoke-all.sh` or `./scripts/verify-create-llm-wiki.sh` was green before the agent started and goes red, STOP, escalate. Those iterations' invariants are sacred this iteration.
- **Dev-repo content damage:** any edit that deletes/modifies the §3 R3 protected files → STOP. Visualize scripts must be READ-ONLY on the wiki.
- **K=3 attempts on the same component file** without its step's check turning green.
- **Architectural pressure:** if a check would only pass by AGENTS.md schema change (no 2→3 bump), removing a regression guard, or violating §8.
- **Infrastructure non-code failures:** transient `npx`/`python3`/`mktemp` failures — retry up to 3 times, then escalate.
- **Frozen-artifact re-edits:** canary fixture (after step 1's commit) and `docs/VISUALIZATION.md` (after step 7's commit) are frozen. Re-edits → escalate.

## §8 Non-goals (explicit out-of-scope)

- **Quartz / mdBook / SilverBullet integration as bundled.** Recommended in `docs/VISUALIZATION.md` for users who want a full static site; not bundled.
- **Docker / kroki / self-hosted diagram server.**
- **GUI / desktop wrapper / Electron app.**
- **Theming, dark mode, mobile responsiveness** of the graph HTML beyond minimum readability.
- **Live-reload watch mode** for `serve.sh`.
- **Native slash-command parity** (`/wiki-visualize` etc.). Wrappers are bash; agentic tools call them by natural language.
- **D3 v8 or later.** Default is v7 from CDN. If D3 v8+ breaks the script, the loop should STOP rather than chase upstream.
- **PDF/PPTX output for slides.** MARP-CLI's HTML output is enough; PDF/PPTX requires Chrome puppeteer install.
- **AGENTS.md schema change.** Visualization is content-derived; no schema bump needed.
- **`scripts/preflight.sh` overhaul.** May add a one-line "Visualizers" hint pointing at `npx`'s existing line; no new dependency checks (mmdc/marp are auto-fetched by npx on first use).

## §9 Real-data test inventory

**Primary oracle (this iteration):**
- `scripts/visualize/verify-visualizers.sh` (NEW) — runs graph smoke + skip-when-absent slides/mermaid smokes.

**Live smoke commands:**
- `./scripts/visualize/verify-visualizers.sh` — sub-second on systems without npx; +5-15s when slides/mermaid available (npx fetch).
- `./scripts/visualize/graph.sh tests/canary/graph-fixture/` — sub-second; deterministic output.

**Existing fixtures preserved as baseline (R1, R2):**
- All artifacts from `plug-and-play-curator-smoke` (`tests/smoke/`, the 4 derived wiki pages, `raw/smoke-source.md`).
- All artifacts from `installer-fresh-skeleton` (`scripts/create-llm-wiki.sh`, `scripts/verify-create-llm-wiki.sh`, `scripts/installer-skeleton-manifest.txt`, `README-FRESH.md`, `wiki/index-FRESH.md`, `tests/installer-output/.gitignore`).

**Before/after observable on a real run:**
- Before: `scripts/visualize/` doesn't exist; `tests/canary/graph-fixture/` doesn't exist; `docs/VISUALIZATION.md` doesn't exist.
- After: all exist; `verify-visualizers.sh` umbrella exits 0; the persona can run `./scripts/visualize/graph.sh wiki/ > graph.html`, open it in a browser, and see their wiki's link graph.

## Critical files

**New:**
- `scripts/visualize/graph.sh`
- `scripts/visualize/graph-html.py`
- `scripts/visualize/slides.sh`
- `scripts/visualize/mermaid.sh`
- `scripts/visualize/serve.sh`
- `scripts/visualize/verify-visualizers.sh`
- `tests/canary/graph-fixture/page-a.md`
- `tests/canary/graph-fixture/page-b.md`
- `tests/canary/graph-fixture/page-c.md`
- `tests/canary/graph-fixture/page-d.md`
- `tests/canary/graph-fixture-nested/root.md`
- `tests/canary/graph-fixture-nested/sub/leaf.md`
- `docs/VISUALIZATION.md`
- `.scratch/visualization-tools/GOAL.md` (this file)

**Modified:**
- `scripts/installer-skeleton-manifest.txt` (append the new visualize/canary/doc paths)
- `README.md` (one new section: "Visualize your wiki" pointer)

**Untouched (regression guards):**
- All dev-repo `raw/*`, `wiki/*.md`, `scripts/smoke-*.sh`, `scripts/create-llm-wiki.sh`, `scripts/verify-create-llm-wiki.sh`, `tests/smoke/`, `tests/canary/canary-*.md`, `tests/canary/canary-csv.csv`, `AGENTS.md`, `.claude/commands/wiki-*.md`.
- Schema version stays 2; `type` enum unchanged.

## Changes from prior draft (post-adversarial-pass)

1. **Timing-note added to §3** clarifying that the §3 completion oracle is evaluated ONLY at step 8; R2 is transiently red between steps 2 and 5 by design and is NOT a stop condition. (Fixes CRITICAL #5 — false stop on intermediate iterations.)
2. **V2b added** to force RECURSIVE directory traversal via a separate `tests/canary/graph-fixture-nested/sub/leaf.md` fixture. (Fixes HIGH #1+#6 — hardcoded counts and `glob('*.md')`-style implementations now both fail.)
3. **V2 parse switched from regex to dedicated `<script id="graph-data" type="application/json">` block** parsed with `json.load`. (Fixes HIGH #2 — fragile regex extraction.)
4. **V4 anti-skip-gaming guard added** — if a tool IS available, harness MUST run its smoke and the captured output MUST NOT contain `skipped:` for that tool. (Fixes HIGH #3 — fully-equipped machine could pass by faking-everything-skipped.)
5. **V4 includes live-smoke for `serve.sh`** via `VISUALIZE_DRY_RUN=1` env var (script honors it; exits 0 without binding port). (Fixes MEDIUM #10 — `bash -n` only catches syntax.)
6. **V5 grep predicate corrected** from `\|` (literal pipe in ERE — never matches) to `|` (ERE alternation). Backslash was a copy-paste artifact from BRE.
7. **Algorithm step 5 specifies dangling-link behavior** explicitly: drop edges whose target is not in nodes; no ghost nodes. Documented in `docs/VISUALIZATION.md`. (Fixes HIGH #9.)
8. **Algorithm step 2 specifies RECURSION** explicitly via `pathlib.Path.rglob('*.md')`. (Reinforces V2b.)
9. **Step 1 freezing rule clarified**: filenames AND `[[link]]` topology are immutable after step 1's commit; frontmatter and non-link prose may be edited as parser-side fixes. (Fixes MEDIUM #8.)

## After approval

Ready for `/goal`, `claude -p`, a worktree agent, or AFK.
