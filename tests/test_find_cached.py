import tempfile
import unittest
from pathlib import Path

from src import find_cached


class FindCachedTests(unittest.TestCase):
    def test_returns_newest_snapshot_with_existing_file(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            original_cache_dir = find_cached.CACHE_DIR
            try:
                find_cached.CACHE_DIR = tmpdir
                base = Path(tmpdir) / "models--user--model" / "snapshots"
                (base / "0001").mkdir(parents=True)
                (base / "0002").mkdir(parents=True)
                (base / "0002" / "model.gguf").write_text("ok")

                resolved = find_cached.find_model_path(
                    "user/model", "model.gguf"
                )

                self.assertTrue(resolved.endswith("0002/model.gguf"))
            finally:
                find_cached.CACHE_DIR = original_cache_dir

    def test_returns_none_if_file_missing(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            original_cache_dir = find_cached.CACHE_DIR
            try:
                find_cached.CACHE_DIR = tmpdir
                base = Path(tmpdir) / "models--user--model" / "snapshots"
                (base / "0001").mkdir(parents=True)

                resolved = find_cached.find_model_path(
                    "user/model", "model.gguf"
                )

                self.assertIsNone(resolved)
            finally:
                find_cached.CACHE_DIR = original_cache_dir


if __name__ == "__main__":
    unittest.main()
