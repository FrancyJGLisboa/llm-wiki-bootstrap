---
description: Alias for /wiki-extract. Acquire one OR MANY URLs / local files into raw/.
allowed-tools: Bash, Read, Write, WebFetch
argument-hint: <url-or-filepath> [<url-or-filepath> ...]
---

This is a short-form alias for `/wiki-extract`. Read the canonical procedure in `.claude/commands/wiki-extract.md` and execute it verbatim against `$ARGUMENTS`. Do not duplicate the logic here — the canonical file is the single source of truth for how extraction works (source-type detection, slug derivation, graceful tool-chain fallbacks, frontmatter shape, single-source vs bulk-mode output).
