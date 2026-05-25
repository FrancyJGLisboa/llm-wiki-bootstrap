---
description: Acquire a URL, local file, or image into raw/ with frontmatter. Does not modify wiki/.
allowed-tools: Bash, Read, Write, WebFetch
argument-hint: <url-or-filepath-or-image-path>
---

You are executing `/wiki-extract $ARGUMENTS` from the `llm-wiki-bootstrap` system. Your job is to acquire one source and deposit it in `raw/` with the right frontmatter. You **never touch `wiki/`** in this command.

## Read first

Read `AGENTS.md` to confirm the raw source frontmatter convention and the slug naming convention.

## Steps

1. **Identify the source type** from `$ARGUMENTS`:
   - Starts with `http://` or `https://` → URL
   - Path to a `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp` → image
   - Path to a `.pdf` → PDF
   - Path to a `.md`, `.txt`, `.html`, `.json`, etc. → local text file
   - Anything else: ask the user to clarify.

2. **Derive a slug** for the file name in `raw/`:
   - URL: domain + path-leaf (e.g. `karpathy-tweet-1234.md`), kebab-case, drop punctuation.
   - File: original basename, kebab-cased.
   - If the slug collides with an existing file in `raw/`, append a date suffix (`-2026-05-25`).

3. **Acquire the content:**
   - **URL:** use `WebFetch` with a prompt like "Return the main textual content of this page as clean markdown, preserving headings and lists." Save the result body.
   - **Local text:** use `Read`, then `Write` to `raw/<slug>.<ext>` (often `.md`).
   - **Image:** copy the binary to `raw/<slug>.<ext>` via `Bash cp`. Then use vision to extract any text in the image AND write a short description. Save as a **sidecar** at `raw/<slug>.<ext>.md`.
   - **PDF:** copy to `raw/<slug>.pdf`. Extract text (use `Bash pdftotext` if available; otherwise note the limitation). Save extracted text as `raw/<slug>.pdf.md`.

4. **Write the frontmatter** at the top of the markdown file (or sidecar). Required fields:

   ```yaml
   ---
   source_url: <url|n/a>
   source_type: <video-transcript | tweet | article | image | pdf | chat | book-chapter | meeting-notes | code | ...>
   source_title: "..."
   source_author: "..."
   fetched_at: <YYYY-MM-DD>
   ingested_hash: ""
   ingested_at: never
   ingested_pages: []
   notes: |
     <optional context about why this was fetched, or how it was acquired>
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

## Output

End with:

```
/wiki-extract complete.

Fetched: <source>
Saved to: raw/<filename>
Type: <source_type>
Hash: (will be computed at first /wiki-ingest)

Next: run /wiki-ingest to integrate into the wiki.
```
