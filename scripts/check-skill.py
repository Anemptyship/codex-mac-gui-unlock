#!/usr/bin/env python3
"""Ask a local Codex app-server to enumerate skills; no model turn or secret access."""
import argparse
import json
import selectors
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--codex", default="codex")
args = parser.parse_args()
process = subprocess.Popen([args.codex, "app-server", "--stdio"], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True, bufsize=1)
def send(value):
    process.stdin.write(json.dumps(value) + "\n"); process.stdin.flush()
selector = selectors.DefaultSelector(); selector.register(process.stdout, selectors.EVENT_READ)
send({"id":1, "method":"initialize", "params":{"clientInfo":{"name":"mac_gui_unlock_discovery", "version":"0.1.0"}}})
found = False
try:
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if not selector.select(timeout=1):
            continue
        line = process.stdout.readline()
        if not line:
            break
        response = json.loads(line)
        if response.get("id") == 1:
            send({"method":"initialized"})
            send({"id":2, "method":"skills/list", "params":{"cwds":[str(Path.cwd())], "forceReload":True}})
        if response.get("id") == 2:
            def search(value):
                if isinstance(value, dict):
                    if value.get("name") == "mac-gui-unlock":
                        return True
                    return any(search(child) for child in value.values())
                return isinstance(value, list) and any(search(child) for child in value)
            found = search(response.get("result", {}))
            print(json.dumps({"codex_skill_discovered":found, "invocation":"$mac-gui-unlock", "source":"local app-server skills/list", "protocol_error": "error" in response}))
            break
    else:
        print(json.dumps({"codex_skill_discovered":False, "result":"discovery_timeout"}))
finally:
    selector.close(); process.terminate()
    try:
        process.wait(timeout=3)
    except subprocess.TimeoutExpired:
        process.kill(); process.wait()
raise SystemExit(0 if found else 2)
