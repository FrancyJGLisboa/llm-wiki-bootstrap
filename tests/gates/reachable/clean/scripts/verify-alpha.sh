#!/usr/bin/env bash
# Invoked from the workflow. Calls the second oracle on the next line.
bash "$(dirname "$0")/verify-beta.sh"
