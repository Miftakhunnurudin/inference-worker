# llama.cpp server with Qwen3.5 support + CUDA 12.4
# Uses pre-built ghcr.io image to avoid building from source

# === STAGE 1: Get llama-server binary from pre-built image ===
FROM ghcr.io/ggml-org/llama.cpp:server-cuda AS llama-cpp

# === STAGE 2: Runtime image ===
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# Copy llama-server binary
COPY --from=llama-cpp /app/llama-server /app/llama-server

# Install Python 3.11 + system deps (procps for pkill, libgomp for llama-server)
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3.11 python3.11-dev python3.11-distutils curl procps libgomp1 && \
    ln -s /usr/bin/python3.11 /usr/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /work
ADD ./src /work

RUN pip install -r requirements.txt && chmod +x start.sh

ENTRYPOINT ["/bin/sh", "-c", "/work/start.sh"]
