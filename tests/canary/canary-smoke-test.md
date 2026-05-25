# Canary Smoke Test

This file is a tiny plain-markdown source used to verify that `/wiki-extract` works end-to-end in your AI tool. It exists purely so the *first* invocation of `/wiki-extract` you run in this repo is a known-good case with a known-good expected output, instead of being whatever real source you happened to bring.

## What this exercises

When you run `/wiki-extract tests/canary/canary-smoke-test.md` in your AI runtime, the agent should:

1. Detect this as **plain text** (`.md` extension).
2. Copy it to `raw/canary-smoke-test.md`.
3. Write the required frontmatter (`source_url`, `source_type`, `fetched_at`, `ingested_hash: ""`, `ingested_at: never`, `ingested_pages: []`, `extraction_method: passthrough`).
4. Leave the body content (everything below this line in `raw/`) intact.

It should **NOT**:

- Modify anything under `wiki/`.
- Write to `log.md`.
- Set `ingested_hash` to a non-empty value (that's `/wiki-ingest`'s job, not `/wiki-extract`'s).

## How to verify

After running `/wiki-extract` in your AI tool, from a shell:

```bash
./scripts/verify-extract.sh canary-smoke-test
```

The verifier checks the *shape* of the produced output (required fields present, frontmatter parses, body non-empty). It does **not** check semantics — a wrong `source_type` value would slip past. For semantics, eyeball the produced `raw/canary-smoke-test.md`.

## Cleanup

After verifying:

```bash
rm raw/canary-smoke-test.md
```

Or leave it — it costs nothing.
