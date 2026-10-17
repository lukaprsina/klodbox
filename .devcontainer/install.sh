#!/usr/bin/env bash
# Usage: bash .devcontainer/install.sh
# Runs on container creation (postCreateCommand). Re-running is safe.
# Tools are installed in the Dockerfile; this only does what needs the live volumes and workspace.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n==> %s\n' "$*"; }

log "Volume ownership"
mkdir -p ~/.claude ~/.config/gh ~/.cache/kache ~/.cargo/registry ~/.cargo/git
sudo mkdir -p /commandhistory
# Top level only: volume roots can mount root-owned (Podman, or a volume made before the image had the dir); -R would walk the whole cargo registry on every rebuild.
sudo chown "$(id -u):$(id -g)" ~/.claude ~/.config/gh ~/.cache/kache ~/.cargo/registry ~/.cargo/git /commandhistory
touch /commandhistory/.bash_history

log "Claude Code settings"
# Seed only: ~/.claude is a volume, and Claude Code creates settings.json on the first change in /config.
# Overwriting it on every create would wipe plugins and settings added since.
[ -f ~/.claude/settings.json ] || cp "$DIR/claude_settings.json" ~/.claude/settings.json

log "Shell config"
# Appended after the tools' own ~/.bashrc lines (flyline etc.). Kept out of the image so editing container.bashrc needs no rebuild.
grep -qF 'container.bashrc' ~/.bashrc 2>/dev/null \
    || echo "[ -f \"$DIR/container.bashrc\" ] && . \"$DIR/container.bashrc\"" >> ~/.bashrc

log "Done"
