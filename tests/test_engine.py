import importlib
import importlib.util
import os
import sys
import unittest
from pathlib import Path


SRC_DIR = Path(__file__).resolve().parents[1] / "src"
if str(SRC_DIR) not in sys.path:
    sys.path.insert(0, str(SRC_DIR))


class FakeModel:
    def __init__(self, model_id):
        self.id = model_id

    def to_dict(self):
        return {"id": self.id, "object": "model"}


class FakeChunk:
    def __init__(self, payload):
        self.payload = payload

    def to_dict(self):
        return self.payload


class FakeResponse:
    def __init__(self, payload):
        self.payload = payload

    def to_dict(self):
        return self.payload


class FakeModelsAPI:
    def __init__(self, models):
        self.models = models

    def list(self):
        return type("ModelList", (), {"data": self.models})()


class FakeChatCompletionsAPI:
    def __init__(self):
        self.calls = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        if kwargs.get("stream"):
            return iter(
                [
                    FakeChunk({"choices": [{"delta": {"content": "hel"}}]}),
                    FakeChunk({"choices": [{"delta": {"content": "lo"}}]}),
                ]
            )
        return FakeResponse(
            {
                "id": "chatcmpl-1",
                "choices": [
                    {"message": {"role": "assistant", "content": "hello"}}
                ],
            }
        )


class FakeCompletionsAPI:
    def __init__(self):
        self.calls = []

    def create(self, **kwargs):
        self.calls.append(kwargs)
        return FakeResponse({"id": "cmpl-1", "choices": [{"text": "hello"}]})


class FakeClient:
    def __init__(self):
        self.models = FakeModelsAPI([FakeModel("local-model")])
        self.chat = type(
            "ChatAPI", (), {"completions": FakeChatCompletionsAPI()}
        )()
        self.completions = FakeCompletionsAPI()


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


class OpenAIEngineTests(unittest.IsolatedAsyncioTestCase):
    @unittest.skipUnless(
        importlib.util.find_spec("dotenv") and importlib.util.find_spec("openai"),
        "requires dotenv and openai packages",
    )
    async def test_models_route_uses_public_override_name(self):
        previous_override = os.environ.get("OPENAI_SERVED_MODEL_NAME_OVERRIDE")
        os.environ["OPENAI_SERVED_MODEL_NAME_OVERRIDE"] = "vibe-model"
        try:
            engine = importlib.import_module("engine")
            engine = importlib.reload(engine)
            fake_client = FakeClient()
            original_client = engine.client
            engine.client = fake_client
            try:
                openai_engine = engine.LlamaCPPOpenAIEngine()
                responses = [
                    response
                    async for response in openai_engine._handle_model_request()
                ]
            finally:
                engine.client = original_client

            self.assertEqual(responses[0]["data"][0]["id"], "vibe-model")
        finally:
            if previous_override is None:
                os.environ.pop("OPENAI_SERVED_MODEL_NAME_OVERRIDE", None)
            else:
                os.environ["OPENAI_SERVED_MODEL_NAME_OVERRIDE"] = previous_override

    @unittest.skipUnless(
        importlib.util.find_spec("dotenv") and importlib.util.find_spec("openai"),
        "requires dotenv and openai packages",
    )
    async def test_chat_route_rewrites_public_override_model_name(self):
        previous_override = os.environ.get("OPENAI_SERVED_MODEL_NAME_OVERRIDE")
        os.environ["OPENAI_SERVED_MODEL_NAME_OVERRIDE"] = "vibe-model"
        try:
            engine = importlib.import_module("engine")
            engine = importlib.reload(engine)
            fake_client = FakeClient()
            original_client = engine.client
            engine.client = fake_client
            try:
                openai_engine = engine.LlamaCPPOpenAIEngine()
                responses = [
                    response
                    async for response in openai_engine._handle_chat_or_completion_request(
                        {
                            "model": "vibe-model",
                            "messages": [{"role": "user", "content": "Hi"}],
                        },
                        chat=True,
                    )
                ]
            finally:
                engine.client = original_client

            self.assertEqual(
                fake_client.chat.completions.calls[0]["model"], "local-model"
            )
            self.assertEqual(responses[0]["choices"][0]["message"]["content"], "hello")
        finally:
            if previous_override is None:
                os.environ.pop("OPENAI_SERVED_MODEL_NAME_OVERRIDE", None)
            else:
                os.environ["OPENAI_SERVED_MODEL_NAME_OVERRIDE"] = previous_override

    @unittest.skipUnless(
        importlib.util.find_spec("dotenv") and importlib.util.find_spec("openai"),
        "requires dotenv and openai packages",
    )
    async def test_streaming_chat_route_yields_sse_chunks(self):
        engine = importlib.import_module("engine")
        engine = importlib.reload(engine)
        fake_client = FakeClient()
        original_client = engine.client
        engine.client = fake_client
        try:
            openai_engine = engine.LlamaCPPOpenAIEngine()
            responses = [
                response
                async for response in openai_engine._handle_chat_or_completion_request(
                    {
                        "model": "local-model",
                        "messages": [{"role": "user", "content": "Hi"}],
                        "stream": True,
                    },
                    chat=True,
                )
            ]
        finally:
            engine.client = original_client

        self.assertEqual(
            responses,
            [
                'data: {"choices":[{"delta":{"content":"hel"}}]}\n\n',
                'data: {"choices":[{"delta":{"content":"lo"}}]}\n\n',
                "data: [DONE]",
            ],
        )


if __name__ == "__main__":
    unittest.main()
