#!/usr/bin/env bash
set -euo pipefail

DOTFILES="$HOME/.dotfiles"
OMZ_DIR="$HOME/.config/oh-my-zsh"
OMZ_CUSTOM="$OMZ_DIR/custom"

info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }

# ── Git submodules ────────────────────────────────────────────────
info "Initializing submodules..."
cd "$DOTFILES"
git submodule update --init --recursive
ok "Submodules initialized"

# ── Homebrew ──────────────────────────────────────────────────────
if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    ok "Homebrew already installed"
fi

# ── Brew packages ─────────────────────────────────────────────────
info "Installing Homebrew packages from Brewfile..."
brew bundle --file="$DOTFILES/Brewfile"
ok "Brew packages installed"

# ── Oh My Zsh ─────────────────────────────────────────────────────
if [ ! -d "$OMZ_DIR" ]; then
    info "Installing Oh My Zsh..."
    ZSH="$OMZ_DIR" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
else
    ok "Oh My Zsh already installed"
fi

# ── ZSH custom plugins ───────────────────────────────────────────
declare -A plugins=(
    [zsh-autosuggestions]="https://github.com/zsh-users/zsh-autosuggestions.git"
    [zsh-syntax-highlighting]="https://github.com/zsh-users/zsh-syntax-highlighting.git"
    [zsh-completions]="https://github.com/zsh-users/zsh-completions.git"
)

for name in "${!plugins[@]}"; do
    dest="$OMZ_CUSTOM/plugins/$name"
    if [ ! -d "$dest" ]; then
        info "Cloning $name..."
        git clone --depth=1 "${plugins[$name]}" "$dest"
    else
        ok "$name already installed"
    fi
done

# ── Powerlevel10k ─────────────────────────────────────────────────
P10K_DIR="$OMZ_CUSTOM/themes/powerlevel10k"
if [ ! -d "$P10K_DIR" ]; then
    info "Cloning Powerlevel10k..."
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
else
    ok "Powerlevel10k already installed"
fi

# ── Stow packages ────────────────────────────────────────────────
PACKAGES=(zsh bash git nvim tmux ghostty alacritty ssh conda)

backup_if_exists() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        warn "Backing up $target -> ${target}.bak"
        mv "$target" "${target}.bak"
    fi
}

info "Stowing dotfiles..."
cd "$DOTFILES"
for pkg in "${PACKAGES[@]}"; do
    if [ -d "$pkg" ]; then
        stow --adopt "$pkg" 2>/dev/null || true
        stow -R "$pkg"
        ok "Stowed $pkg"
    fi
done

# ── TPM (Tmux Plugin Manager) ────────────────────────────────────
TPM_DIR="$HOME/.config/tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    info "Cloning TPM..."
    git clone --depth=1 https://github.com/tmux-plugins/tpm "$TPM_DIR"
else
    ok "TPM already installed"
fi

# ── NVM ───────────────────────────────────────────────────────────
if [ ! -d "$HOME/.nvm" ]; then
    info "Installing NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash
else
    ok "NVM already installed"
fi

# ── Done ──────────────────────────────────────────────────────────
echo ""
ok "Dotfiles installation complete!"
echo ""
info "Remaining manual steps:"
echo "  1. Open tmux and press prefix + I to install tmux plugins"
echo "  2. Run 'p10k configure' if you want to reconfigure the prompt"
echo "  3. Restart your shell: exec zsh"
