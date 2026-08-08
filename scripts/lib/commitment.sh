#!/usr/bin/env bash
# scripts/lib/commitment.sh — the ONE reader for "does this raw source carry an
# ingest commitment?". Source it; do not exec it.
#
# WHY THIS FILE EXISTS: the test was written four times as an inline grep —
#
#     grep -q 'ingested_hash: "[0-9a-f]' "$f"
#
# in wiki-lint-commitment.sh, wiki-metrics.sh, eval-retrieval.sh, and (worst)
# verify-retrieval-eval.sh, the ORACLE, which reimplemented the check instead of
# calling it. All four demanded a literal opening double-quote. `ingested_hash:
# d1d2986…` is valid YAML and is what four of this repo's own raw sources carry,
# so the lint reported "carries no ingested_hash" for sources whose hash was
# present, correct, and current — and advised re-running /wiki-ingest, which
# would have spent real model calls rewriting pages to fix a regex.
#
# The diagnosis was wrong in a second, worse way: the message also claimed
# "hash-drift detection is disabled for this body". It is not.
# wiki-lint-hash-drift.sh reads the field with an awk helper that strips quotes,
# so drift was being detected the whole time on exactly the sources the lint
# called uncommitted. Two readers of one field disagreed, and the stricter one
# was wrong.
#
# scripts/commit-source.py — the canonical WRITER — always emits the quoted form
# (line ~116) but READS quote-optionally (line ~101). Tolerant reading is the
# intended contract; this file is that contract, in one place, for shell.
#
# Same reasoning as body-hash.sh being the one hasher: a second implementation
# of a shared predicate does not stay identical to the first.

# fm_commitment_field <file> <key> — read a frontmatter scalar, quotes stripped.
# Prints nothing when the file has no frontmatter or the key is absent.
fm_commitment_field() {
  LC_ALL=C awk -v key="$2" '
    NR == 1 && $0 != "---" { exit }
    NR == 1 { next }
    /^---$/ { exit }
    index($0, key ":") == 1 {
      v = substr($0, length(key) + 2)
      sub(/^[[:space:]]+/, "", v); sub(/[[:space:]]+$/, "", v)
      gsub(/^["'\'']|["'\'']$/, "", v)
      print v; exit
    }
  ' "$1" 2>/dev/null
}

# has_commitment <file> — 0 if <file> (or its `<file>.md` sidecar) records a
# non-empty hex ingested_hash, 1 otherwise.
#
# The sidecar fallback is not incidental: a binary or tabular source (`x.csv`,
# `x.pdf`) carries its commitment on the parsed `x.csv.md` beside it, and the
# pair is one source with one commitment.
has_commitment() {
  local f="$1" v
  for cand in "$f" "$f.md"; do
    [ -f "$cand" ] || continue
    v="$(fm_commitment_field "$cand" ingested_hash)"
    # Hex only. A non-hex value is a hand-written or corrupted receipt, and a
    # commitment nobody derived is worse than none — it reads as verified.
    case "$v" in
      "" ) continue ;;
      *[!0-9a-fA-F]* ) continue ;;
      * ) return 0 ;;
    esac
  done
  return 1
}
