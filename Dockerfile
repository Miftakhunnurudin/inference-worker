# llama.cpp server with Qwen3.5 support + CUDA 12.4
# Uses pre-built ghcr.io image directly (includes all shared libs)

FROM ghcr.io/ggml-org/llama.cpp:server-cuda

# Install Python 3.11 + system deps
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3.11 python3.11-dev python3.11-distutils curl procps && \
    ln -s /usr/bin/python3.11 /usr/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /work
ADD ./src /work

RUN pip install -r requirements.txt && chmod +x start.sh

ENTRYPOINT ["/bin/sh", "-c", "/work/start.sh"]
