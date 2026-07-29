#!/usr/bin/env bash
# tests/eval/retrieval-corpus/gen-scale-filler.sh <wiki_root> <n_pages>
#
# Deterministically populate an installed wiki with <n_pages> filler pages so
# the retrieval eval can measure how quality and reads-per-answer bend with
# corpus size (scripts/eval-scale.sh). No clock, no randomness: byte-identical
# output for the same <n_pages>, verified by scripts/verify-scale-eval.sh (F1).
#
# The filler is DISTRACTOR-DENSE ON PURPOSE: pages live in the needle
# questions' own vocabulary (retention windows, retry ceilings, throughput)
# for other, explicitly-named services — so retrieval at scale must
# discriminate, not just navigate an inert mass. It is also DISJOINT ON
# PURPOSE: no needle phrase, needle figure, or needle identifier appears in
# any filler byte (blocklist enforced by verify-scale-eval.sh F3), so the
# ground truth of every graded question is unchanged at every scale.
#
# Layout per domain (12 domains, pages round-robin):
#   raw/scale-<svc>-ops-notes.md    one raw stub per domain, real body hash
#                                   (scripts/body-hash.sh — the canonical way),
#                                   its ## metrics section carrying every
#                                   figure its cluster's pages cite
#   wiki/scale-<svc>-note-NNN.md    filler pages: TL;DR, cited Body, Related
#   index.md                        gains a "## Scale corpus (generated)"
#                                   section listing every filler page
#   .scale-manifest                 pages=N domains=12 + content sha256

set -euo pipefail

WIKI_ROOT="${1:?usage: gen-scale-filler.sh <wiki_root> <n_pages>}"
N="${2:?usage: gen-scale-filler.sh <wiki_root> <n_pages>}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
HASHER="$REPO_ROOT/scripts/body-hash.sh"

[ -d "$WIKI_ROOT/wiki" ] || { echo "error: $WIKI_ROOT/wiki missing (install first)" >&2; exit 1; }
[ -x "$HASHER" ] || { echo "error: $HASHER missing" >&2; exit 1; }
case "$N" in ''|*[!0-9]*) echo "error: n_pages must be an integer" >&2; exit 1 ;; esac

DOMAINS=(billing checkout search notifications auth media exports telemetry ledger scheduler webhooks archive)
ND=${#DOMAINS[@]}
TOPICS=("retention window" "peak throughput" "retry ceiling" "queue depth" "error budget" "cache TTL" "replication lag" "deploy cadence")
UNITS=("days" "MB/s" "attempts" "entries" "minutes" "seconds" "ms" "per week")

# figure <i> <topic_idx> — deterministic, disjoint from every needle figure:
# days land in 200–372 (needles: 30/35/90/180), attempts in 10–18 (needles:
# 3/7), rates in 1000+ (needles: 412/389/999).
figure() {
  local i="$1" t="$2"
  case "$t" in
    0) echo $(( 200 + (i * 13) % 173 )) ;;
    1) echo $(( 1000 + i * 3 )) ;;
    2) echo $(( 10 + i % 9 )) ;;
    3) echo $(( 5000 + i * 11 )) ;;
    4) echo $(( 20 + (i * 7) % 40 )) ;;
    5) echo $(( 600 + (i * 17) % 300 )) ;;
    6) echo $(( 40 + (i * 3) % 55 )) ;;
    7) echo $(( 2 + i % 4 )) ;;
  esac
}

mkdir -p "$WIKI_ROOT/raw"

# Per-domain accumulators for the raw stubs' ## metrics sections.
metrics_dir="$(mktemp -d)"
trap 'rm -rf "$metrics_dir"' EXIT

index_tmp="$metrics_dir/index-entries"
: > "$index_tmp"

