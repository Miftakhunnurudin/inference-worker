import unittest

from src.utils import JobInput


class JobInputTests(unittest.TestCase):
    def test_prompt_input_extracts_inference_kwargs(self):
        job = JobInput(
            {
                "prompt": "hello",
                "stream": True,
                "temperature": 0.7,
                "max_tokens": 128,
            }
        )

        job.validate()

        self.assertEqual(job.llm_input, "hello")
        self.assertTrue(job.stream)
        self.assertEqual(job.inference_kwargs["temperature"], 0.7)
        self.assertEqual(job.inference_kwargs["max_tokens"], 128)

    def test_messages_input_is_valid(self):
        job = JobInput(
            {
                "messages": [
                    {"role": "system", "content": "You are helpful."},
                    {"role": "user", "content": "Hi"},
                ]
            }
        )

        job.validate()
        self.assertIsInstance(job.llm_input, list)

    def test_missing_prompt_and_messages_is_invalid(self):
        job = JobInput({"stream": False})
        with self.assertRaises(ValueError):
            job.validate()

    def test_invalid_openai_route_is_rejected(self):
        job = JobInput({"openai_route": "/v1/unknown"})
        with self.assertRaises(ValueError):
            job.validate()


if __name__ == "__main__":
    unittest.main()
