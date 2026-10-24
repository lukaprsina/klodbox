# Everything that doesn't need a volume is baked in here, so rebuilds reuse cached layers.
# Layers are ordered by change frequency: apt first, toolchain next, fast-moving installers last.
# Volumes (see devcontainer.json) mount over ~/.claude, ~/.config/gh, ~/.cache/kache and
# ~/.cargo/{registry,git} only, so nothing installed below is shadowed.
FROM mcr.microsoft.com/devcontainers/base:ubuntu26.04

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
# ARG, not ENV: don't leak into the running container.
ARG DEBIAN_FRONTEND=noninteractive

# Apt repos and packages. Ubuntu's own neovim lags upstream by months; the PPA tracks master.
RUN apt-get update \
     && apt-get install -y --no-install-recommends software-properties-common ca-certificates curl gnupg \
     && add-apt-repository -y -n ppa:neovim-ppa/unstable \
     && curl -fsSL https://yazi-rs.github.io/builds/yazi-keyring.gpg -o /usr/share/keyrings/yazi-keyring.gpg \
     && echo 'deb [signed-by=/usr/share/keyrings/yazi-keyring.gpg] https://yazi-rs.github.io/builds/ stable main' \
     > /etc/apt/sources.list.d/yazi.list \
     && mkdir -p /etc/apt/keyrings \
     && curl -fsSL https://r2.kunobi.com/kache/apt/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/kache.gpg \
     && echo 'deb [signed-by=/etc/apt/keyrings/kache.gpg] https://r2.kunobi.com/kache/apt stable main' \
     > /etc/apt/sources.list.d/kache.list \
     && apt-get update \
     && apt-get install -y --no-install-recommends \
     build-essential file unzip jq tmux ripgrep fd-find bat python-is-python3 \
     neovim yazi ffmpeg 7zip poppler-utils imagemagick resvg \
     kache \
     && ln -sf /usr/bin/fdfind /usr/local/bin/fd \
     && ln -sf /usr/bin/batcat /usr/local/bin/bat \
     && rm -rf /var/lib/apt/lists/*

USER vscode
# Also on PATH for VS Code's own processes (rust-analyzer, tasks), which don't read ~/.bashrc.
ENV PATH=/home/vscode/.local/bin:/home/vscode/.cargo/bin:/home/vscode/.opencode/bin:$PATH
# Mount points for the volumes: created here, owned by vscode, so a fresh volume copies that ownership.
RUN mkdir -p ~/.claude ~/.config/gh ~/.cache/kache ~/.cargo/registry ~/.cargo/git

# Rust nightly, then kache's cargo wrapper (writes ~/.cargo/config.toml). No systemd in the container, so no login service.
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs \
     | sh -s -- -y --profile default --default-toolchain nightly -c rust-analyzer -c rust-src \
     && kache init --yes --no-service --no-shell

# cargo-binstall fetches prebuilt binaries (falls back to compiling). cargo-update gives `cargo install-update -a`.
# shpool keeps terminal sessions alive across dropped connections; its daemon autostarts, no systemd needed.
RUN curl -L --proto '=https' --tlsv1.2 -sSf https://raw.githubusercontent.com/cargo-bins/cargo-binstall/main/install-from-binstall-release.sh | bash \
     && cargo binstall --no-confirm cargo-update
RUN cargo binstall --no-confirm shpool

# Unpinned `latest`: a rebuild without cache picks up new versions.
# VP_NODE_MANAGER must be set on the bash side of the pipe, or the installer asks.
RUN curl -fsSL https://vite.plus | VP_NODE_MANAGER=yes bash
RUN curl -fsSL https://opencode.ai/v2/install | bash
RUN curl -LsSf https://astral.sh/uv/install.sh | sh
RUN bash <(curl -sSfL https://github.com/HalFrgrd/flyline/releases/latest/download/install.sh)
RUN curl -fsSL https://claude.ai/install.sh | bash
# Installs fff-mcp to ~/.local/bin; install.sh registers it with Claude.
RUN curl -fsSL https://dmtrkovalenko.dev/install-fff-mcp.sh | bash
# Installs to ~/.cargo/bin; claude_settings.json points at it.
RUN curl --proto '=https' --tlsv1.2 -LsSf \
     https://github.com/lukaprsina/claude-statusline/releases/latest/download/claude-statusline-installer.sh | sh
