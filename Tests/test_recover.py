import importlib.util
from pathlib import Path
import unittest
import uuid

path = Path(__file__).resolve().parents[1] / ".agents/skills/mac-gui-unlock/scripts/recover.py"
spec = importlib.util.spec_from_file_location("recovery", path)
module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)

def observation(state, session=42):
    return {"observation":{"state":state, "session":session, "ownSession":True}}

class RecoveryTests(unittest.TestCase):
    def invoke(self, responses):
        self.calls = []
        def run(command, task=None):
            self.calls.append(command)
            return responses.pop(0)
        return run
    def test_success_still_requires_gui_proof(self):
        run = self.invoke([(0,observation("locked")), (0,{}), (0,{"recovered":True}), (0,observation("unlocked"))])
        code, result = module.recover(uuid.uuid4(), run)
        self.assertEqual(code,0); self.assertTrue(result["recovered"]); self.assertFalse(result["gui_verified"])
        self.assertEqual(self.calls, ["status","preflight","unlock-once","status"])
    def test_unknown_failure_no_retry(self):
        for attempt in [(2,{"result":"focus_changed"}), (3,{"recovered":False}), (0,{"recovered":False})]:
            run = self.invoke([(0,observation("locked")),(0,{}),attempt])
            code, result = module.recover(uuid.uuid4(),run)
            self.assertNotEqual(code,0); self.assertEqual(self.calls.count("unlock-once"),1)
    def test_changed_session_after_post_is_failure(self):
        run = self.invoke([(0,observation("locked")), (0,{}), (0,{"recovered":True}), (0,observation("unlocked",43))])
        self.assertEqual(module.recover(uuid.uuid4(),run)[0],3)
    def test_preflight_refusal_never_attempts(self):
        run = self.invoke([(0,observation("locked")), (2,{"result":"permissions_missing"})])
        self.assertEqual(module.recover(uuid.uuid4(),run)[0],2)
        self.assertNotIn("unlock-once", self.calls)
    def test_unlocked_is_noop(self):
        run = self.invoke([(0,observation("unlocked"))])
        code,result = module.recover(uuid.uuid4(),run)
        self.assertEqual(code,0); self.assertFalse(result["recovered"]); self.assertEqual(self.calls,["status"])
