# AI Sandbox Base

This repository provides a small, disposable container environment for running an AI/Codex-oriented shell.

The container itself is treated as disposable. Persistent state lives in the local `home/` directory, which is mounted as the container user's home directory.

## Requirements

- Docker or Podman
- `jq`
- `sha256sum` or `shasum`

Podman is used automatically when Docker is not available. With Podman, `start.sh` uses `--userns=keep-id` so files under `home/` remain owned by the host user.

## Usage

Start or enter the sandbox:

```sh
./start.sh
```

Stop and remove the sandbox container:

```sh
./stop.sh
```

When run from an interactive terminal, `start.sh` opens a shell inside the container. When run non-interactively, it only ensures the container is running and prints the container name.

## Container Identity

The container name is generated from this repository's absolute path:

```text
<sanitized-absolute-path>-<path-hash>
```

For example:

```text
home-takami-work-ai-sandbox-base-cb22c108b56a
```

This keeps the name readable while avoiding collisions between directories with similar names.

## Persistent Home

`start.sh` creates `home/` if it does not exist. On first startup, it copies the image's `/home/ai` contents into `home/`, then mounts:

```text
./home -> /home/ai
```

Codex state created inside the container, such as sessions and auth/config files, is therefore stored under:

```text
home/.codex
```

`home/` is ignored by Git.

## Image Cache

Images are cached and reused. `start.sh` computes an image hash from `sandbox.json` and the configured watched inputs.

The default watched inputs are:

```json
{
  "image_watch": [
    "Containerfile",
    "init.d",
    "start.sh",
    "stop.sh"
  ]
}
```

If any watched file or directory changes, `start.sh` builds a new image tag and recreates the container. Older images are left in the local image store so the container runtime can reuse build cache.

## Repository Contents

- `Containerfile`: base image and installed tools
- `init.d/`: build-time setup scripts
- `sandbox.json`: image rebuild watch configuration
- `start.sh`: build/cache/start/enter workflow
- `stop.sh`: stop and remove the disposable container
- `home/`: persistent container home, ignored by Git
