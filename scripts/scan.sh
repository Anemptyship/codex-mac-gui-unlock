#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
command -v gitleaks >/dev/null 2>&1 || { echo 'Install gitleaks before scanning or pushing.' >&2; exit 2; }
gitleaks dir --redact --no-banner --log-level warn .
if git rev-parse --verify HEAD >/dev/null 2>&1; then
    gitleaks git --redact --no-banner --log-level warn .
fi
python3 scripts/check-public-tree.py
