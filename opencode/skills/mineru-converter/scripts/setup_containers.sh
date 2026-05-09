#!/usr/bin/env bash
# Build + run the MinerU GPU container for the literature-review skill.
# Idempotent: skips build if image exists, skips run if container is up.
#
# Usage:
#   bash setup_containers.sh                       # build (if needed) + run
#   MINERU_REGION=china bash setup_containers.sh   # use aliyun+modelscope
#   SKIP_MINERU=1 bash setup_containers.sh         # no-op (CPU-only host)
#   MINERU_REBUILD=1 bash setup_containers.sh      # force rebuild
set -e

CONTAINER_CMD=$(command -v podman || command -v docker || true)
if [ -z "$CONTAINER_CMD" ]; then
    echo "ERROR: neither podman nor docker found in PATH" >&2
    exit 1
fi
echo "[info] container runtime: $CONTAINER_CMD"

IMAGE_TAG="${MINERU_IMAGE_TAG:-localhost/mineru-api:local}"
MINERU_VARIANT="${MINERU_VARIANT:-slim}"
DOCKERFILE_VARIANT="${MINERU_REGION:-global}"
BUILD_REF="${MINERU_GIT_REF:-master}"

# Slim variant: pipeline-only, ~6-8 GB image. No vllm/flashinfer/sglang.
# Models live on a host bind mount, downloaded lazily on first start.
write_slim_build_context() {
    local dir="$1"
    cat > "$dir/entrypoint.sh" <<'ENTRYPOINT_EOF'
#!/bin/bash
set -e
# Ensure pipeline models are downloaded AND mineru.json is generated.
# mineru-models-download is cheap when files already exist (HF cache hits)
# but always writes the correct /root/mineru.json pointing at the snapshot.
if [ ! -f /root/mineru.json ]; then
    echo "[entrypoint] initializing pipeline models + mineru.json"
    mineru-models-download -s huggingface -m pipeline
fi
export MINERU_MODEL_SOURCE=local
exec "$@"
ENTRYPOINT_EOF
    chmod +x "$dir/entrypoint.sh"

    cat > "$dir/Dockerfile" <<'DOCKERFILE'
FROM nvidia/cuda:12.4.1-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    MINERU_MODEL_SOURCE=local \
    LD_LIBRARY_PATH=/usr/local/nvidia/lib64:/usr/local/cuda/lib64

RUN apt-get update && apt-get install -y --no-install-recommends \
        python3.11 python3.11-venv python3-pip \
        fonts-noto-core fonts-noto-cjk fontconfig \
        libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 \
        ca-certificates curl \
    && update-alternatives --install /usr/bin/python python /usr/bin/python3.11 1 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1 \
    && fc-cache -fv \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# mineru[core] excludes vllm/sglang/lmdeploy. Pipeline backend only.
RUN python -m pip install --upgrade pip \
    && python -m pip install -U 'mineru[core]>=3.0.0'

# Models are NOT baked into the image. They live on a host-side bind mount
# at /root/.cache/huggingface and are downloaded lazily on first start so
# host (incl. other mineru installs) and container share one copy.
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
DOCKERFILE
}

build_image() {
    if [ "${MINERU_REBUILD:-0}" != "1" ] \
       && $CONTAINER_CMD image exists "$IMAGE_TAG" 2>/dev/null; then
        echo "[skip] image $IMAGE_TAG already built (MINERU_REBUILD=1 to force)"
        return
    fi
    BUILD_DIR=$(mktemp -d)
    trap "rm -rf $BUILD_DIR" RETURN
    if [ "$MINERU_VARIANT" = "slim" ]; then
        echo "[gen ] slim Dockerfile (pipeline-only, ~9 GB, models on bind mount)"
        write_slim_build_context "$BUILD_DIR"
    else
        URL="https://raw.githubusercontent.com/opendatalab/MinerU/$BUILD_REF/docker/$DOCKERFILE_VARIANT/Dockerfile"
        echo "[fetch] $URL  (full variant, ~35 GB)"
        if ! curl -fsSL "$URL" -o "$BUILD_DIR/Dockerfile"; then
            echo "ERROR: cannot fetch Dockerfile from $URL" >&2
            exit 1
        fi
    fi
    echo "[build] $IMAGE_TAG (slim: 5-15 min, full: 15-40 min)"
    $CONTAINER_CMD build -t "$IMAGE_TAG" "$BUILD_DIR"
}

