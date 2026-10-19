"""Check user isolation and profile generation before touching a real account."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "generate_profile", Path(__file__).resolve().parents[1] / "scripts/generate-profile.py"
)
profile = importlib.util.module_from_spec(spec)
spec.loader.exec_module(profile)


class ProfileTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name) / "shared source"
        self.root.mkdir()
        (self.root / "flake.lock").write_text("{}")
        self.destination = Path(self.temporary.name) / "profile"

    def test_profiles_use_each_developers_identity(self):
        for username, home in [("alice", "/home/alice"), ("bob", "/srv/dev homes/bob")]:
            target = profile.generate(self.root, self.destination, username, home)
            content = target.read_text()
            self.assertIn(f'username = "{username}";', content)
            self.assertIn(f'homeDirectory = "{home}";', content)
            self.assertNotIn("gary", content)
            self.assertNotIn("221B", content)

    def test_missing_shared_lock_is_rejected(self):
        (self.root / "flake.lock").unlink()
        with self.assertRaisesRegex(ValueError, "flake.lock"):
            profile.generate(self.root, self.destination, "alice", "/home/alice")
        self.assertFalse(self.destination.exists())

    def test_existing_manual_configuration_is_preserved(self):
        self.destination.mkdir()
        target = self.destination / "flake.nix"
        target.write_text("# My private setup\n")
        with self.assertRaisesRegex(ValueError, "manually maintained"):
            profile.generate(self.root, self.destination, "alice", "/home/alice")
        self.assertEqual(target.read_text(), "# My private setup\n")

    def test_nix_interpolation_and_quotes_are_escaped(self):
        value = '/home/a"${builtins.abort "bad"}'
        literal = profile.nix_string(value)
        self.assertIn(r"\${", literal)
        self.assertIn(r'\"', literal)

    def test_repeated_generation_does_not_rewrite_the_profile(self):
        target = profile.generate(self.root, self.destination, "alice", "/home/alice")
        previous = target.stat().st_mtime_ns
        profile.generate(self.root, self.destination, "alice", "/home/alice")
        self.assertEqual(previous, target.stat().st_mtime_ns)


if __name__ == "__main__":
    unittest.main()
