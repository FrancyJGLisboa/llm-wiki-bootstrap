This file has no YAML frontmatter at all — it is plain prose with no `---`
delimiters anywhere. body-hash.sh must reject it (exit 1) rather than hashing it
as if the whole file were the body of an empty frontmatter block.
