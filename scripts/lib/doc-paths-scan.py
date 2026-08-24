#!/usr/bin/env python3
"""Scanner for scripts/gate-doc-paths.sh (rule DOC-PATH-RESOLVES).

Emits one TAB-separated `path:line<TAB>fix` record per violation on stdout.
Lives in its own file rather than in a heredoc: the patterns it needs contain
backticks, and an odd backtick inside a $( ) heredoc breaks bash's parser at
parse time — the gate would exit 2 before running a single check.

Run from the repository root. See the gate for the rule and its rationale.
"""
import os, re, subprocess, sys

root = os.getcwd()
manifest_path = "scripts/installer-skeleton-manifest.txt"

# What ships, and where a shipped doc's content really comes from. The installer
# rewrites two targets from FRESH templates; the template is the file whose
# prose is actually mailed out, so it is the file this gate must judge.
manifest = set()
if os.path.exists(manifest_path):
    for ln in open(manifest_path):
        ln = ln.strip()
        if ln and not ln.startswith("#"):
            manifest.add(ln)
TEMPLATE_SOURCE = {
    "README.md": "templates/README-fresh.md",
    "docs/QUICKSTART.md": "templates/QUICKSTART-fresh.md",
}

# Prefer git: it respects .gitignore, so untracked build output and vendored
# node_modules never enter the scan. Fall back to a walk so a fixture tree does
# not need a nested .git — a nested repo inside tests/ turns into a gitlink in
# the parent and is worse than the problem it solves.
tracked = []
try:
    r = subprocess.run(["git", "ls-files", "*.md", "*.mdc"],
                       capture_output=True, text=True)
    if r.returncode == 0:
        tracked = r.stdout.split()
except OSError:
    pass
if not tracked:
    SKIP_DIRS = {".git", "node_modules", "__pycache__", ".pytest_cache", "dist"}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for fn in filenames:
            if fn.endswith((".md", ".mdc")):
                tracked.append(os.path.relpath(os.path.join(dirpath, fn), root))

# A doc is judged at the directory it will LIVE in. templates/README-fresh.md is
# installed at the target root, so its `](START-HERE.md)` is correct even though
# nothing named START-HERE.md sits beside it in templates/.
install_path = {}
overridden = set()
for target, src in TEMPLATE_SOURCE.items():
    # Only a template that actually exists overrides its target. Without this the
    # override is a blanket exemption for README.md in any tree — including one
    # that has no template and where README.md really is the shipped file.
    if os.path.exists(src):
        install_path[src] = target
        overridden.add(target)   # the dev file is NOT what ships; its template is

# SCOPE — this gate judges documents a reader is meant to ACT on. Excluded, by
# construction rather than by per-line suppression:
#   log.md              append-only history. An entry naming a script that was
#   LEARNINGS.md        later renamed is an accurate record of what happened,
#                       not a broken instruction. Rewriting it would be lying.
#                       LEARNINGS.md is the same shape: dated incident entries
#                       whose examples cite scripts that have since been removed.
#   .scratch/           dated working notes from finished investigations.
#   tests/, benchmarks/*/runs/, docs/assessments/
#                       captured outputs and one-off artifacts, same argument.
# Everything else — README, START-HERE, ADVANCED, AGENTS, docs/, templates/,
# .claude/commands/, and every agent shim — is in scope.
EXCLUDED = (".scratch/", "tests/", "docs/assessments/")
def out_of_scope(doc):
    return doc in ("log.md", "LEARNINGS.md") or doc.startswith(EXCLUDED) or "/runs/" in doc

LINK = re.compile(r"\]\(([^)\s]+)\)")
SCRIPT = re.compile(r"(?:\./)?((?:scripts|templates)/[A-Za-z0-9_./-]+\.(?:sh|py|tsv|txt|tmpl))")
# A runnable invocation: `./scripts/x.sh`, `bash scripts/x.sh`, `python3 scripts/x.py`.
INVOCATION = re.compile(r"(?:^|[`\s(])(?:\./|(?:bash|sh|python3?|source|\.)\s+)"
                        r"((?:scripts|templates)/[A-Za-z0-9_./-]+\.(?:sh|py))")

