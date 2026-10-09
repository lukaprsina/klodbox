# Sourced from ~/.bashrc by .devcontainer/install.sh. Container-only; the host bashrc is not used.

if command -v nvim >/dev/null; then export EDITOR=nvim; else export EDITOR=vi; fi
alias r='exec bash'

# Shell history lives in a volume so it survives rebuilds.
export HISTFILE=/commandhistory/.bash_history
export PROMPT_COMMAND='history -a'

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/.opencode/bin:$PATH"

# yazi: cd into the directory you quit in
command -v yazi >/dev/null && function y() {
    local tmp cwd
    tmp="$(mktemp -t "yazi-cwd.XXXXXX")"
    command yazi "$@" --cwd-file="$tmp"
    IFS= read -r -d '' cwd < "$tmp"
    [ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd" || builtin true
    command rm -f -- "$tmp"
}
