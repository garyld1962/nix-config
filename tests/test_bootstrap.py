"""Ensure the master installer rejects unsafe invocation before installation."""
import os
from pathlib import Path
import subprocess
import unittest

ROOT = Path(__file__).resolve().parents[1]


class BootstrapTests(unittest.TestCase):
    def test_non_wsl_invocation_is_rejected(self):
        env = dict(os.environ)
        env.pop("WSL_DISTRO_NAME", None)
        result = subprocess.run(["bash", str(ROOT / "bootstrap.sh")], env=env,
                                text=True, capture_output=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("inside an Ubuntu WSL", result.stderr)

    def test_unknown_option_is_rejected_before_installation(self):
        result = subprocess.run(["bash", str(ROOT / "bootstrap.sh"), "--unknown"],
                                text=True, capture_output=True, timeout=5)
        self.assertEqual(result.returncode, 64)
        self.assertIn("Usage:", result.stderr)


if __name__ == "__main__":
    unittest.main()
