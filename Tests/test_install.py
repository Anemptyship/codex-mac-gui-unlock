import importlib.util
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]

def run(name, root):
    return subprocess.run(["python3", str(ROOT / "scripts" / name), "--root", str(root)] + (["--no-build"] if name == "install.py" else []), capture_output=True)

class InstallTests(unittest.TestCase):
    def test_idempotency_collision_and_uninstall(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual(run("install.py", root).returncode, 0)
            self.assertEqual(run("install.py", root).returncode, 0)
            skill = root / ".agents/skills/mac-gui-unlock"
            self.assertTrue((skill / "SKILL.md").is_file())
            unrelated = root / "keep.txt"; unrelated.write_text("keep")
            self.assertEqual(run("uninstall.py", root).returncode, 0)
            self.assertEqual(run("uninstall.py", root).returncode, 0)
            self.assertEqual(unrelated.read_text(), "keep")
            self.assertFalse(skill.exists())
    def test_skill_collision_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory); skill = root / ".agents/skills/mac-gui-unlock"
            skill.mkdir(parents=True); (skill / "SKILL.md").write_text("foreign")
            self.assertNotEqual(run("install.py", root).returncode, 0)
            self.assertEqual((skill / "SKILL.md").read_text(), "foreign")
    def test_modified_app_is_preserved(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.assertEqual(run("install.py", root).returncode, 0)
            binary = root / "Applications/Codex Mac GUI Unlock.app/Contents/MacOS/GUIUnlock"
            binary.write_bytes(b"changed")
            self.assertNotEqual(run("uninstall.py", root).returncode, 0)
            self.assertEqual(binary.read_bytes(), b"changed")
    def test_skill_frontmatter_and_launcher_arguments(self):
        skill = ROOT / ".agents/skills/mac-gui-unlock/SKILL.md"
        header = skill.read_text().split("---", 2)[1]
        self.assertIn("name: mac-gui-unlock", header)
        self.assertIn("description:", header)
        launcher = ROOT / ".agents/skills/mac-gui-unlock/scripts/mac-gui-unlock.py"
        for arguments in (["unlock-once"], ["grant", "--task", "invalid"], ["status", "--password", "fixture-not-a-secret"]):
            result = subprocess.run(["python3", str(launcher), *arguments], capture_output=True)
            self.assertEqual(result.returncode, 2)

if __name__ == "__main__":
    unittest.main()
