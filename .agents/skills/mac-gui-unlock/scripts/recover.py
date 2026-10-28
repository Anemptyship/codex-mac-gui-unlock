#!/usr/bin/env python3
"""One bounded recovery; the calling agent owns the exact pending GUI operation."""
import argparse
import json
from pathlib import Path
import subprocess
import sys
import uuid

LAUNCHER = Path(__file__).with_name("mac-gui-unlock.py")

def call(command, task=None):
    argv = [sys.executable, str(LAUNCHER), command]
    if task:
        argv += ["--task", str(task)]
    process = subprocess.run(argv, capture_output=True, text=True, timeout=25)
    try:
        return process.returncode, json.loads(process.stdout)
    except ValueError:
        return 3, {"result":"invalid_receipt_do_not_retry", "recovered":False}

def recover(task, invoke=call):
    code, before = invoke("status")
    if code:
        return code, before
    state = before.get("observation", {}).get("state")
    if state == "unlocked":
        return 0, {"result":"already_unlocked_verify_pending_gui_once", "recovered":False, "retry_pending_gui_once":True}
    if state != "locked":
        return 2, {"result":"lock_state_unknown", "recovered":False}
    code, preflight = invoke("preflight")
    if code:
        return code, preflight
    code, attempt = invoke("unlock-once", task)
    if code or not attempt.get("recovered"):
        return code or 2, attempt
    code, after = invoke("status")
    first = before.get("observation", {})
    last = after.get("observation", {})
    if code or not last.get("ownSession") or last.get("state") != "unlocked" or last.get("session") != first.get("session"):
        return 3, {"result":"independent_status_failed_do_not_retry", "recovered":False}
    return 0, {"result":"os_unlock_observed_pending_gui_verification", "recovered":True, "gui_verified":False, "retry_pending_gui_once":True}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--task", required=True, type=uuid.UUID)
    args = parser.parse_args()
    try:
        code, result = recover(args.task)
    except (OSError, subprocess.TimeoutExpired):
        code, result = 3, {"result":"recovery_timeout_do_not_retry", "recovered":False}
    print(json.dumps(result)); sys.exit(code)
