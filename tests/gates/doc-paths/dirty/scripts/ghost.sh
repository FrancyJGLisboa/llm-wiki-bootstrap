#!/usr/bin/env bash
# Fixture for scripts/gate-doc-paths.sh. Never executed — the gate only checks
# whether the path exists and whether it is in the manifest. Shebang present so
# the repo-wide shellcheck job (-S error) does not flag SC2148.
scripts/ghost.sh
