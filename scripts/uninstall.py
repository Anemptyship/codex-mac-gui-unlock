#!/usr/bin/env python3
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
from install import IDENTITY, SOURCE, APP, digest

def uninstall(root):
    root = root.resolve()
    manifest = root / ".agents/mac-gui-unlock-install.json"
    if manifest.is_symlink():
        raise RuntimeError("Refusing symbolic-link manifest")
    if not manifest.exists():
        print(json.dumps({"uninstalled": True, "already_absent": True})); return
    record = json.loads(manifest.read_text())
    if record.get("identity") != IDENTITY or record.get("source") != str(SOURCE):
        raise RuntimeError("Foreign installation left untouched")
    app = root / "Applications" / APP
    link = root / ".agents/skills/mac-gui-unlock"
    if os.path.lexists(link) and (not link.is_symlink() or link.resolve() != SOURCE / ".agents/skills/mac-gui-unlock"):
        raise RuntimeError("Foreign skill left untouched")
    if root == Path.home() and not os.path.lexists(app):
        raise RuntimeError("App absent: remove the dedicated Keychain item locally before manual cleanup; revocation cannot be verified")
    if os.path.lexists(app):
        if app.is_symlink() or record.get("binary_sha256") != digest(app / "Contents/MacOS/GUIUnlock"):
            raise RuntimeError("Modified app left untouched")
        marker = app / "Contents/Resources/project-marker"
        if not marker.is_file() or marker.read_text().strip() != IDENTITY:
            raise RuntimeError("Foreign or modified app marker left untouched")
        subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)], check=True, capture_output=True)
        if root == Path.home():
            subprocess.run([str(SOURCE / "scripts/mac-gui-unlock"), "uninstall"], check=True)
        shutil.rmtree(app)
    if link.is_symlink():
        link.unlink()
    manifest.unlink()
    print(json.dumps({"uninstalled": True, "receipts_retained_locally": True}))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.home())
    try:
        uninstall(parser.parse_args().root)
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(json.dumps({"uninstalled": False, "reason": str(error)}), file=sys.stderr); sys.exit(2)
