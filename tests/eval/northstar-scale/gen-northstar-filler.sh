#!/usr/bin/env bash
# tests/eval/northstar-scale/gen-northstar-filler.sh <workspace> <n_docs>
#
# Deterministically add <n_docs> distractor raw sources to a staged Northstar
# workspace, so the decision benchmark can be run at corpus scale.
#
# WHY THIS EXISTS: the Northstar corpus is 28 files / ~3,537 tokens. Every
# alternative — a long-context prompt, an agent with the folder, BM25 — wins
# trivially at that size, which is why the first benchmark run showed the
# compiled arm slower and no more accurate. The product's claim only bites when
# the corpus exceeds what an alternative can simply read. This grows the corpus
# without touching the twelve graded answers.
#
# DISJOINT ON PURPOSE. Filler lives in a service-operations domain (retention
# windows, retry ceilings, throughput) that shares no discriminative term with
# grain trading. The blocklist below is enforced by --verify and must stay
# empty-matching: if one filler byte carries a needle identifier, every graded
# answer becomes unsound and the measurement is void, not merely noisy.
#
# Common English that happens to appear in gold `contains` ("not", "open",
# "price", "increase", "export") is NOT blocked and does not need to be: those
# are scored against the model's ANSWER text, not against corpus presence.
# Blocking them would also make realistic prose impossible.
#
# DISTRACTOR-DENSE ON PURPOSE. Filler carries dated assumptions, supersessions
# and conflicting statements of its own, so retrieval at scale must discriminate
# rather than navigate an inert mass.
#
# Deterministic: no clock, no randomness. Same <n_docs> gives byte-identical
# output, so a scale curve is reproducible.

set -uo pipefail

WS="${1:?usage: gen-northstar-filler.sh <workspace> <n_docs> | --verify <workspace>}"
if [ "$WS" = "--verify" ]; then
  WS="${2:?usage: --verify <workspace>}"; MODE=verify; N=0
else
  N="${2:?usage: gen-northstar-filler.sh <workspace> <n_docs>}"; MODE=generate
fi
[ -d "$WS/raw" ] || { echo "no raw/ under $WS" >&2; exit 2; }

# Discriminative needle terms. Case-insensitive, fixed strings.
BLOCK='northstar
soymeal
santos
5.50
5.70
175 mt
fully covered
brl
maria silva
leo martins
email-2026-
meeting-2026-
research-2026-
note-2026-
sheet-2026-'

SERVICES="ingest-relay parcel-router token-vault audit-sink mesh-broker cache-tier batch-planner quota-guard trace-hub schema-forge replay-queue edge-shaper"

if [ "$MODE" = generate ]; then
  i=0
  while [ "$i" -lt "$N" ]; do
    i=$((i + 1))
    svc=$(printf '%s\n' $SERVICES | sed -n "$(( (i % 12) + 1 ))p")
    # Deterministic pseudo-dates and figures derived from the index only.
    mon=$(( (i % 12) + 1 )); day=$(( (i % 27) + 1 ))
    win=$(( 30 + (i % 11) * 15 )); ceil=$(( 3 + (i % 5) )); thr=$(( 400 + (i % 23) * 25 ))
    prev=$(( win - 15 ))
    printf -v d '2025-%02d-%02d' "$mon" "$day"
    f="$WS/raw/scale-$svc-ops-$(printf '%04d' "$i").md"
    cat > "$f" <<EOF
---
source_url: n/a
source_id: scale-$svc-ops-$(printf '%04d' "$i")
source_type: note
source_title: "$svc operations note $i"
source_author: "Platform Operations"
fetched_at: 2025-12-31
asserted_at: $d
asserted_at_source: "#record"
ingested_hash: ""
ingested_at: never
ingested_pages: []
extraction_method: synthetic
---

# Record

**Service:** $svc
**Date:** $d

## Retention

The retention window for $svc is $win days. This replaces the earlier $prev day
window recorded before $d; treat $win days as current until reissued.

## Reliability

Retry ceiling is $ceil attempts. Sustained throughput target is $thr events per
second. An earlier note put the ceiling at $(( ceil + 1 )) attempts; that figure
is superseded.

## Open items

Capacity headroom beyond the $thr events per second target is not established in
this record.
EOF
    [ -f "$f" ] || { echo "failed writing $f" >&2; exit 1; }
  done
  echo "generated $N distractor raw sources under $WS/raw"
fi

# ── Blocklist enforcement. A hit voids the measurement, so it exits non-zero. ──
hits=0
while IFS= read -r term; do
  [ -n "$term" ] || continue
  # Search ONLY filler files, matched by BASENAME. An earlier version grepped
  # all of raw/ and filtered the full path for "scale-", which matched the
  # workspace directory name (scale-ws) and flagged every real Northstar source
  # as contaminated. The check was broken, not the corpus.
  found="$(find "$WS/raw" -type f -name 'scale-*' -exec grep -ilF -- "$term" {} + 2>/dev/null || true)"
  if [ -n "$found" ]; then
    echo "BLOCKLIST HIT: filler contains needle term '$term'" >&2
    printf '%s\n' "$found" | head -3 | sed 's/^/    /' >&2
    hits=$((hits + 1))
  fi
done <<EOF
$BLOCK
EOF
if [ "$hits" -gt 0 ]; then
  echo "filler is NOT disjoint from the graded needles — measurement would be void" >&2
  exit 1
fi
echo "blocklist clean: no filler byte carries a discriminative needle term"
