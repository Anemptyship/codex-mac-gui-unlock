#!/usr/bin/env python3
"""Install only this project's signed app and collision-checked skill symlink."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

IDENTITY = "org.codexcommunity.MacGUIUnlock"
APP = "Codex Mac GUI Unlock.app"
SOURCE = Path(__file__).resolve().parents[1]

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def install(root, build=True):
    root = root.resolve()
    app = root / "Applications" / APP
    skill = root / ".agents/skills/mac-gui-unlock"
    manifest = root / ".agents/mac-gui-unlock-install.json"
    source_skill = SOURCE / ".agents/skills/mac-gui-unlock"
    built = SOURCE / "dist" / APP
    if build:
        subprocess.run([str(SOURCE / "scripts/build.sh")], check=True)
    if not built.is_dir():
        raise RuntimeError("Build the app first")
    subprocess.run(["/usr/bin/codesign", "--verify", "--deep", "--strict", str(built)], check=True)
    if manifest.is_symlink():
        raise RuntimeError("Refusing symbolic-link manifest")
    old = json.loads(manifest.read_text()) if manifest.exists() else None
    if old and (old.get("identity") != IDENTITY or old.get("source") != str(SOURCE)):
        raise RuntimeError("Manifest belongs to a different installation")
    if os.path.lexists(skill) and (not skill.is_symlink() or skill.resolve() != source_skill):
        raise RuntimeError("Skill collision: existing destination left untouched")
    if os.path.lexists(app):
        if app.is_symlink() or not old or old.get("binary_sha256") != digest(app / "Contents/MacOS/GUIUnlock"):
            raise RuntimeError("Application collision or modified installation left untouched")
        if old["binary_sha256"] != digest(built / "Contents/MacOS/GUIUnlock"):
            raise RuntimeError("Build changed: revoke and uninstall the previous app before reinstalling")
    if not app.exists():
        app.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(built, app)
    skill.parent.mkdir(parents=True, exist_ok=True)
    if not skill.is_symlink():
        skill.symlink_to(source_skill, target_is_directory=True)
    record = {"identity": IDENTITY, "source": str(SOURCE), "binary_sha256": digest(app / "Contents/MacOS/GUIUnlock")}
    fd = os.open(manifest, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as handle:
        json.dump(record, handle)
    if root == Path.home():
        subprocess.run(["/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister", "-f", str(app)], check=True)
    print(json.dumps({"installed": True, "skill_registered": skill.is_symlink(), "credentials_modified": False}))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--root", type=Path, default=Path.home(), help="Test installation root; defaults to current home")
    parser.add_argument("--no-build", action="store_true")
    args = parser.parse_args()
    try:
        install(args.root, not args.no_build)
    except (RuntimeError, OSError, ValueError, subprocess.CalledProcessError) as error:
        print(json.dumps({"installed": False, "reason": str(error)}), file=sys.stderr)
        sys.exit(2)