i=0
while [ "$i" -lt "$N" ]; do
  d=$(( i % ND )); svc="${DOMAINS[$d]}"
  t=$(( (i / ND) % ${#TOPICS[@]} )); topic="${TOPICS[$t]}"; unit="${UNITS[$t]}"
  f=$(figure "$i" "$t")
  slug=$(printf 'scale-%s-note-%03d' "$svc" "$i")
  topic_slug=$(printf '%s' "$topic" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')

  # Same-domain neighbour for a resolvable Related link (wraps inside cluster).
  next=$(( i + ND )); [ "$next" -ge "$N" ] && next=$d
  next_slug=$(printf 'scale-%s-note-%03d' "$svc" "$next")

  cat > "$WIKI_ROOT/wiki/$slug.md" <<EOF
---
title: ${svc} ${topic} note ${i}
type: note
source: analysis
updated: 2026-05-01
tags: [scale-filler, ${svc}, ${topic_slug}]
---

# ${svc} ${topic} — operational note ${i}

## Definition / TL;DR
The ${svc} service's ${topic} is ${f} ${unit}, per the May 2026 ops notes.

## Body
The ${svc} service records a ${topic} of ${f} ${unit} (source: raw/scale-${svc}-ops-notes.md#metrics). The figure was reviewed at the May 2026 operational readiness sync and is owned by the ${svc} on-call rotation (source: raw/scale-${svc}-ops-notes.md#procedures). Changes require a change ticket against the ${svc} runbook.

## Related
- [[${next_slug}]] — same-cluster operational note for the ${svc} service
EOF

  printf -- '- %s: %s %s (note %s)\n' "$topic" "$f" "$unit" "$i" >> "$metrics_dir/$svc"
  printf -- '- [[%s]] — %s %s: %s %s (ops notes, May 2026)\n' "$slug" "$svc" "$topic" "$f" "$unit" >> "$index_tmp"
  i=$(( i + 1 ))
done

# One raw stub per domain that actually appeared, hashed with the canonical
# hasher so the drift lint (R5's precondition) stays clean over filler.
d=0
while [ "$d" -lt "$ND" ] && [ "$d" -lt "$N" ]; do
  svc="${DOMAINS[$d]}"
  raw="$WIKI_ROOT/raw/scale-${svc}-ops-notes.md"
  first_slug=$(printf 'scale-%s-note-%03d' "$svc" "$d")
  cat > "$raw" <<EOF
---
source_url: n/a
source_type: notes
source_title: "${svc} ops notes — May 2026"
source_author: unknown
fetched_at: 2026-05-01
asserted_at: 2026-04-10
asserted_at_source: "#L1"
ingested_hash: ""
ingested_at: "2026-05-01 09:00"
ingested_pages: [wiki/${first_slug}.md]
extraction_method: passthrough
---
# ${svc} ops notes — May 2026

Operational figures for the ${svc} service, as reviewed 2026-04-10.

## metrics

$(cat "$metrics_dir/$svc")

## procedures

The ${svc} on-call rotation owns every figure above. Changes require a change
ticket against the ${svc} runbook and sign-off at the weekly operational
readiness sync.
EOF
  h=$("$HASHER" "$raw")
  # Portable in-place: rewrite via temp file (BSD/GNU sed -i differ).
  awk -v h="$h" '{ sub(/^ingested_hash: ""$/, "ingested_hash: \"" h "\"") } 1' \
    "$raw" > "$raw.tmp" && mv "$raw.tmp" "$raw"
  d=$(( d + 1 ))
done

# Index section (idempotent: replace any previous scale section).
idx="$WIKI_ROOT/wiki/index.md"
if [ -f "$idx" ]; then
  awk '/^## Scale corpus \(generated\)$/{skip=1; next} skip && /^## /{skip=0} !skip' \
    "$idx" > "$idx.tmp" && mv "$idx.tmp" "$idx"
  { echo ""; echo "## Scale corpus (generated)"; echo ""; cat "$index_tmp"; } >> "$idx"
fi

# Manifest: page count + content hash of every generated byte, order-stable.
{
  echo "pages=$N domains=$(( N < ND ? N : ND ))"
  find "$WIKI_ROOT/wiki" -name 'scale-*.md' -type f | sort | xargs cat \
    | openssl dgst -sha256 | awk '{print "sha256=" $NF}'
} > "$WIKI_ROOT/.scale-manifest"

echo "[scale-filler] $N pages across $(( N < ND ? N : ND )) domains, manifest at $WIKI_ROOT/.scale-manifest" >&2
