#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
ENGINE=""

if command -v docker >/dev/null 2>&1; then
    ENGINE="docker"
elif command -v podman >/dev/null 2>&1; then
    ENGINE="podman"
else
    echo "docker or podman is required." >&2
    exit 1
fi

hash_path() {
    if command -v sha256sum >/dev/null 2>&1; then
        printf '%s' "$1" | sha256sum | awk '{print $1}'
    else
        printf '%s' "$1" | shasum -a 256 | awk '{print $1}'
    fi
}

sanitize_name() {
    printf '%s' "$1" \
        | tr '[:upper:]' '[:lower:]' \
        | sed -e 's|^/||' -e 's|[^a-z0-9_.-]|-|g' -e 's|--*|-|g' -e 's|^[-.]*||' -e 's|[-.]*$||'
}

PATH_HASH="$(hash_path "$SCRIPT_DIR")"
SHORT_HASH="${PATH_HASH:0:12}"
SAFE_PATH="$(sanitize_name "$SCRIPT_DIR")"
SAFE_PATH="${SAFE_PATH:-workspace}"

CONTAINER_NAME="${SAFE_PATH}-${SHORT_HASH}"

if "$ENGINE" container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then
    "$ENGINE" rm -f "$CONTAINER_NAME" >/dev/null
    echo "Removed container: $CONTAINER_NAME"
else
    echo "Container does not exist: $CONTAINER_NAME"
fi
