#!/bin/bash

# fail on error:
set -e -o pipefail
set -x # verbose: print every command before executing

# This script starts the llama-server with the command line arguments
# specified in the environment variable LLAMA_SERVER_CMD_ARGS, ensuring
# that the server listens on port 3098. It also starts the handler.py
# script after the server is up and running.

cleanup() {
    echo "start.sh: Cleaning up..."
    pkill -P $$ # kill all child processes of the current script
    exit 0
}

MODEL_ARGS=""
CACHE_MISS_FALLBACK="${LLAMA_CACHE_MISS_FALLBACK:-download}"

resolve_cached_path() {
    local gguf_path="$1"
    python ./find_cached.py "$LLAMA_CACHED_MODEL" "$gguf_path"
}

resolve_model_args() {
    local gguf_path="${LLAMA_CACHED_GGUF_PATH:-model.gguf}"
    local resolved_model_path=""

    if [ -z "$LLAMA_CACHED_MODEL" ]; then
        echo "start.sh: WARNING: Caching is disabled. Please visit the inference-worker README and docs to learn more."
        return
    fi

    echo "start.sh: Caching is enabled. Finding cached model path..."
    resolved_model_path="$(resolve_cached_path "$gguf_path" || true)"

    if [ -n "$resolved_model_path" ]; then
        MODEL_ARGS="-m $resolved_model_path"
        echo "start.sh: Using cached model with arguments: $MODEL_ARGS"
        return
    fi

    if [ "$CACHE_MISS_FALLBACK" = "download" ]; then
        echo "start.sh: Cached model not found. Falling back to Hugging Face download for '$LLAMA_CACHED_MODEL'."
        echo "start.sh: Hint: To enable RunPod managed cached models, set the endpoint Model field to '$LLAMA_CACHED_MODEL' (or its Hugging Face URL)."
        if [ -n "$LLAMA_CACHED_GGUF_PATH" ]; then
            MODEL_ARGS="-hf $LLAMA_CACHED_MODEL -hff $LLAMA_CACHED_GGUF_PATH"
        else
            echo "start.sh: WARNING: LLAMA_CACHED_GGUF_PATH is empty. Falling back to default file selection from repository."
            MODEL_ARGS="-hf $LLAMA_CACHED_MODEL"
        fi
        echo "start.sh: Using fallback model arguments: $MODEL_ARGS"
        return
    fi

    echo "start.sh: Error: Could not resolve cached model path for '$LLAMA_CACHED_MODEL' with GGUF path '$gguf_path'."
    echo "start.sh: Hint: Set the endpoint Model field to '$LLAMA_CACHED_MODEL' (or its Hugging Face URL) to use RunPod managed caching."
    echo "start.sh: Error: Set LLAMA_CACHE_MISS_FALLBACK=download to enable fallback downloads."
    exit 1
}

resolve_model_args

# check if $LLAMA_SERVER_CMD_ARGS is set
if [ -z "$LLAMA_SERVER_CMD_ARGS" ]; then
    echo "start.sh: Warning: LLAMA_SERVER_CMD_ARGS is not set. Defaulting to --ctx-size 512 -ngl 999"
    LLAMA_SERVER_CMD_ARGS="--ctx-size 512 -ngl 999"
fi

# check if the substring --port is in LLAMA_SERVER_CMD_ARGS and if yes, raise an error:
if [[ "$LLAMA_SERVER_CMD_ARGS" == *"--port"* ]]; then
    echo "start.sh: Error: You must not define --port in LLAMA_SERVER_CMD_ARGS, as port 3098 is required."
    exit 1
fi

# prevent conflicting model source arguments
if [[ "$LLAMA_SERVER_CMD_ARGS" == *" -m "* ]] || [[ "$LLAMA_SERVER_CMD_ARGS" == "-m "* ]] || [[ "$LLAMA_SERVER_CMD_ARGS" == *" -hf "* ]] || [[ "$LLAMA_SERVER_CMD_ARGS" == "-hf "* ]] || [[ "$LLAMA_SERVER_CMD_ARGS" == *" -hff "* ]] || [[ "$LLAMA_SERVER_CMD_ARGS" == "-hff "* ]]; then
    echo "start.sh: Error: Do not define -m, -hf, or -hff in LLAMA_SERVER_CMD_ARGS. Configure model selection via LLAMA_CACHED_MODEL and LLAMA_CACHED_GGUF_PATH instead."
    exit 1
fi

# trap exit signals and call the cleanup function
trap cleanup SIGINT SIGTERM

# kill any existing llama-server processes
echo "start.sh: Stopping existing llama-server instances (if any)..."
{
    pkill llama-server 2>/dev/null
} || {
    echo "start.sh: No llama-server running"
}

# we have a string with all the command line arguments in the env var LLAMA_SERVER_CMD_ARGS;
# it contains a.e. "-hf modelname --ctx-size 4096 -ngl 999".

echo "start.sh: Running /app/llama-server $MODEL_ARGS $LLAMA_SERVER_CMD_ARGS --port 3098"

touch llama.server.log

# We need to pass these arguments to llama-server verbatim.
LD_LIBRARY_PATH=/app /app/llama-server $MODEL_ARGS $LLAMA_SERVER_CMD_ARGS --port 3098 2>&1 | tee llama.server.log &

LLAMA_SERVER_PID=$! # store the process ID (PID) of the background command

tries_so_far=0

check_server_is_running() {
    echo "start.sh: Checking if llama-server is done initializing..."

    if grep -q "listening" llama.server.log; then
        return 0 # success
    fi

    tries_so_far=$((tries_so_far + 1))

    if [ "$tries_so_far" -ge 120 ]; then
        echo "start.sh: Error: llama-server did not start within 60 seconds."
        exit 1
    fi

    # check if the process is still running
    if ! kill -0 "$LLAMA_SERVER_PID" 2>/dev/null; then
        echo "start.sh: Error: llama-server process has exited unexpectedly."
        exit 1
    fi

    return 1 # not ready yet
}

echo "start.sh: Waiting for llama-server to start..."

# wait for the server to start
while ! check_server_is_running; do
    # we don't want to lose too much time, so we check very frequently
    sleep 0.5
done

echo "start.sh: llama-server is up and running, delegating to the handler script."

python -u handler.py "$1"
