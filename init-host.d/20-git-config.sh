#!/usr/bin/env bash
set -euo pipefail

copy_if_missing() {
    local source_file="$1"
    local target_file="$2"
    local target_dir

    if [ ! -f "$source_file" ]; then
        return 0
    fi

    if [ -f "$target_file" ]; then
        return 0
    fi

    target_dir="$(dirname "$target_file")"
    mkdir -p "$target_dir"
    install -m 600 "$source_file" "$target_file"
}

copy_if_missing "$HOME/.gitconfig" "$SANDBOX_HOME_DIR/.gitconfig"
copy_if_missing "$HOME/.config/git/config" "$SANDBOX_HOME_DIR/.config/git/config"
