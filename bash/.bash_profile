[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"

# Source OS-specific config (stowed from bash-macos/ or bash-linux/)
if [[ -d "$HOME/.bashrc.d" ]]; then
    for f in "$HOME/.bashrc.d"/*.sh; do [ -f "$f" ] && . "$f"; done
fi
