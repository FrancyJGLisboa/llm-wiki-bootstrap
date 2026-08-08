# Same stand-in as the clean tree, so the ONLY difference between the two trees
# is the hardcoded path in scripts/resolve.sh.
ctx_root() { [ -d "${1:-.}/context" ] && printf 'context\n' || printf 'wiki\n'; }