run_container() {
    if $CONTAINER_CMD ps --format '{{.Names}}' 2>/dev/null | grep -qx 'mineru'; then
        echo "[skip] mineru already running"
        return
    fi
    $CONTAINER_CMD rm -f mineru >/dev/null 2>&1 || true
    # GPU access strategy (in order of preference):
    #   1. docker  -> --gpus all (needs nvidia-container-toolkit runtime)
    #   2. podman + CDI (/etc/cdi/nvidia.yaml from nvidia-ctk or NixOS's
    #      hardware.nvidia-container-toolkit.enable).
    #   3. raw /dev/nvidia* passthrough PLUS host driver lib bind mount.
    #      Without userspace libs (libcuda.so, libnvidia-ml.so) a bare
    #      device passthrough still fails with cuda.is_available()==False.
    #      On NixOS driver libs live at /run/opengl-driver/lib; other
    #      distros expose them in /usr/lib/x86_64-linux-gnu.
    if [ "$(basename "$CONTAINER_CMD")" = "docker" ]; then
        GPU_ARGS=(--gpus all)
    elif [ -f /etc/cdi/nvidia.yaml ] || [ -f /var/run/cdi/nvidia.yaml ]; then
        GPU_ARGS=(--device nvidia.com/gpu=all)
    else
        GPU_ARGS=()
        for dev in /dev/nvidia0 /dev/nvidiactl /dev/nvidia-uvm \
                   /dev/nvidia-uvm-tools /dev/nvidia-modeset; do
            [ -e "$dev" ] && GPU_ARGS+=(--device "$dev")
        done
        DRIVER_LIB_DIR=""
        for d in /run/opengl-driver/lib /usr/lib/x86_64-linux-gnu; do
            if [ -f "$d/libcuda.so.1" ] || [ -f "$d/libcuda.so" ]; then
                DRIVER_LIB_DIR="$d"
                break
            fi
        done
        if [ -n "$DRIVER_LIB_DIR" ]; then
            GPU_ARGS+=(-v "$DRIVER_LIB_DIR:/usr/local/nvidia/lib64:ro")
            # NixOS driver libs are symlinks into /nix/store; mount it so
            # the symlinks resolve inside the container.
            [ -d /nix/store ] && GPU_ARGS+=(-v /nix/store:/nix/store:ro)
        else
            echo "WARN: no NVIDIA driver libs found; GPU will be unavailable" >&2
        fi
        GPU_ARGS+=(-e NVIDIA_VISIBLE_DEVICES=all)
        GPU_ARGS+=(-e NVIDIA_DRIVER_CAPABILITIES=all)
    fi
    HOST_HF_CACHE="${MINERU_MODELS_DIR:-$HOME/.cache/huggingface}"
    mkdir -p "$HOST_HF_CACHE/hub"
    echo "[run ] starting mineru on :8000 (GPU: ${GPU_ARGS[*]})"
    echo "       models bind-mount: $HOST_HF_CACHE -> /root/.cache/huggingface"
    $CONTAINER_CMD run -d --name mineru --restart unless-stopped \
        "${GPU_ARGS[@]}" -p 8000:8000 \
        -v "$HOST_HF_CACHE:/root/.cache/huggingface:Z" \
        -e MINERU_MODEL_SOURCE=local \
        "$IMAGE_TAG" \
        mineru-api --host 0.0.0.0 --port 8000 >/dev/null
    # First startup preloads models: allow up to 5 minutes.
    for i in $(seq 1 300); do
        if curl -sf http://localhost:8000/docs >/dev/null 2>&1; then
            echo "[ok  ] mineru ready"
            return
        fi
        sleep 1
    done
    echo "WARN : mineru not responding after 300s; inspect with:" >&2
    echo "       $CONTAINER_CMD logs mineru" >&2
}

if [ "${SKIP_MINERU:-0}" = "1" ]; then
    echo "[skip] mineru (SKIP_MINERU=1)"
    exit 0
fi

build_image
run_container

echo
echo "Status:"
$CONTAINER_CMD ps --filter name=mineru \
    --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' || true
