# klodbox

A ready-made [dev container](https://containers.dev) for working with Claude Code: Ubuntu, Claude Code, `gh`, and a handful of tools you pick in one file. Works with Docker or Podman, in VS Code.

## Why a container

Claude Code is configured here to run with **no permission prompts** (`bypassPermissions`). That is only reasonable when something else is the boundary. In the container:

- Commands, file tools, hooks and MCP servers run inside the container, not on your machine. Only the project folder is shared with the host.
- It runs as a non-root user, and the container is cheap to throw away and rebuild.
- Everyone gets the same setup from the same files.

What it does **not** do (see [Anthropic's guidance](https://code.claude.com/docs/en/devcontainer)):

- Claude can change anything in the project folder, and that is your real folder.
- Anything reachable from inside the container can be sent out, including the Claude login in `~/.claude` and the `gh` token. There is no firewall here. **Only open repos you trust.**
- Don't mount `~/.ssh` or cloud credentials. Use `gh auth login` and short-lived tokens.

## What you get

- **Always:** Claude Code (native install, updates with `claude upgrade`), [claude-statusline](https://github.com/lukaprsina/claude-statusline), `gh`, `tmux`, `jq`, `ripgrep`, `fd`, `bat`, `build-essential`.
- **On by default** (the `TOOLS` array in `.devcontainer/install.sh`): [vite-plus](https://vite.plus) (manages Node), [opencode](https://opencode.ai), [yazi](https://yazi-rs.github.io), neovim, [flyline](https://github.com/HalFrgrd/flyline) (readline replacement), [uv](https://docs.astral.sh/uv/).
- **Off by default:** `rust` (nightly). Uncomment it in `TOOLS`.
- Claude settings from `.devcontainer/claude_settings.json`, shell setup from `.devcontainer/container.bashrc`.

## Setup

You need [VS Code](https://code.visualstudio.com) with the [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) extension, plus a container engine:

| Host | Engine | Notes |
|---|---|---|
| Windows | Docker Desktop, or docker-ce inside WSL2 | Keep the project in the WSL filesystem, not `C:\`. Open it with VS Code's WSL integration. |
| Linux | Docker, or Podman | For Podman, add `"dev.containers.dockerPath": "podman"` to your **user** settings. The extension adds `--userns=keep-id` itself. |
| macOS | Docker Desktop | Not tested. |

## Use

1. Copy `.devcontainer/` into your project (or use this repo as a template).
2. **Rename it:** set `"name"` in `.devcontainer/devcontainer.json` to your project (it ships as `klodbox`). It is the title VS Code shows.
3. In VS Code: **Dev Containers: Reopen in Container**. The first build takes a few minutes.
4. First time only, inside the container: run `claude` and sign in, then `gh auth login` (accept the git setup prompt). Both survive rebuilds.

## Choosing tools

Edit `TOOLS` at the top of `.devcontainer/install.sh`: one name per line, comment a line out to skip it. Each tool is an `apt_<name>` and/or `install_<name>` function, so adding one is a few lines.

- **Apply changes without rebuilding:** `bash .devcontainer/install.sh` (safe to re-run).
- **Rebuild:** **Dev Containers: Rebuild Container** after changing `devcontainer.json`.
- A failing tool is logged and skipped; the script reports the failures at the end.

## Volumes

These persist across rebuilds, so installs are mostly updates:

| Volume | Mounted at | Shared by all projects |
|---|---|---|
| `claude-code-config` | `~/.claude` | yes |
| `gh-config` | `~/.config/gh` | yes |
| `cargo-home`, `rustup-home` | `~/.cargo`, `~/.rustup` | yes |
| `shell-history-<id>` | `/commandhistory` | per project |

Start clean (use `podman` instead of `docker` if that's your engine):

```sh
docker ps -a                                  # find the container, then:
docker rm -f <container>                      # (or "Dev Containers: Rebuild Without Cache")
docker volume ls                              # see the volumes
docker volume rm claude-code-config gh-config cargo-home rustup-home
docker volume prune                           # removes ALL unused volumes
```

Removing `claude-code-config` signs you out and `gh-config` drops the `gh` login. Claude settings are re-copied from the repo on the next create.

## Gotchas

- **Installers fetch `latest`.** Nothing is pinned, so two builds on different days can differ.
- **Claude settings are overwritten.** `install.sh` copies `claude_settings.json` over `~/.claude/settings.json` on every create. Edit the repo file, not the one in the container.
- **Skills are manual.** Install them inside the container after the first build.
- **Shared volumes:** two containers running `install.sh` at once can trip over each other in `~/.cargo`.
- **Line endings:** `.gitattributes` forces LF so `install.sh` works from a Windows checkout.

## Links

- [Dev Containers in VS Code](https://code.visualstudio.com/docs/devcontainers/containers) and [containers.dev](https://containers.dev)
- [Claude Code in dev containers](https://code.claude.com/docs/en/devcontainer)
- [claude-statusline](https://github.com/lukaprsina/claude-statusline) was inspired by the `prompt-cache-control` mod in [claude-code-templates](https://github.com/davila7/claude-code-templates).
