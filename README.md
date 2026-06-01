# AI Sandbox Base

This repository provides a small, disposable container environment for running an AI/Codex-oriented shell.

The container itself is treated as disposable. Persistent state lives in the local `home/` directory, which is mounted as the container user's home directory.

## Requirements

- Docker or Podman
- `jq`
- `sha256sum` or `shasum`

Podman is used automatically when Docker is not available. With Podman, `bash` uses `--userns=keep-id` so files under `home/` remain owned by the host user.

## Usage

Start or enter the sandbox:

```sh
./bash
```

Stop and remove the sandbox container:

```sh
./stop
```

When run from an interactive terminal, `bash` opens a shell inside the container. When run non-interactively, it only ensures the container is running and prints the container name.

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

`bash` creates `home/` if it does not exist. On first startup, it copies the image's `/home/ai` contents into `home/`, then mounts:

```text
./home -> /home/ai
```

Codex state created inside the container, such as sessions and auth/config files, is therefore stored under:

```text
home/.codex
```

`home/` is ignored by Git.

## Extra Mounts

Additional host directories can be mounted by enabling entries in `sandbox.json`.
If `sandbox.json` does not exist, `bash` copies it from `_sandbox.json` at startup.
`sandbox.json` is ignored by Git so local mounts can be customized:

```json
{
  "mounts": [
    {
      "enabled": true,
      "source": "../shared",
      "target": "/home/ai/shared",
      "readonly": false
    }
  ]
}
```

Relative `source` paths are resolved from the repository directory. `target` paths must be under `/home/ai`. Disabled mount entries are ignored and are not validated.

At startup, `bash` prints the persistent home mount and any enabled extra mounts. If the enabled mount list changes, the existing container is recreated so the new mounts take effect.

## Host Setup

Build-time initialization scripts live in `init-guest.d/` and run inside the image build.

Host-side initialization scripts live in `init-host.d/` and run only when `home/` is first created. The default host init script copies the host Codex auth file from:

```text
$CODEX_HOME/auth.json
```

or, when `CODEX_HOME` is not set:

```text
$HOME/.codex/auth.json
```

to:

```text
home/.codex/auth.json
```

Existing auth files in `home/` are not overwritten.

The host init scripts also copy host Git identity/configuration files when present:

```text
$HOME/.gitconfig
$HOME/.config/git/config
```

to the same paths under `home/`. Existing Git config files in `home/` are not overwritten.

## Image Cache

Images are cached and reused. `bash` computes an image hash from the local `sandbox.json` and the configured watched inputs.

The default watched inputs are:

```json
{
  "image_watch": [
    "Containerfile",
    "init-guest.d",
    "init-host.d",
    "bash",
    "stop"
  ]
}
```

If any watched file or directory changes, `bash` builds a new image tag and recreates the container. Older images are left in the local image store so the container runtime can reuse build cache.

## Repository Contents

- `Containerfile`: base image and installed tools
- `init-guest.d/`: build-time setup scripts that run inside the image build
- `init-host.d/`: first-run host setup scripts for `home/`
- `_sandbox.json`: default image rebuild watch configuration copied to `sandbox.json`
- `sandbox.json`: local image rebuild watch configuration, ignored by Git
- `bash`: build/cache/start/enter workflow
- `stop`: stop and remove the disposable container
- `home/`: persistent container home, ignored by Git
