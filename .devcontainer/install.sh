#!/usr/bin/env bash
# Usage: bash .devcontainer/install.sh
# Runs on container creation (postCreateCommand). Re-running is safe.
# Edit TOOLS to choose what gets installed; comment a line out to skip it.
set -euo pipefail

TOOLS=(
    vite-plus
    opencode
    yazi
    neovim
    flyline
    uv
    # rust
    # kache  # Rust/C++ compiler cache; needs rust
)

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n==> %s\n' "$*"; }

# A tool defines apt_<name> (adds to APT_PKGS, may set up a repo) and/or install_<name>.
# Their bodies run with set -e disabled (they are called from `if`), so chain steps with &&.
APT_PKGS=(build-essential file unzip jq tmux ripgrep fd-find bat python-is-python3)

apt_yazi() {
    if [ ! -f /etc/apt/sources.list.d/yazi.list ]; then
        curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg | sudo tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null
        echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' \
            | sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null
    fi
    APT_PKGS+=(yazi ffmpeg 7zip poppler-utils imagemagick resvg)
}

apt_neovim() { APT_PKGS+=(neovim); }

apt_kache() {
    if [ ! -f /etc/apt/sources.list.d/kache.list ]; then
        sudo mkdir -p /etc/apt/keyrings
        curl -fsSL https://r2.kunobi.com/kache/apt/gpg.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kache.gpg
        echo 'deb [signed-by=/etc/apt/keyrings/kache.gpg] https://r2.kunobi.com/kache/apt stable main' \
            | sudo tee /etc/apt/sources.list.d/kache.list >/dev/null
    fi
    APT_PKGS+=(kache)
}

# VP_NODE_MANAGER must be set on the bash side of the pipe, or the installer asks.
install_vite-plus() { curl -fsSL https://vite.plus | VP_NODE_MANAGER=yes bash; }
install_opencode() { curl -fsSL https://opencode.ai/v2/install | bash; }
install_flyline() { bash <(curl -sSfL https://github.com/HalFrgrd/flyline/releases/latest/download/install.sh); }
install_uv() { curl -LsSf https://astral.sh/uv/install.sh | sh; }

install_rust() {
    local rustup=~/.cargo/bin/rustup
    if [ -x "$rustup" ]; then
        "$rustup" toolchain install nightly --profile default -c rust-analyzer -c rust-src \
            && "$rustup" default nightly \
            && "$rustup" update
    else
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
            | sh -s -- -y --profile default --default-toolchain nightly -c rust-analyzer -c rust-src
    fi
}

# Writes rustc-wrapper into ~/.cargo/config.toml (cargo-home volume). No systemd in the container, so no login service.
install_kache() { kache init --yes --no-service --no-shell; }

install_claude-code() { curl -fsSL https://claude.ai/install.sh | bash; }

install_claude-statusline() {
    curl --proto '=https' --tlsv1.2 -LsSf \
        https://github.com/lukaprsina/claude-statusline/releases/latest/download/claude-statusline-installer.sh | sh
}

FAILED=()
# run <label> <function>: log, run, and keep going if it fails.
run() {
    log "$1"
    "$2" || { echo "!! $1 failed" >&2; FAILED+=("$1"); }
}

for tool in "${TOOLS[@]}"; do
    if ! declare -F "apt_$tool" >/dev/null && ! declare -F "install_$tool" >/dev/null; then
        echo "Unknown tool: $tool" >&2
        exit 1
    fi
done

log "Volume ownership"
mkdir -p ~/.claude ~/.config/gh ~/.cargo ~/.rustup
sudo mkdir -p /commandhistory
sudo chown -R "$(id -u):$(id -g)" ~/.claude ~/.config/gh ~/.cargo ~/.rustup /commandhistory
touch /commandhistory/.bash_history

for tool in "${TOOLS[@]}"; do
    if declare -F "apt_$tool" >/dev/null; then
        run "apt repository: $tool" "apt_$tool"
    fi
done

log "System packages"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${APT_PKGS[@]}"
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat

for tool in "${TOOLS[@]}"; do
    if declare -F "install_$tool" >/dev/null; then
        run "$tool" "install_$tool"
    fi
done

run "claude-code" install_claude-code

log "Claude Code settings"
cp "$DIR/claude_settings.json" ~/.claude/settings.json
run "claude-statusline" install_claude-statusline

log "Shell config"
grep -qF 'container.bashrc' ~/.bashrc 2>/dev/null \
    || echo "[ -f \"$DIR/container.bashrc\" ] && . \"$DIR/container.bashrc\"" >> ~/.bashrc

if [ "${#FAILED[@]}" -gt 0 ]; then
    printf '\n!! Failed: %s\n' "${FAILED[*]}" >&2
    exit 1
fi
log "Done"
