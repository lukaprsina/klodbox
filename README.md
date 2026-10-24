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

- **Always:** Claude Code (native install, updates with `claude upgrade`), [claude-statusline](https://github.com/lukaprsina/claude-statusline), `gh`, `tmux`, `jq`, `ripgrep`, `fd`, `bat`, `build-essential`, the [fff](https://github.com/dmtrKovalenko/fff) MCP server (file search) and the Exa plugin (web search).
- **Also installed** (in `.devcontainer/Dockerfile`): [shpool](https://github.com/shell-pool/shpool) (via [cargo-binstall](https://github.com/cargo-bins/cargo-binstall), with `cargo-update`), [vite-plus](https://vite.plus) (manages Node), [opencode](https://opencode.ai), [yazi](https://yazi-rs.github.io), neovim, [flyline](https://github.com/HalFrgrd/flyline) (readline replacement), [uv](https://docs.astral.sh/uv/), Rust nightly and [`kache`](https://github.com/kunobi-ninja/kache) (compiler cache).
- Claude settings from `.devcontainer/claude_settings.json` and global instructions from `.devcontainer/CLAUDE.md` (tell Claude to use fff and Exa), shell setup from `.devcontainer/container.bashrc`.

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

## Surviving dropped connections

Claude Code dies when its terminal does, which happens when Remote-SSH drops. Run it inside a [shpool](https://github.com/shell-pool/shpool) session instead:

```sh
c           # alias for: shpool attach -f claude
claude
```

After a drop, open a terminal and run `c` again; the session and the running agent are still there. Detach with `Ctrl-Space Ctrl-q`. Closing the VS Code window still stops the container (and the session with it); only a dropped connection is survived.
## Choosing tools

Tools are `RUN` lines in `.devcontainer/Dockerfile`: delete a line to skip a tool, add one to install another. Apt packages go in the big `apt-get install` block at the top.

- **Rebuild:** **Dev Containers: Rebuild Container** after any change to the Dockerfile or `devcontainer.json`. VS Code builds the image itself, so there is nothing else to run. Unchanged layers come from cache; use **Rebuild Without Cache** to pick up new `latest` versions.
- **Build by hand (optional):** to see build errors faster than a full rebuild, run `docker build -f .devcontainer/Dockerfile .devcontainer` (or `podman build ...`) from the host. Podman warns that `SHELL` isn't persisted in OCI format; it's harmless, and `--format docker` silences it.
- `.devcontainer/install.sh` only runs on create: volume ownership, the Claude settings seed and the shell hook. Re-run it with `bash .devcontainer/install.sh` (safe).
- Editing `container.bashrc` needs no rebuild; open a new shell.

## Volumes

Only data lives in volumes; tools are in the image. They persist across rebuilds:

| Volume | Mounted at | Shared by all projects |
|---|---|---|
| `claude-code-config` | `~/.claude` | yes |
| `gh-config` | `~/.config/gh` | yes |
| `kache-cache` | `~/.cache/kache` | yes |
| `cargo-registry`, `cargo-git` | `~/.cargo/registry`, `~/.cargo/git` | yes |
| `shell-history-<id>` | `/commandhistory` | per project |

Start clean (use `podman` instead of `docker` if that's your engine):

```sh
docker ps -a                                  # find the container, then:
docker rm -f <container>                      # (or "Dev Containers: Rebuild Without Cache")
docker volume ls                              # see the volumes
docker volume rm claude-code-config gh-config kache-cache cargo-registry cargo-git
docker volume prune                           # removes ALL unused volumes
```

Removing `claude-code-config` signs you out and `gh-config` drops the `gh` login. Claude settings and `CLAUDE.md` are re-copied from the repo on the next create.

## Gotchas

- **Installers fetch `latest`.** Nothing is pinned, and Docker caches the layers, so the versions you get depend on when each layer was last built without cache.
- **Claude settings are seeded once.** `install.sh` copies `claude_settings.json` to `~/.claude/settings.json` and `CLAUDE.md` to `~/.claude/CLAUDE.md` only if they don't exist yet. To re-seed, delete the file in the container and re-run `install.sh`. The fff MCP registration and Exa plugin install are also done there, and skipped once present.
- **Skills are manual.** Install them inside the container after the first build.
- **kache and links.** Its store is a volume and the project is a bind mount. Whether restores are links, clones or copies depends on your engine and filesystem; run `kache doctor` after a build. Sharing the store with the host would let the container write to your host's cache, so it isn't set up here.
- **Shared volumes:** two containers building at once share the cargo registry and the kache store, and can wait on each other's locks.
- **Line endings:** `.gitattributes` forces LF so `install.sh` works from a Windows checkout.

## Links

- [Dev Containers in VS Code](https://code.visualstudio.com/docs/devcontainers/containers) and [containers.dev](https://containers.dev)
- [Claude Code in dev containers](https://code.claude.com/docs/en/devcontainer)
- [claude-statusline](https://github.com/lukaprsina/claude-statusline) was inspired by the `prompt-cache-control` mod in [claude-code-templates](https://github.com/davila7/claude-code-templates).
