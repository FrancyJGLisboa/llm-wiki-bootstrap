#!/usr/bin/env bash
# scripts/vtt-to-md.sh — convert a WebVTT/SRT subtitle file to a markdown
# transcript body for /wiki-extract's YouTube handler.
#
# YouTube auto-generated captions arrive as "rolling" VTT: every cue repeats
# the previous line plus inline word-timing tags (<00:00:01.319><c> word</c>).
# Fed to an LLM raw, that is ~3x the tokens for the same content. This script
# deterministically:
#
#   1. strips VTT/SRT scaffolding (headers, cue ids, timecodes, NOTE/STYLE
#      blocks, inline tags, HTML entities)
#   2. drops consecutive duplicate lines (the rolling-caption artifact)
#   3. groups lines into paragraphs, breaking on silence gaps
#   4. emits a timestamp heading `## (m:ss)` at most every ANCHOR_INTERVAL
#      seconds — citation anchors matching the style of existing
#      video-transcript raw files (see raw/karpathy-llm-wiki-video-transcript.md)
#
# Output is the transcript BODY only (stdout). The caller (/wiki-extract)
# prepends the frontmatter and the `# <title>` heading.
#
# Usage:
#   scripts/vtt-to-md.sh <subtitle-file.vtt|.srt>
#
# Tunables (env):
#   ANCHOR_INTERVAL — min seconds between `## (m:ss)` headings (default 180)
#   PARA_GAP        — silence gap in seconds that starts a new paragraph (default 6)

set -euo pipefail

file="${1:?usage: vtt-to-md.sh <subtitle-file.vtt|.srt>}"

if [[ ! -f "$file" ]]; then
  echo "error: not a file: $file" >&2
  exit 1
fi

ANCHOR_INTERVAL="${ANCHOR_INTERVAL:-180}"
PARA_GAP="${PARA_GAP:-6}"

awk -v anchor_interval="$ANCHOR_INTERVAL" -v para_gap="$PARA_GAP" '
function tosec(t,   n, p) {
  gsub(/,/, ".", t)            # SRT uses 00:00:01,319
  n = split(t, p, ":")
  if (n == 3) return p[1] * 3600 + p[2] * 60 + p[3]
  if (n == 2) return p[1] * 60 + p[2]
  return p[1] + 0
}
function fmt(s,   h, m) {
  s = int(s)
  h = int(s / 3600); m = int((s % 3600) / 60)
  if (h > 0) return sprintf("%d:%02d:%02d", h, m, s % 60)
  return sprintf("%d:%02d", m, s % 60)
}
function flush() {
  if (para != "") { print para; print "" }
  para = ""
}
BEGIN { started = 0; in_block = 0; cur = 0; prev_start = 0; anchor = 0; para = ""; prev_line = "" }

# VTT header + metadata lines.
/^\xEF\xBB\xBFWEBVTT/ || /^WEBVTT/ { next }
/^(Kind|Language):/ { next }

# NOTE / STYLE / REGION blocks run until the next blank line.
/^(NOTE|STYLE|REGION)/ { in_block = 1; next }
/^[[:space:]]*$/       { in_block = 0; next }
in_block               { next }

# Timecode line: capture the cue start, ignore the rest (settings like
# "align:start position:0%" follow the arrow in auto-sub VTT).
/-->/ { cur = tosec($1); next }

# SRT numeric cue indexes.
/^[0-9]+[[:space:]]*$/ { next }

# Caption text line.
{
  gsub(/<[^>]*>/, "")          # inline tags: <c>, <i>, <00:00:01.319>, ...
  gsub(/&nbsp;/, " ")
  gsub(/&amp;/, "\\&")
  gsub(/&lt;/, "<")
  gsub(/&gt;/, ">")
  gsub(/&quot;/, "\"")
  gsub(/&#39;/, "\x27")
  gsub(/^[[:space:]]+|[[:space:]]+$/, "")
  if ($0 == "") next
  if ($0 == prev_line) next    # rolling-caption duplicate
  prev_line = $0

  if (!started || cur - anchor >= anchor_interval) {
    flush()
    printf "## (%s)\n\n", fmt(cur)
    anchor = cur
    started = 1
  } else if (cur - prev_start > para_gap) {
    flush()
  }
  prev_start = cur

  para = (para == "") ? $0 : para " " $0
}
END { flush() }
' "$file"
