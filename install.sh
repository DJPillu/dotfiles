#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"
OS="$(uname -s)"
OMZ_DIR="$HOME/.config/oh-my-zsh"
OMZ_CUSTOM="$OMZ_DIR/custom"

# ── Output helpers ───────────────────────────────────────────────
info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
err()   { printf "\033[1;31m[err]\033[0m   %s\n" "$1" >&2; }

# ── Available modules ────────────────────────────────────────────
ALL_MODULES=(submodules packages omz stow tpm nvm)

valid_module() {
    local mod="$1"
    for m in "${ALL_MODULES[@]}"; do
        [[ "$m" == "$mod" ]] && return 0
    done
    return 1
}

# ── CLI argument parsing ─────────────────────────────────────────
INTERACTIVE=true
UPDATE_MODE=false
declare -A ENABLED
for m in "${ALL_MODULES[@]}"; do ENABLED[$m]=1; done

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  --all                 Run all modules non-interactively
  --only mod1,mod2      Run only the listed modules
  --exclude mod1,mod2   Run all modules except the listed ones
  -u, --update          Update existing installs (brew/apt upgrade,
                        git pull omz/p10k/plugins/tpm, reinstall nvm)
  -h, --help            Show this help message

Modules: submodules, packages, omz, stow, tpm, nvm
EOF
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            INTERACTIVE=false
            shift
            ;;
        --only)
            INTERACTIVE=false
            for m in "${ALL_MODULES[@]}"; do ENABLED[$m]=0; done
            IFS=',' read -ra MODS <<< "$2"
            for m in "${MODS[@]}"; do
                if valid_module "$m"; then
                    ENABLED[$m]=1
                else
                    err "Unknown module: $m"
                    exit 1
                fi
            done
            shift 2
            ;;
        --exclude)
            INTERACTIVE=false
            IFS=',' read -ra MODS <<< "$2"
            for m in "${MODS[@]}"; do
                if valid_module "$m"; then
                    ENABLED[$m]=0
                else
                    err "Unknown module: $m"
                    exit 1
                fi
            done
            shift 2
            ;;
        -u|--update)
            UPDATE_MODE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            err "Unknown option: $1"
            usage
            ;;
    esac
done

# Update an existing git checkout in place
git_pull() {
    local dir="$1"
    local label="${2:-$(basename "$dir")}"
    if [ -d "$dir/.git" ]; then
        info "Updating $label..."
        if git -C "$dir" pull --ff-only --quiet 2>/dev/null; then
            ok "$label updated"
        else
            warn "$label: could not fast-forward (skipping)"
        fi
    fi
}

# ── Interactive menu ─────────────────────────────────────────────
if $INTERACTIVE; then
    echo ""
    if $UPDATE_MODE; then
        echo "Dotfiles installer ($OS) [UPDATE MODE]"
    else
        echo "Dotfiles installer ($OS)"
    fi
    echo "========================"
    echo ""
    echo "Toggle modules by number, then press Enter to start."
    echo "  a = select all | n = deselect all"
    echo ""

    while true; do
        for i in "${!ALL_MODULES[@]}"; do
            m="${ALL_MODULES[$i]}"
            if [[ "${ENABLED[$m]}" -eq 1 ]]; then
                printf "  %d) [x] %s\n" "$((i+1))" "$m"
            else
                printf "  %d) [ ] %s\n" "$((i+1))" "$m"
            fi
        done
        echo ""
        read -rp "Choice [1-${#ALL_MODULES[@]}/a/n/Enter]: " choice
        case "$choice" in
            a) for m in "${ALL_MODULES[@]}"; do ENABLED[$m]=1; done ;;
            n) for m in "${ALL_MODULES[@]}"; do ENABLED[$m]=0; done ;;
            "") break ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#ALL_MODULES[@]} )); then
                    m="${ALL_MODULES[$((choice-1))]}"
                    ENABLED[$m]=$(( 1 - ENABLED[$m] ))
                else
                    warn "Invalid choice: $choice"
                fi
                ;;
        esac
        printf "\033[%dA\033[J" "$(( ${#ALL_MODULES[@]} + 2 ))"
    done
fi

enabled() { [[ "${ENABLED[$1]}" -eq 1 ]]; }

info "Detected OS: $OS"
echo ""

# ── Module: submodules ───────────────────────────────────────────
if enabled submodules; then
    cd "$DOTFILES"
    if $UPDATE_MODE; then
        info "Updating submodules to latest remote..."
        git submodule update --init --recursive --remote
        ok "Submodules updated"
    else
        info "Initializing submodules..."
        git submodule update --init --recursive
        ok "Submodules initialized"
    fi