# A guarded invocation is not a broken instruction. `[ -f x ] && bash x` is the
# correct way to write a step that applies only where the script exists, and it
# is exactly what this gate should be pushing authors toward — so recognising it
# is detection, not a carve-out. Recognised only when the guard names the SAME
# path as the invocation, so a guard on some other file cannot launder an
# unguarded command.
def guarded(line, target):
    esc = re.escape(target)
    return re.search(r"\[\s+-[efxrs]\s+(?:\./)?" + esc + r"\s+\]", line) is not None


def placeholder(p):
    return any(c in p for c in "<>$*{}|") or p.startswith(("http://", "https://", "mailto:", "#"))

viol = []
for doc in sorted(set(tracked)):
    if out_of_scope(doc):
        continue
    # A doc that is neither tracked-and-present nor readable is git's problem.
    try:
        lines = open(doc, encoding="utf-8", errors="replace").read().split("\n")
    except OSError:
        continue

    here = install_path.get(doc, doc)
    base = os.path.dirname(here)
    ships = (here in manifest or doc in manifest) and doc not in overridden

    for i, line in enumerate(lines, 1):
        seen = set()

        for m in LINK.finditer(line):
            target = m.group(1).split("#", 1)[0]
            if not target or placeholder(target) or target in seen:
                continue
            seen.add(target)
            resolved = os.path.normpath(os.path.join(base, target))
            if not os.path.exists(os.path.join(root, resolved)):
                viol.append(("%s:%d" % (doc, i),
                             "link target `%s` does not resolve (from %s). Point it at a real "
                             "file or drop the link." % (target, here)))

        for m in SCRIPT.finditer(line):
            target = m.group(1)
            if placeholder(target) or target in seen:
                continue
            seen.add(target)
            if not os.path.exists(os.path.join(root, target)):
                viol.append(("%s:%d" % (doc, i),
                             "names `%s`, which does not exist in this repository. Name the real "
                             "script or remove the instruction." % target))
            elif ships and manifest and target not in manifest \
                 and target in {m.group(1) for m in INVOCATION.finditer(line)} \
                 and not guarded(line, target):
                viol.append(("%s:%d" % (doc, i),
                             "this doc SHIPS (installed as %s) but names `%s`, which is not in %s — "
                             "the command is guaranteed to fail in every generated compiler. Add it "
                             "to the manifest, or move the instruction into a bootstrap-repo-only "
                             "document." % (here, target, manifest_path)))


# ── Shipped scripts ───────────────────────────────────────────────────────────
# Same rule, one layer down. verify-guided-workspace.sh SHIPS and ran four tests
# from tests/guided-workspace/; only two were in the manifest, so the documented
# "Verify installation" step and the VS Code task "Context: Verify guided
# workspace" both died in every generated compiler — while passing in the dev
# repo, where the files are present. A doc-only scan cannot see that.
#
# Deliberately narrow: only "$ROOT/<path>" and "$SCRIPT_DIR/../<path>" literals,
# which is how a shipped script names a sibling artifact. Bare words, runtime
# temp paths and variable-built paths are not matched — this catches the one
# form that is statically knowable, not every path a script could construct.
# Restricted to scripts/ and tests/ — STATIC assets a script depends on, which
# must therefore ship. Everything under context/, wiki/ and the package root is
# produced at runtime (context-profile.json by use-profile.sh, tensions.md and
# open-questions-dashboard.md by synthesize/all.sh), and demanding those be in
# the manifest would be wrong: a fresh compiler is supposed to lack them.
SHIPPED_REF = re.compile(r'"\$(?:ROOT|REPO_ROOT)/((?:scripts|tests)/[A-Za-z0-9_./-]*\.[A-Za-z0-9]+)"')

if manifest:
    for script in sorted(m for m in manifest if m.endswith(".sh")):
        if not os.path.exists(script):
            continue
        try:
            lines = open(script, encoding="utf-8", errors="replace").read().split("\n")
        except OSError:
            continue
        for i, line in enumerate(lines, 1):
            for m in SHIPPED_REF.finditer(line):
                target = m.group(1)
                if placeholder(target) or guarded(line, target):
                    continue
                if target not in manifest:
                    viol.append(("%s:%d" % (script, i),
                                 "this script SHIPS but reads `%s`, which is not in %s — it will "
                                 "fail in every generated compiler while passing here. Add the "
                                 "file to the manifest, or guard the step with [ -f %s ]."
                                 % (target, manifest_path, target)))

for where, fix in viol:
    print("%s\t%s" % (where, fix))
