---
description: Safely extract every new or changed evidence-inbox file, then compile it.
allowed-tools: Bash, Read, Write
argument-hint: [--no-compile]
---

Process the friendly `EVIDENCE-INBOX/` boundary without editing or deleting user originals.

1. Run `python3 scripts/inbox.py pending --json`. Stop on any safety error.
2. If nothing is pending, report `EVIDENCE-INBOX is up to date` and make no changes.
3. For each pending path, execute the exact local-file acquisition contract from
   `.claude/commands/ctx-extract.md`. Treat each `EVIDENCE-INBOX/<path>` as one source. Do
   not move, rename, edit, or delete the evidence-inbox original.
4. Verify the normalized raw output with `scripts/verify-extract.sh` where its
   source type is supported.
5. Only after successful extraction, run:
   `python3 scripts/inbox.py record "<path>" --raw "raw/<normalized-source>"`.
   Never record a failed or degraded extraction as successful.
6. Unless `$ARGUMENTS` contains `--no-compile`, execute `/ctx-compile` for the raw
   sources created in this run.
7. Report three bounded lists: compiled, needs attention, unchanged. Include the
   evidence-inbox-to-raw mapping for compiled files.

The state ledger is deterministic and Git-visible at `context/inbox-state.json`.
Do not infer success from file-name similarity; the explicit record operation is
the completion boundary.
