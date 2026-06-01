---
description: Acquire one OR MANY URLs / local files (PDF, DOCX, XLSX, CSV, image, plain text) — or pasted inline text (--text) — into raw/, parsing binary content to markdown when possible. Does not modify wiki/.
allowed-tools: Bash, Read, Write, WebFetch
argument-hint: <url-or-filepath> [<url-or-filepath> ...]  |  --text [--title "<title>"] [--source-type <value>] <pasted text>
---

You are executing `/wiki-extract $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to acquire one or more sources and deposit each in `raw/` with the right frontmatter. You **never touch `wiki/`** in this command.

## Read first

**Run from the wiki root** (the directory with `raw/`, `wiki/`, `AGENTS.md`, `log.md`). If `AGENTS.md` is absent, you're not in a wiki: tell the user to run `/wiki-init` first (or `cd` into their wiki), then stop.

Read `AGENTS.md` to confirm the raw source frontmatter convention and the slug naming convention.

## Inline-text mode (when `$ARGUMENTS` begins with `--text`)

If the first whitespace-delimited token of `$ARGUMENTS` is exactly `--text`, switch to **inline-text mode**. Skip both the bulk-split logic and the Step 1 type detection — the argument is *content*, not a path or URL.

1. **Parse flags.** Optional `--title "<title>"` and/or `--source-type <value>` may immediately follow `--text` (in any order); if present, consume them. **Everything after the flag(s) is the literal source content** — never whitespace-split it, never treat its tokens as separate sources, never strip or interpret it beyond reading the `--title` / `--source-type` values.
2. **Title.** If `--title` was given, use it. If not, **ask the user once** for a short title (used for the slug and `source_title`); do not invent one silently from the content.
3. **Slug.** Kebab-case the title (drop punctuation). On collision with an existing `raw/` file, append a date suffix (`-YYYY-MM-DD`), per Step 2's rule.
4. **Write** the content verbatim (UTF-8) to `raw/<slug>.md`, then prepend the Step 4 frontmatter with: `source_url: n/a`, `extraction_method: passthrough`, and `extraction_status` omitted (it is `ok`). For `source_type`: use the `--source-type <value>` if given (e.g. `interaction` when capturing a session for `/wiki-learn`); otherwise default to `note` (or a better-fitting open value if the content is obviously a tweet / chat / meeting-notes / etc.). The value is passed through verbatim — `source_type` is an open enum (see `AGENTS.md`).
5. **Verify** (Step 5) and emit the **single-source** output block.

**`--text` is single-source only.** Because it consumes the rest of the line as content, it cannot be combined with URLs/files in the same invocation — run those in a separate `/wiki-extract`. That single-flag delimiter is what keeps pasted prose unambiguous against bulk multi-source input (so the paste is never shredded into tokens). No quoting of the content is required.

## Bulk-input mode (when `$ARGUMENTS` contains more than one source)

**Unless `$ARGUMENTS` begins with `--text`** (inline-text mode, above): if `$ARGUMENTS` contains multiple whitespace- or newline-separated tokens, treat each token as an independent source and run **Steps 1–4 below** for each one, in order, top-to-bottom. Do not stop the batch on a single failure: if one source fails (e.g. URL 404, missing local file, all extraction handlers absent for a binary format), log the failure with an `extraction_status: failed` sidecar (per Step 3's failure path) and move to the next source. At the end of the batch, emit one consolidated summary listing:

- Sources successfully written (with slugs)
- Sources marked `degraded` (extracted but with caveats — e.g. LLM-vision fallback used)
- Sources marked `failed` (no usable output — sidecar still written)

Each source still produces its own `raw/<slug>.<ext>` (or sidecar). The batch is a flat list, not a manifest file. **Quoting**: arguments containing spaces should be quoted by the user (e.g. `/wiki-extract "/path/with space/doc.pdf" https://example.com`). If you can't reliably split, ask the user once for the unambiguous list — do not guess.

## Steps (run once per source)

1. **Identify the source type** from the current source (extension-based, lowercase comparison). _(Skip this step entirely in inline-text mode — see above; the argument is content, already known to be passthrough.)_
   - Starts with `http://` or `https://` → URL
   - `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp` → image
   - `.pdf` → PDF
   - `.docx` → DOCX (Word)
   - `.xlsx` → XLSX (Excel)
   - `.csv` → CSV
   - `.md`, `.txt`, `.html`, `.json`, `.yaml`, `.toml`, source code, etc. → plain text
   - Anything else: ask the user how to treat it. Do not guess.

2. **Derive a slug** for the file name in `raw/`:
   - URL: domain + path-leaf (e.g. `karpathy-tweet-1234.md`), kebab-case, drop punctuation.
   - File: original basename, kebab-cased.
   - Inline text (`--text`): kebab-case the `--title` value (or the title you asked the user for).
   - If the slug collides with an existing file in `raw/`, append a date suffix (`-2026-05-25`).

