#!/usr/bin/env python3
"""Launch the fixed signed app through LaunchServices, then read its redacted receipt."""
import argparse
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import time
import uuid

COMMANDS = ("status", "preflight", "permissions", "setup", "grant", "unlock-once", "revoke", "uninstall")

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", choices=COMMANDS)
    parser.add_argument("--task", type=uuid.UUID)
    args = parser.parse_args()
    if args.command in ("grant", "unlock-once") and not args.task:
        parser.error("--task UUID is required")
    app = Path.home() / "Applications/Codex Mac GUI Unlock.app"
    if not app.is_dir() or app.is_symlink():
        print(json.dumps({"result": "app_not_installed", "recovered": False})); return 2
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True, capture_output=True)
    folder = Path.home() / "Library/Application Support/CodexMacGUIUnlock"
    folder.mkdir(mode=0o700, parents=True, exist_ok=True)
    info = folder.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
        print(json.dumps({"result": "unsafe_receipt_directory", "recovered": False})); return 2
    request = uuid.uuid4()
    receipt = folder / (str(request).upper() + ".json")
    argv = ["/usr/bin/open", "-n", "-a", str(app), "--args", "--command", args.command, "--request", str(request)]
    if args.task:
        argv.extend(["--task", str(args.task)])
    subprocess.run(argv, check=True, capture_output=True)
    deadline = time.monotonic() + (180 if args.command in ("setup", "grant", "permissions") else 20)
    while time.monotonic() < deadline:
        try:
            fd = os.open(receipt, os.O_RDONLY | os.O_NOFOLLOW)
        except FileNotFoundError:
            time.sleep(0.1); continue
        with os.fdopen(fd) as handle:
            info = os.fstat(handle.fileno())
            if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or info.st_nlink != 1 or stat.S_IMODE(info.st_mode) != 0o600 or info.st_size > 16384:
                print(json.dumps({"result": "unsafe_receipt", "recovered": False})); return 2
            result = json.load(handle)
        print(json.dumps(result, sort_keys=True))
        return result["exitCode"]
    print(json.dumps({"result": "receipt_timeout_do_not_retry", "recovered": False}))
    return 3

if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError):
        print(json.dumps({"result": "launcher_failed_do_not_retry", "recovered": False}))
        sys.exit(3)
