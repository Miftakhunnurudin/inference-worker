# Build llama.cpp with Qwen3.5 support + CUDA 12.4 compatibility
# Supports all NVIDIA GPUs (RTX 4090, A5000, A40, H100, etc.)

# === STAGE 1: Build llama.cpp from source ===
FROM nvidia/cuda:12.4.1-devel-ubuntu22.04 AS builder

ARG LLAMA_CPP_TAG=b8500

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    build-essential cmake curl git && \
    rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/ggml-org/llama.cpp /llama && \
    cd /llama && git checkout tags/${LLAMA_CPP_TAG} && \
    cmake -B build \
        -DGGML_CUDA=ON \
        -DLLAMA_CUDA=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_CUDA_ARCHITECTURES="70;80;86;89;90" && \
    LD_LIBRARY_PATH=/usr/local/cuda/lib64/stubs:${LD_LIBRARY_PATH} \
    cmake --build build --config Release -j $(nproc) --target llama-server

# === STAGE 2: Runtime image ===
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

# Copy llama-server + shared libs
COPY --from=builder /llama/build/bin/llama-server /app/llama-server
COPY --from=builder /llama/build/src/libllama.so /usr/lib/
COPY --from=builder /llama/build/ggml/src/libggml*.so* /usr/lib/
COPY --from=builder /llama/build/ggml/src/ggml-cuda/libggml-cuda.so /usr/lib/

# Install Python 3.11
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
    python3.11 python3.11-dev python3.11-distutils curl && \
    ln -s /usr/bin/python3.11 /usr/bin/python && \
    curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11 && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /work
ADD ./src /work

RUN pip install -r requirements.txt && chmod +x start.sh

ENV LD_LIBRARY_PATH=/usr/lib
ENTRYPOINT ["/bin/sh", "-c", "/work/start.sh"]
