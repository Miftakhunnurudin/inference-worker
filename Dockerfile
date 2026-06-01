# llama.cpp server with Qwen3.5 support + CUDA 12.4
# Uses pre-built ghcr.io image directly (includes all shared libs)

FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Install Python 3.12 + system deps (Ubuntu 24.04 default)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3 python3-dev python3-pip curl procps && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /work
ADD ./src /work

RUN pip install -r requirements.txt && chmod +x start.sh

ENTRYPOINT ["/bin/sh", "-c", "/work/start.sh"]