3. **Acquire the content.** Every binary format below follows a **graceful tool chain** — try the best handler first, fall back if it's missing, and if everything fails save the binary with an `extraction_status: failed` sidecar (never silently). Record what you used in the `extraction_method` frontmatter field (see step 4).

   - **URL:** use `WebFetch` with the prompt "Return the main textual content of this page as clean markdown, preserving headings and lists." Save the result as `raw/<slug>.md`. → `extraction_method: webfetch`.

   - **Plain text** (`.md`, `.txt`, `.html`, `.json`, `.yaml`, `.toml`, source code, etc.): use `Read`, then `Write` to `raw/<slug>.<ext>`. → `extraction_method: passthrough`.

   - **CSV:** copy to `raw/<slug>.csv` via `Bash cp`. Count rows with `Bash wc -l`. Always also write a sidecar `raw/<slug>.csv.md` with:
     - ≤100 rows: full table rendered in markdown.
     - >100 rows: header + first 20 rows + a `(...truncated, N total rows)` line.
     → `extraction_method: csv-passthrough`.

   - **Image** (`.png`/`.jpg`/`.jpeg`/`.gif`/`.webp`): copy the binary to `raw/<slug>.<ext>` via `Bash cp`. Use your vision capability to (a) extract any text visible in the image and (b) write a short description of what it shows. Save extracted text + description as `raw/<slug>.<ext>.md`. → `extraction_method: llm-vision`.

   - **PDF:** copy to `raw/<slug>.pdf` via `Bash cp`. Extract text via the first method that works:
     1. `Bash pdftotext "<file>" -` — best for text-native PDFs.
     2. If `pdftotext` is unavailable, or returns near-empty output (scanned / image-heavy PDF), fall back to **LLM vision**: read the PDF via `Read` (if your runtime supports PDF natively) or extract page-by-page.
     3. If both fail, save only the binary and write `raw/<slug>.pdf.md` with `extraction_status: failed` and a one-line note.

     Save extracted text as `raw/<slug>.pdf.md`. → `extraction_method: pdftotext | llm-vision | failed`.

   - **DOCX:** copy to `raw/<slug>.docx` via `Bash cp`. Extract via the first method that works:
     1. `Bash pandoc -f docx -t markdown "<file>"` — preserves headings, lists, tables.
     2. If `pandoc` is missing, fall back to `Bash python3 -c "from docx import Document; d=Document('<file>'); print('\n\n'.join(p.text for p in d.paragraphs))"` if Python 3 + the `python-docx` package are available.
     3. If neither, write `raw/<slug>.docx.md` with `extraction_status: failed` and a one-line install hint (e.g., "install pandoc: `brew install pandoc` or `apt install pandoc`").

     Save extracted text as `raw/<slug>.docx.md`. → `extraction_method: pandoc | python-docx | failed`.

   - **XLSX:** copy to `raw/<slug>.xlsx` via `Bash cp`. Extract via the first method that works:
     1. `Bash xlsx2csv "<file>" --all` — emits CSV per sheet; convert each sheet's CSV to a markdown table, prefix with `### <sheet-name>`.
     2. If `xlsx2csv` is missing, fall back to `Bash python3 -c "import openpyxl; ..."` if Python 3 + `openpyxl` are available.
     3. If neither, write `raw/<slug>.xlsx.md` with `extraction_status: failed` and a one-line install hint.

     For sheets with >100 rows: header + first 20 rows + `(...truncated, N total rows)` per sheet. Save as `raw/<slug>.xlsx.md`. → `extraction_method: xlsx2csv | openpyxl | failed`.

   **Tool-availability check:** before running any optional binary (`pdftotext`, `pandoc`, `xlsx2csv`, `python3`), probe it with `Bash command -v <tool>` and branch accordingly. Never assume; never crash the command on a missing tool.

4. **Write the frontmatter** at the top of the markdown file (or sidecar). Required + optional fields:

   ```yaml
   ---
   source_url: <url|n/a>
   source_type: <video-transcript | tweet | article | image | pdf | docx | xlsx | csv | chat | book-chapter | meeting-notes | code | ...>
   source_title: "..."
   source_author: "..."
   fetched_at: <YYYY-MM-DD>
   ingested_hash: ""
   ingested_at: never
   ingested_pages: []
   extraction_method: <webfetch | passthrough | csv-passthrough | pdftotext | llm-vision | pandoc | python-docx | xlsx2csv | openpyxl | failed>
   extraction_status: <ok | degraded | failed>   # optional; omit when ok
   notes: |
     <optional context about why this was fetched, or how it was acquired. If extraction was degraded or failed, name the missing tool and the install hint here.>
   ---
   ```

   For binaries: the frontmatter goes in the sidecar `.md`, not the binary.

5. **Verify** the file was written. Read it back, confirm frontmatter is valid YAML.

## What you must NOT do

- Modify any file in `wiki/`.
- Modify `log.md` (acquisition is not an ingest — no log entry).
- Set `ingested_hash` to a non-empty value (that's `/wiki-ingest`'s job).
- Process the content into wiki pages (that's the next command).
- Run with no argument. If `$ARGUMENTS` is empty, ask the user what to fetch.
- In inline-text mode, whitespace-split the content or treat its words as separate sources. The text after `--text` (and optional `--title "..."` / `--source-type <value>` flags) is **one** source, written verbatim.

## Output

**Single-source mode** — end with:

```
/wiki-extract complete.

Fetched: <source>
Saved to: raw/<filename>
Type: <source_type>
Hash: (will be computed at first /wiki-ingest)

Next: run /wiki-ingest to integrate into the wiki.
```

**Bulk mode** (more than one source in `$ARGUMENTS`) — end with a single consolidated summary:

```
/wiki-extract complete — batch of N sources.

OK (M):
  <source-1> → raw/<slug-1>.<ext> (<source_type>)
  <source-2> → raw/<slug-2>.<ext> (<source_type>)
  ...

Degraded (D):
  <source-x> → raw/<slug-x>.<ext> — <reason, e.g. used llm-vision fallback>
  ...

Failed (F):
  <source-y> → raw/<slug-y>.<ext>.md (extraction_status: failed) — <reason>
  ...

Next: run /wiki-ingest to integrate into the wiki.
```

N = M + D + F. If F > 0, also surface a one-line hint on how to remediate (install missing tool, fix path, retry URL). If M = 0, exit-state should still be "complete" — the failed-sidecars are themselves the deliverable for the next run.
