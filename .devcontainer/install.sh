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

# A tool defines any of these (hyphens in <name> become underscores for PKGS_):
#   repo_<name>      set up an apt repository, idempotent. Skips the tool's PKGS_ if it fails.
#   PKGS_<name>      array of apt packages to install.
#   install_<name>   non-apt install, runs after apt.
# repo_ and install_ bodies run through `run`'s `||`, so set -e is off inside them: chain steps with && and return 1 on failure.
BASE_PKGS=(build-essential file unzip jq tmux ripgrep fd-find bat python-is-python3)

repo_yazi() {
    if [ ! -f /etc/apt/sources.list.d/yazi.list ]; then
        curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg | sudo tee /usr/share/keyrings/yazi-keyring.gpg >/dev/null \
            && echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' \
                | sudo tee /etc/apt/sources.list.d/yazi.list >/dev/null \
            || return 1
    fi
}
PKGS_yazi=(yazi ffmpeg 7zip poppler-utils imagemagick resvg)

# Ubuntu's own neovim lags upstream by months; the PPA tracks master.
repo_neovim() { sudo add-apt-repository -y -n ppa:neovim-ppa/unstable; }
PKGS_neovim=(neovim)

repo_kache() {
    if [ ! -f /etc/apt/sources.list.d/kache.list ]; then
        sudo mkdir -p /etc/apt/keyrings \
            && curl -fsSL https://r2.kunobi.com/kache/apt/gpg.key | sudo gpg --dearmor --yes -o /etc/apt/keyrings/kache.gpg \
            && echo 'deb [signed-by=/etc/apt/keyrings/kache.gpg] https://r2.kunobi.com/kache/apt stable main' \
                | sudo tee /etc/apt/sources.list.d/kache.list >/dev/null \
            || return 1
    fi
}
PKGS_kache=(kache)
# Writes rustc-wrapper into ~/.cargo/config.toml (cargo-home volume). No systemd in the container, so no login service.
install_kache() { kache init --yes --no-service --no-shell; }

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

install_claude-code() { curl -fsSL https://claude.ai/install.sh | bash; }

install_claude-statusline() {
    curl --proto '=https' --tlsv1.2 -LsSf \
        https://github.com/lukaprsina/claude-statusline/releases/latest/download/claude-statusline-installer.sh | sh
}

FAILED=()
# run <label> <function>: log, run, and keep going if it fails. Returns the function's status.
run() {
    log "$1"
    "$2" || { echo "!! $1 failed" >&2; FAILED+=("$1"); return 1; }
}

pkgs_var() { printf 'PKGS_%s' "${1//-/_}"; }

for tool in "${TOOLS[@]}"; do
    if ! declare -F "repo_$tool" >/dev/null \
        && ! declare -F "install_$tool" >/dev/null \
        && ! declare -p "$(pkgs_var "$tool")" >/dev/null 2>&1; then
        echo "Unknown tool: $tool" >&2
        exit 1
    fi
done

log "Volume ownership"
mkdir -p ~/.claude ~/.config/gh ~/.cargo ~/.rustup ~/.local ~/.opencode
sudo mkdir -p /commandhistory
# Top level only: volume roots mount root-owned; -R would walk the whole cargo/rustup trees on every rebuild.
sudo chown "$(id -u):$(id -g)" ~/.claude ~/.config/gh ~/.cargo ~/.rustup ~/.local ~/.opencode /commandhistory
touch /commandhistory/.bash_history

export DEBIAN_FRONTEND=noninteractive
log "Apt bootstrap"
# add-apt-repository (PPAs) and gpg (keyrings) are needed before any repo_ step.
sudo apt-get update
sudo apt-get install -y --no-install-recommends software-properties-common ca-certificates curl gnupg

APT_PKGS=("${BASE_PKGS[@]}")
for tool in "${TOOLS[@]}"; do
    if declare -F "repo_$tool" >/dev/null; then
        run "apt repository: $tool" "repo_$tool" || continue
    fi
    if declare -p "$(pkgs_var "$tool")" >/dev/null 2>&1; then
        declare -n tool_pkgs="$(pkgs_var "$tool")"
        APT_PKGS+=("${tool_pkgs[@]}")
        unset -n tool_pkgs
    fi
done

log "System packages"
sudo apt-get update
sudo apt-get install -y --no-install-recommends "${APT_PKGS[@]}"
sudo ln -sf /usr/bin/fdfind /usr/local/bin/fd
sudo ln -sf /usr/bin/batcat /usr/local/bin/bat

for tool in "${TOOLS[@]}"; do
    if declare -F "install_$tool" >/dev/null; then
        run "$tool" "install_$tool" || true
    fi
done

run "claude-code" install_claude-code || true

log "Claude Code settings"
# Seed only: ~/.claude is a volume, and Claude Code creates settings.json on the first change in /config.
# Overwriting it on every create would wipe plugins and settings added since.
[ -f ~/.claude/settings.json ] || cp "$DIR/claude_settings.json" ~/.claude/settings.json
run "claude-statusline" install_claude-statusline || true

log "Shell config"
grep -qF 'container.bashrc' ~/.bashrc 2>/dev/null \
    || echo "[ -f \"$DIR/container.bashrc\" ] && . \"$DIR/container.bashrc\"" >> ~/.bashrc

if [ "${#FAILED[@]}" -gt 0 ]; then
    # Warn but exit 0: a nonzero postCreateCommand makes VS Code show a failed-container prompt for a mostly usable box.
    printf '\n!! Failed: %s (re-run: bash .devcontainer/install.sh)\n' "${FAILED[*]}" >&2
fi
log "Done"
