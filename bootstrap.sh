#!/usr/bin/env bash
# Zero-prerequisite bootstrap for a fresh macOS or WSL/Ubuntu machine.
#
#   curl -fsSL https://raw.githubusercontent.com/DJPillu/dotfiles/main/bootstrap.sh | bash
#   curl -fsSL .../bootstrap.sh | bash -s -- --only stow,doctor     # pass installer flags
#
# Installs git/curl (and Xcode CLT + Homebrew on macOS), clones the repo over
# HTTPS into ~/.dotfiles, initialises submodules and hands off to
# ./install.sh --all. Safe to re-run: an existing checkout is fast-forwarded.
#
# Everything lives inside main() so bash parses the whole file before running
# anything (a truncated download can never execute half a script).
set -euo pipefail

main() {
    local DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
    local REPO_HTTPS="${DOTFILES_REPO:-https://github.com/DJPillu/dotfiles.git}"
    local REPO_SSH="git@github.com:DJPillu/dotfiles.git"
    local BRANCH="${DOTFILES_BRANCH:-main}"
    local -a INSTALL_ARGS=("$@")
    [[ ${#INSTALL_ARGS[@]} -eq 0 ]] && INSTALL_ARGS=(--all)

    info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
    ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
    warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
    err()   { printf "\033[1;31m[err]\033[0m   %s\n" "$1" >&2; }

    # Children must never read from our stdin: under `curl | bash` that is the
    # script itself. Use the terminal when there is one, /dev/null otherwise.
    local TTY_IN=/dev/null
    { : </dev/tty; } 2>/dev/null && TTY_IN=/dev/tty

    local OS IS_MAC=false IS_LINUX=false
    OS="$(uname -s)"
    case "$OS" in
        Darwin) IS_MAC=true ;;
        Linux)  IS_LINUX=true ;;
        *) err "Unsupported OS: $OS"; exit 1 ;;
    esac

    # ── sudo keep-alive (one password prompt for the whole run) ──
    if $IS_LINUX && command -v sudo &>/dev/null && [[ $EUID -ne 0 ]]; then
        info "Requesting sudo up front (apt needs it)..."
        sudo -v <"$TTY_IN"
        ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) &
        local SUDO_KEEPALIVE_PID=$!
        # shellcheck disable=SC2064
        trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null || true" EXIT
    fi
    local SUDO=""
    $IS_LINUX && [[ $EUID -ne 0 ]] && SUDO="sudo"

    # ── Prerequisites: git + curl ────────────────────────────────
    if $IS_MAC; then
        if ! xcode-select -p &>/dev/null; then
            info "Installing Xcode Command Line Tools (a dialog will appear)..."
            xcode-select --install 2>/dev/null || true
            until xcode-select -p &>/dev/null; do sleep 10; done
            ok "Xcode Command Line Tools installed"
        fi
        if ! command -v brew &>/dev/null && [[ ! -x /opt/homebrew/bin/brew && ! -x /usr/local/bin/brew ]]; then
            info "Installing Homebrew..."
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" <"$TTY_IN"
        fi
        if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
    else
        if [[ ! -r /etc/os-release ]] || ! grep -qiE 'debian|ubuntu' /etc/os-release; then
            err "Only Debian/Ubuntu (incl. WSL) is supported on Linux."
            exit 1
        fi
        if ! command -v git &>/dev/null || ! command -v curl &>/dev/null; then
            info "Installing git and curl..."
            $SUDO apt-get update -qq
            $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git curl ca-certificates
        fi
    fi
    ok "git and curl available"

    # ── Clone or update ──────────────────────────────────────────
    if [[ -d "$DOTFILES/.git" ]]; then
        info "Existing checkout at $DOTFILES; fast-forwarding..."
        git -C "$DOTFILES" fetch --quiet origin "$BRANCH" || warn "fetch failed; continuing offline"
        if ! git -C "$DOTFILES" pull --ff-only --quiet origin "$BRANCH" 2>/dev/null; then
            warn "Could not fast-forward (local changes?). Continuing with current checkout."
        fi
    else
        if [[ -e "$DOTFILES" ]]; then
            err "$DOTFILES exists but is not a git checkout. Move it aside and re-run."
            exit 1
        fi
        info "Cloning $REPO_HTTPS -> $DOTFILES"
        git clone --branch "$BRANCH" --recurse-submodules "$REPO_HTTPS" "$DOTFILES"
    fi
    git -C "$DOTFILES" submodule update --init --recursive --quiet
    ok "Repository ready"

    # ── Hand off to the installer ────────────────────────────────
    cd "$DOTFILES"
    chmod +x ./install.sh
    info "Running ./install.sh ${INSTALL_ARGS[*]}"
    DOTFILES="$DOTFILES" ./install.sh "${INSTALL_ARGS[@]}" <"$TTY_IN"

    # ── Post: optionally switch to SSH remote ────────────────────
    if [[ -f "$HOME/.ssh/id_ed25519" || -f "$HOME/.ssh/id_rsa" ]] \
       && [[ "$(git -C "$DOTFILES" remote get-url origin)" == "$REPO_HTTPS" ]]; then
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
            git -C "$DOTFILES" remote set-url origin "$REPO_SSH"
            ok "Switched origin to SSH ($REPO_SSH)"
        else
            info "SSH key present but not authorised on GitHub yet. To switch later:"
            echo "    git -C $DOTFILES remote set-url origin $REPO_SSH"
        fi
    fi
}

main "$@"
