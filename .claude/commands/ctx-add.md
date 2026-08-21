---
description: Add any evidence and update the context through one user-facing workflow.
allowed-tools: Bash, Read, Write
argument-hint: <files|folder|urls> | --text "..." --title "..." | (empty to process dropped files)
---

This is the single user-facing evidence intake. Accept local files, folders, URLs,
pasted text, or files already dropped into `EVIDENCE-INBOX/`. Default to compiling
successfully acquired evidence immediately.

1. Parse `$ARGUMENTS` without evaluating shell substitutions. Separate HTTP(S) URLs,
   local paths, and `--text` input. Reject unsupported schemes and ambiguous mixtures.
2. For local files/folders or pasted text, run `scripts/add-evidence.py` with safely
   quoted arguments. Then execute the complete `/ctx-inbox` contract to normalize and
   compile newly staged evidence.
3. For files already in `EVIDENCE-INBOX/` (including an empty invocation), execute the
   complete `/ctx-inbox` contract directly.
4. For each URL, execute the complete `/ctx-extract` contract. After all successful URL
   acquisitions, execute `/ctx-compile` only for their new raw sources.
5. Mixed local and URL input is allowed: finish each acquisition path, then report one
   combined result. One source failing must not make successful sources disappear.
6. If `$ARGUMENTS` contains `--no-compile`, acquire/stage only and say clearly that the
   context was not updated. Otherwise compilation is the default.
7. Report in ordinary language: added, unchanged, needs attention, and what context
   changed. Do not expose internal command names unless the user asks for technical detail.

Never edit or delete a user original. Never mark degraded or failed acquisition as
successful. Preserve exact source provenance and use UNKNOWN when evidence is insufficient.
