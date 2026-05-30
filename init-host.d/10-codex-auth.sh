#!/usr/bin/env bash
set -euo pipefail

HOST_CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
SOURCE_AUTH="$HOST_CODEX_HOME/auth.json"
TARGET_CODEX_HOME="$SANDBOX_HOME_DIR/.codex"
TARGET_AUTH="$TARGET_CODEX_HOME/auth.json"

if [ ! -f "$SOURCE_AUTH" ]; then
    exit 0
fi

mkdir -p "$TARGET_CODEX_HOME"
if [ ! -f "$TARGET_AUTH" ]; then
    install -m 600 "$SOURCE_AUTH" "$TARGET_AUTH"
fi
