<p align="center">
    <img src="https://raw.githubusercontent.com/ggml-org/llama.cpp/master/media/llama1-icon-transparent.png" alt="llama.cpp logo" width="128">
</p>

# Serverless llama.cpp inference worker for RunPod

This repository contains a serverless inference worker for running llama.cpp models on RunPod. It uses the `llama-server` image to provide an API for interacting with the models.
The following OpenAI API endpoints are supported:

- `v1/models`
- `v1/chat/completions`
- `v1/completions`

Streaming responses is also supported.

## OpenAI-Compatible Usage

When deployed on RunPod Serverless, this worker can be used through RunPod's
OpenAI-compatible path:

- `https://api.runpod.ai/v2/<YOUR_ENDPOINT_ID>/openai/v1`

That makes it usable from tools that only know how to talk to an OpenAI-style
API, such as AI harnesses and coding agents.

### Python Example

```python
from openai import OpenAI
import os

client = OpenAI(
    api_key=os.environ["RUNPOD_API_KEY"],
    base_url="https://api.runpod.ai/v2/<YOUR_ENDPOINT_ID>/openai/v1",
)

models = client.models.list()
model = models.data[0].id

response = client.chat.completions.create(
    model=model,
    messages=[{"role": "user", "content": "Write a hello world program."}],
)

print(response.choices[0].message.content)
```

### cURL Example

```bash
curl "https://api.runpod.ai/v2/<YOUR_ENDPOINT_ID>/openai/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $RUNPOD_API_KEY" \
  -d '{
    "model": "<MODEL_FROM_/v1/models>",
    "messages": [
      {"role": "user", "content": "Say hello in one sentence."}
    ]
  }'
```

### Model Name Override

If your client expects a stable model name instead of the raw llama.cpp model
identifier, set `OPENAI_SERVED_MODEL_NAME_OVERRIDE`. The worker will:

- expose that value from `v1/models`
- accept that same value on `v1/chat/completions` and `v1/completions`

This is useful when wiring the endpoint into tools that require a fixed OpenAI
model name.

**Important!** This project is still relatively new. Please [open a new issue](https://github.com/Jacob-ML/inference-worker/issues/new) if you encounter any problems in order to get help.

**This is a fork of [SvenBrnn's `runpod-worker-ollama`](https://github.com/SvenBrnn/runpod-worker-ollama).**

## Setup

To get the best performance out of this worker, it is recommended to use cached models. Please see the [cached models documentation](./docs/cached.md) for more information, this is **highly recommended and will save many resources**.

## Configuration

The worker can be configured via environment variables set in the RunPod hub configuration:

Important: to use RunPod managed cached models, you must also set the endpoint **Model** field in RunPod to the same Hugging Face repository as `LLAMA_CACHED_MODEL`.

If you deploy from the RunPod Hub listing in this repository, `LLAMA_CACHED_MODEL` is exposed as a Hugging Face selector field named `RunPod Cached Model` in `.runpod/hub.json`.

- `LLAMA_SERVER_CMD_ARGS`: Non-model command line arguments (argv) for the `llama-server` binary. Example: `--ctx-size 4096 -ngl 999`. **IMPORTANT**: Please do not define `--port`, `-m`, `-hf`, or `-hff` here.
- `LLAMA_CACHED_MODEL`: Hugging Face model ID used for cached model lookup and optional fallback download.
- `LLAMA_CACHED_GGUF_PATH`: GGUF file path inside the Hugging Face model repository. Recommended to keep fallback deterministic.
- `LLAMA_CACHE_MISS_FALLBACK`: Behavior when cached model lookup fails. Supported values: `download` (default) and `fail`.
- `MAX_CONCURRENCY`: Maximum number of concurrent requests the worker can handle. Default is `8`.
- `OPENAI_SERVED_MODEL_NAME_OVERRIDE`: Optional stable public model name for the OpenAI-compatible API.

When using cached models, do not include `-m`, `-hf`, or `-hff` in `LLAMA_SERVER_CMD_ARGS`. The worker will generate those arguments automatically.

## License

Please see the [LICENSE](./LICENSE) file for more information.

[![Runpod badge](https://api.runpod.io/badge/Jacob-ML/inference-worker)](https://console.runpod.io/hub/Jacob-ML/inference-worker)
