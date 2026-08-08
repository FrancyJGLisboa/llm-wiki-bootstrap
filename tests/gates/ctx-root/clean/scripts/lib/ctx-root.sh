# Stand-in for the real lib. Present so the clean fixture reads like real code.
# It is NOT the excluded path (that exclusion is keyed to scripts/lib/ctx-root.sh
# relative to the repo root, which this is, so it is skipped here too) — the
# clean signal comes from scripts/resolve.sh, which names no root at all.
ctx_root() { [ -d "${1:-.}/context" ] && printf 'context\n' || printf 'wiki\n'; }
