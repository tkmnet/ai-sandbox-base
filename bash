#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_FILE="$SCRIPT_DIR/sandbox.json"
HOST_INIT_DIR="$SCRIPT_DIR/init-host.d"
ENGINE=""
RUN_ARGS=()
IMAGE_REGISTRY_PREFIX=""

if command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
    RUN_ARGS+=(--userns=keep-id)
    IMAGE_REGISTRY_PREFIX="localhost/"
else
    echo "docker or podman is required." >&2
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "jq is required." >&2
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Missing config: $CONFIG_FILE" >&2
    exit 1
fi

hash_path() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | awk '{print $1}'
    else
        printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
    fi
}

hash_file() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

hash_stream() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{print $1}'
    else
        shasum -a 256 | awk '{print $1}'
    fi
}

sanitize_name() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -e 's|^/||' -e 's|[^a-z0-9_.-]|-|g' -e 's|--*|-|g' -e 's|^[-.]*||' -e 's|[-.]*$||'
}

hash_image_inputs() {
    {
        printf 'config\t%s\t%s\n' "sandbox.json" "$(hash_file "$CONFIG_FILE")"

        jq -r '.image_watch[]' "$CONFIG_FILE" | while IFS= read -r relative_path; do
            case "$relative_path" in
                ""|/*|..|../*|*/..|*/../*)
                    echo "Invalid image_watch path: $relative_path" >&2
                    exit 1
                    ;;
            esac

            absolute_path="$SCRIPT_DIR/$relative_path"
            if [ -f "$absolute_path" ]; then
                printf 'file\t%s\t%s\n' "$relative_path" "$(hash_file "$absolute_path")"
            elif [ -d "$absolute_path" ]; then
                printf 'dir\t%s\n' "$relative_path"
                while IFS= read -r -d '' file_path; do
                    normalized_path="${file_path#"$SCRIPT_DIR"/}"
                    printf 'file\t%s\t%s\n' "$normalized_path" "$(hash_file "$file_path")"
                done < <(find "$absolute_path" -type f -print0 | sort -z)
            else
                printf 'missing\t%s\n' "$relative_path"
            fi
        done
    } | hash_stream
}

PATH_HASH="$(hash_path "$SCRIPT_DIR")"
SHORT_HASH="${PATH_HASH:0:12}"
SAFE_PATH="$(sanitize_name "$SCRIPT_DIR")"
SAFE_PATH="${SAFE_PATH:-workspace}"
IMAGE_HASH="$(hash_image_inputs)"
SHORT_IMAGE_HASH="${IMAGE_HASH:0:12}"

CONTAINER_NAME="${SAFE_PATH}-${SHORT_HASH}"
IMAGE_REPOSITORY_PREFIX="${SAFE_PATH}-${SHORT_HASH}"
IMAGE_REPOSITORY="${IMAGE_REPOSITORY_PREFIX}-${SHORT_IMAGE_HASH}"
IMAGE_NAME="${IMAGE_REGISTRY_PREFIX}${IMAGE_REPOSITORY}:latest"
HOME_DIR="$SCRIPT_DIR/home"
CONTAINER_HOME="/home/ai"
IMAGE_HASH_LABEL="local.sandbox.image-hash"

exists_container() {
    "$ENGINE" container inspect "$CONTAINER_NAME" >/dev/null 2>&1
}

running_container() {
    [ "$("$ENGINE" container inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null || true)" = "true" ]
}

container_image_hash() {
    "$ENGINE" container inspect -f "{{ index .Config.Labels \"$IMAGE_HASH_LABEL\" }}" "$CONTAINER_NAME" 2>/dev/null || true
}

exists_image() {
    "$ENGINE" image inspect "$IMAGE_NAME" >/dev/null 2>&1
}

run_host_init() {
    if [ ! -d "$HOST_INIT_DIR" ]; then
        return 0
    fi

    while IFS= read -r -d '' script_path; do
        SANDBOX_DIR="$SCRIPT_DIR" \
            SANDBOX_HOME_DIR="$HOME_DIR" \
            SANDBOX_CONTAINER_HOME="$CONTAINER_HOME" \
            bash "$script_path"
    done < <(find "$HOST_INIT_DIR" -maxdepth 1 -type f -name '*.sh' -print0 | sort -z)
}

cleanup_old_images() {
    "$ENGINE" images --format '{{.Repository}}:{{.Tag}}' | while IFS= read -r image_ref; do
        case "$image_ref" in
            "<none>:<none>"|"$IMAGE_NAME")
                continue
                ;;
        esac

        repository="${image_ref%:*}"
        repository_basename="${repository##*/}"
        if [ "$repository_basename" = "$IMAGE_REPOSITORY" ]; then
            continue
        fi

        case "$repository_basename" in
            "$IMAGE_REPOSITORY_PREFIX"-*)
                "$ENGINE" rmi "$image_ref" >/dev/null 2>&1 || true
                ;;
        esac
    done
}

if ! exists_image; then
    "$ENGINE" build \
        --label "$IMAGE_HASH_LABEL=$IMAGE_HASH" \
        --build-arg "UID=$(id -u)" \
        --build-arg "GID=$(id -g)" \
        -t "$IMAGE_NAME" \
        -f "$SCRIPT_DIR/Containerfile" \
        "$SCRIPT_DIR"
    cleanup_old_images
fi

if exists_container && [ "$(container_image_hash)" != "$IMAGE_HASH" ]; then
    "$ENGINE" rm -f "$CONTAINER_NAME" >/dev/null
fi

mkdir -p "$HOME_DIR"
if [ -z "$(find "$HOME_DIR" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
    "$ENGINE" run "${RUN_ARGS[@]}" --rm --entrypoint tar "$IMAGE_NAME" -C "$CONTAINER_HOME" -cf - . \
        | tar -C "$HOME_DIR" -xf -
    run_host_init
fi

if ! exists_container; then
    "$ENGINE" run \
        "${RUN_ARGS[@]}" \
        -d \
        --name "$CONTAINER_NAME" \
        --hostname "$CONTAINER_NAME" \
        --workdir "$CONTAINER_HOME" \
        --label "$IMAGE_HASH_LABEL=$IMAGE_HASH" \
        --volume "$HOME_DIR:$CONTAINER_HOME" \
        "$IMAGE_NAME" \
        bash -lc 'trap "exit 0" TERM INT; while :; do sleep 86400 & wait "$!"; done' >/dev/null
elif ! running_container; then
    "$ENGINE" start "$CONTAINER_NAME" >/dev/null
fi

if [ -t 0 ] && [ -t 1 ]; then
    exec "$ENGINE" exec -it "$CONTAINER_NAME" bash
fi

echo "Container is running: $CONTAINER_NAME"
