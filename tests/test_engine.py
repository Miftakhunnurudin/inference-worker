import importlib
import importlib.util
import os
import unittest


class EngineImportTests(unittest.TestCase):
    @unittest.skipUnless(
        importlib.util.find_spec("dotenv")
        and importlib.util.find_spec("openai"),
        "requires dotenv and openai packages",
    )
    def test_engine_import_without_openai_api_key(self):
        previous = os.environ.pop("OPENAI_API_KEY", None)
        try:
            engine = importlib.import_module("src.engine")
            engine = importlib.reload(engine)
            self.assertIsNotNone(engine.client)
            self.assertTrue(hasattr(engine.client, "models"))
        finally:
            if previous is not None:
                os.environ["OPENAI_API_KEY"] = previous


if __name__ == "__main__":
    unittest.main()