fi

# ── Module: packages ─────────────────────────────────────────────
if enabled packages; then
    if [[ "$OS" == "Darwin" ]]; then
        if ! command -v brew &>/dev/null; then
            info "Installing Homebrew..."
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            eval "$(/opt/homebrew/bin/brew shellenv)"
        else
            ok "Homebrew already installed"
        fi
        if $UPDATE_MODE; then
            info "Updating Homebrew..."
            brew update
            info "Upgrading Homebrew packages..."
            brew upgrade
        fi
        info "Installing packages from Brewfile..."
        brew bundle --file="$DOTFILES/Brewfile"
        ok "Brew packages installed"
    else
        info "Updating apt package index..."
        sudo apt update
        if $UPDATE_MODE; then
            info "Upgrading apt packages..."
            sudo apt upgrade -y
        fi
        info "Installing packages via apt..."
        sudo apt install -y \
            bat eza fd-find fzf neovim ripgrep stow \
            tldr tmux wget zoxide dos2unix
        ok "apt packages installed"
    fi
fi

# ── Module: omz ──────────────────────────────────────────────────
if enabled omz; then
    if [ ! -d "$OMZ_DIR" ]; then
        info "Installing Oh My Zsh..."
        ZSH="$OMZ_DIR" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
    elif $UPDATE_MODE; then
        git_pull "$OMZ_DIR" "Oh My Zsh"
    else
        ok "Oh My Zsh already installed"
    fi

    declare -A zsh_plugins=(
        [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
        [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
        [zsh-completions]="https://github.com/zsh-users/zsh-completions.git"
    )

    for name in "${!zsh_plugins[@]}"; do
        dest="$OMZ_CUSTOM/plugins/$name"
        if [ ! -d "$dest" ]; then
            info "Cloning $name..."
            git clone --depth=1 "${zsh_plugins[$name]}" "$dest"
        elif $UPDATE_MODE; then
            git_pull "$dest" "$name"
        else
            ok "$name already installed"
        fi
    done

    P10K_DIR="$OMZ_CUSTOM/themes/powerlevel10k"
    if [ ! -d "$P10K_DIR" ]; then
        info "Cloning Powerlevel10k..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    elif $UPDATE_MODE; then
        git_pull "$P10K_DIR" "Powerlevel10k"
    else
        ok "Powerlevel10k already installed"
    fi
fi

# ── Module: stow ─────────────────────────────────────────────────
if enabled stow; then
    SHARED_PACKAGES=(zsh bash git nvim tmux ghostty alacritty ssh conda)
    if [[ "$OS" == "Darwin" ]]; then
        OS_PACKAGES=(zsh-macos bash-macos)
    else
        OS_PACKAGES=(zsh-linux bash-linux)
    fi
    ALL_STOW=("${SHARED_PACKAGES[@]}" "${OS_PACKAGES[@]}")

    info "Stowing dotfiles..."
    cd "$DOTFILES"
    for pkg in "${ALL_STOW[@]}"; do
        if [ -d "$pkg" ]; then
            stow --adopt "$pkg" 2>/dev/null || true
            stow -R "$pkg"
            ok "Stowed $pkg"
        fi
    done
fi

# ── Module: tpm ──────────────────────────────────────────────────
if enabled tpm; then
    TPM_DIR="$HOME/.config/tmux/plugins/tpm"
    if [ ! -d "$TPM_DIR" ]; then
        info "Cloning TPM..."
        git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
    elif $UPDATE_MODE; then
        git_pull "$TPM_DIR" "TPM"
        if [ -x "$TPM_DIR/bin/update_plugins" ]; then
            info "Updating tmux plugins..."
            "$TPM_DIR/bin/update_plugins" all || warn "tmux plugin update failed"
        fi
    else
        ok "TPM already installed"
    fi
fi

# ── Module: nvm ──────────────────────────────────────────────────
NVM_VERSION="v0.40.1"
if enabled nvm; then
    if [ ! -d "$HOME/.nvm" ]; then
        info "Installing NVM..."
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    elif $UPDATE_MODE; then
        info "Updating NVM to ${NVM_VERSION}..."
        curl -o- "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh" | bash
    else
        ok "NVM already installed"
    fi
fi

# ── Done ─────────────────────────────────────────────────────────
echo ""
if $UPDATE_MODE; then
    ok "Dotfiles update complete!"
else
    ok "Dotfiles installation complete!"
fi
echo ""
info "Remaining manual steps:"
echo "  1. Open tmux and press prefix + I to install tmux plugins"
echo "  2. Run 'p10k configure' if you want to reconfigure the prompt"
echo "  3. Restart your shell: exec zsh"
