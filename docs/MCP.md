# MCP access (optional)

Make this wiki readable — and optionally writable — by any MCP-aware AI client without going through the slash commands. Useful when:

- You want Claude Desktop, ChatGPT Desktop, Cursor, or another client to answer questions from the wiki directly (no `/wiki-query` indirection).
- You're running a non-Claude-Code agent that can't load `.claude/commands/wiki-*.md`.
- You want BM25 search over the wiki without writing a custom indexer.

This is an **optional read surface**. The three-layer model and the five slash commands are unchanged. MCP doesn't replace them — it adds a parallel programmatic door into the same files.

## What we use

[`@bitbonsai/mcpvault`](https://github.com/bitbonsai/mcpvault) — a lightweight MCP server that exposes any directory of markdown files (frontmatter-aware, BM25 search, safe write modes). The "vault" in the name is naming, not a requirement: it works on `wiki/` here without Obsidian installed.

Why we picked it: it's already published on npm, it's frontmatter-aware (won't corrupt our YAML), it gives BM25 search out of the box, and zero plugin dependencies. If it later proves unsuitable, the MCP protocol means swapping it is a one-file change.

## Quick start

```bash
# 1. Confirm npx is available.
./scripts/preflight.sh   # look for "npx — present"

# 2. Launch the server (foregrounded for testing).
./scripts/mcp-server.sh

# In another shell, ask any MCP client to connect (see "Register with a client" below).
```

The launcher is just a thin convenience around `npx -y @bitbonsai/mcpvault@latest wiki/`. You can invoke `npx` directly if you prefer; the launcher only resolves the path and reports clearer errors when `npx` is missing.

Point it at `raw/` instead by passing the directory:

```bash
./scripts/mcp-server.sh raw    # expose raw/ to clients
./scripts/mcp-server.sh .      # expose the whole repo (rare; not recommended)
```

## Register with a client

The MCP server runs as a stdio child of the AI client. The client launches it on demand — you don't need to start `scripts/mcp-server.sh` yourself once the config below is in place.

### Claude Desktop

Edit `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS) or `%APPDATA%\Claude\claude_desktop_config.json` (Windows):

```json
{
  "mcpServers": {
    "llm-wiki": {
      "command": "npx",
      "args": ["-y", "@bitbonsai/mcpvault@latest", "/absolute/path/to/llm-wiki-bootstrap/wiki"]
    }
  }
}
```

Restart Claude Desktop. The wiki appears as an MCP source in the UI.

### Claude Code

Edit `~/.claude.json` (or your project-local `.claude.json`):

```json
{
  "mcpServers": {
    "llm-wiki": {
      "command": "npx",
      "args": ["-y", "@bitbonsai/mcpvault@latest", "/absolute/path/to/llm-wiki-bootstrap/wiki"],
      "env": {}
    }
  }
}
```

Run `claude mcp list` to confirm registration.

### Cursor

In `~/.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "llm-wiki": {
      "command": "npx",
      "args": ["-y", "@bitbonsai/mcpvault@latest", "/absolute/path/to/llm-wiki-bootstrap/wiki"]
    }
  }
}
```

### Other clients

Any MCP-compatible client (OpenCode, Gemini CLI, OpenAI Codex, IntelliJ 2025.1+, Windsurf, ChatGPT Desktop Enterprise+) follows the same shape: name the server, set `command: npx`, pass `-y @bitbonsai/mcpvault@latest <absolute-wiki-path>` as args. Check the client's MCP docs for the exact config file location.

## What the server exposes

Per `@bitbonsai/mcpvault`'s feature list, the server provides ~14 MCP tools:

| Category | Tools |
|---|---|
| Read | `read_note`, `read_multiple_notes`, `list_directory`, `get_notes_info`, `get_vault_stats` |
| Write | `write_note`, `patch_note`, `move_note`, `move_file`, `delete_note` (requires confirmation) |
| Search | `search_notes` (multi-word matching with BM25 relevance reranking) |
| Frontmatter | `get_frontmatter`, `update_frontmatter` |
| Tags | `manage_tags` (add / remove / list) |

The write tools respect frontmatter — they parse with gray-matter and preserve formatting on fields they don't touch. That matters for this repo: `ingested_hash`, `ingested_at`, and `ingested_pages` should only be touched by `/wiki-ingest`. Out of band MCP writes that overwrite them will break ingest idempotence.

## Recommended posture: read-only by default

In the current repo we recommend treating MCP as a **read** surface only. Writes flow through the five slash commands so the `log.md` audit trail stays accurate. To enforce that at the client level, some clients let you allow-list MCP tools — restrict to `read_note`, `read_multiple_notes`, `list_directory`, `search_notes`, `get_notes_info`, `get_vault_stats`, `get_frontmatter`.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Client can't find the server | Wrong absolute path | Use `realpath wiki/` to get the canonical path, paste that into the config |
| `npx: command not found` | Node.js missing | Install Node ≥18 (https://nodejs.org), rerun `./scripts/preflight.sh` |
| Server starts then hangs | Normal | MCP is stdio-based; the server waits for the client to speak first |
| BM25 returns nothing | First run | The server indexes on connect; give it a few seconds the first time |
| YAML corruption after writes | Out-of-band write hit a field `/wiki-ingest` owns | Run `/wiki-lint`; surface the contradiction and re-ingest from `raw/` |

## See also

- [`AGENTS.md`](../AGENTS.md) — three-layer model and the slash commands MCP complements
- [`scripts/mcp-server.sh`](../scripts/mcp-server.sh) — the launcher
- [`scripts/preflight.sh`](../scripts/preflight.sh) — checks npx availability
- Upstream: https://github.com/bitbonsai/mcpvault — for issues with the MCP server itself
