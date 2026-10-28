#!/usr/bin/env python3
"""Reject common private paths/build products in the source tree without printing values."""
from pathlib import Path
import re
import hashlib
import json
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
result = subprocess.run(["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root, capture_output=True, check=True)
problems = []
for entry in result.stdout.split(b"\0"):
    if not entry:
        continue
    relative = entry.decode()
    file = root / relative
    if file.is_symlink():
        problems.append(relative); continue
    if any(part in {".build", "dist", ".local", "__pycache__"} for part in Path(relative).parts):
        problems.append(relative); continue
    if relative == "assets/AppIcon.png":
        reviewed = json.loads((root / "assets/manifest.json").read_text())["AppIcon.png"]
        data = file.read_bytes()
        if not data.startswith(b"\x89PNG\r\n\x1a\n") or hashlib.sha256(data).hexdigest() != reviewed["sha256"]:
            problems.append(relative)
        continue
    if file.suffix.lower() in {".png", ".jpg", ".log", ".key", ".p12", ".mobileprovision"}:
        problems.append(relative); continue
    try:
        content = file.read_text()
    except (UnicodeError, IsADirectoryError):
        problems.append(relative); continue
    if re.search(r"/Users/[A-Za-z0-9_-]+/|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}", content):
        problems.append(relative)
if problems:
    print("Public-tree review failed; inspect these filenames locally:", ", ".join(problems), file=sys.stderr)
    sys.exit(2)
print("Public-tree private-path and artifact checks passed.")
