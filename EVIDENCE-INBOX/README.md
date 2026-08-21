# EVIDENCE-INBOX

Drop new evidence here. Nested folders are allowed.

- You own these files. The compiler must never edit or delete them.
- Symlinks are rejected so evidence cannot silently escape the workspace.
- `/ctx-inbox` extracts new or changed files into immutable `raw/` sources and
  records the mapping in `context/inbox-state.json`.
- A file becomes pending again when its bytes change.

Keep sensitive evidence local unless you have deliberately configured a remote.
