"""
This module contains utility classes and functions for handling job inputs.
"""


class JobInput:
    """
    Class to parse and store job input data. It extracts fields such as
    llm_input, stream, openai_route, and openai_input from the provided job
    dictionary.
    """

    def __init__(self, job):
        """
        Initialize the JobInput instance by parsing the job dictionary.

        Default values:
        - llm_input: job["messages"] if present, else job["prompt"]
        - stream: False
        - openai_route: None
        - openai_input: None
        """

        if not isinstance(job, dict):
            raise ValueError("input must be a JSON object")

        self.llm_input = job.get("messages", job.get("prompt"))
        self.openai_route = job.get("openai_route")
        self.openai_input = job.get("openai_input")

        if self.openai_route == "/v1/models" and self.openai_input is None:
            # RunPod can route model-list requests without a JSON body.
            self.openai_input = {}

        self.stream = job.get(
            "stream",
            self.openai_input.get("stream", False)
            if isinstance(self.openai_input, dict)
            else False,
        )

        self.inference_kwargs = {
            k: v
            for k, v in job.items()
            if k
            not in {
                "prompt",
                "messages",
                "stream",
                "openai_route",
                "openai_input",
            }
        }

    def validate(self):
        if self.openai_route:
            if self.openai_route not in {
                "/v1/models",
                "/v1/chat/completions",
                "/v1/completions",
            }:
                raise ValueError("openai_route is invalid")
            if (
                self.openai_route != "/v1/models"
                and not isinstance(self.openai_input, dict)
            ):
                raise ValueError(
                    "openai_input must be a JSON object for this route"
                )
            return

        if self.llm_input is None:
            raise ValueError("input must include either 'prompt' or 'messages'")

        if not isinstance(self.stream, bool):
            raise ValueError("stream must be a boolean")
