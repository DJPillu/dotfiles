#!/usr/bin/env bash
# Dotfiles installer: macOS (zsh) and WSL/Ubuntu (bash).
# Idempotent; safe to re-run. See ./install.sh --help.
set -Eeuo pipefail

DOTFILES="${DOTFILES:-$HOME/.dotfiles}"
OMZ_DIR="$HOME/.config/oh-my-zsh"
OMZ_CUSTOM="$OMZ_DIR/custom"
BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
NVM_FALLBACK_VERSION="v0.40.3"
NVIM_OPT_LINK="/opt/nvim"
CURRENT_MODULE="startup"

# ── Output helpers ───────────────────────────────────────────────
info()  { printf "\033[1;34m[info]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[ok]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[warn]\033[0m  %s\n" "$1"; }
err()   { printf "\033[1;31m[err]\033[0m   %s\n" "$1" >&2; }
section() { printf "\n\033[1m── %s ──\033[0m\n" "$1"; CURRENT_MODULE="$1"; }

on_error() {
    local line="$1"
    err "Module '$CURRENT_MODULE' failed (install.sh line $line). Re-run with --only $CURRENT_MODULE after fixing."
}
trap 'on_error $LINENO' ERR

# ── OS detection ─────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
IS_MAC=false; IS_LINUX=false; IS_WSL=false; IS_DEBIAN=false
case "$OS" in
    Darwin) IS_MAC=true ;;
    Linux)
        IS_LINUX=true
        grep -qi microsoft /proc/version 2>/dev/null && IS_WSL=true
        if [[ -r /etc/os-release ]] && grep -qiE 'debian|ubuntu' /etc/os-release; then
            IS_DEBIAN=true
        fi
        ;;
    *) err "Unsupported OS: $OS"; exit 1 ;;
esac
if $IS_LINUX && ! $IS_DEBIAN; then
    err "Linux support is limited to Debian/Ubuntu (apt). Detected: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}")"
    exit 1
fi
os_label() {
    if $IS_MAC; then echo "macOS ($ARCH)"
    elif $IS_WSL; then echo "WSL/$(. /etc/os-release; echo "$NAME $VERSION_ID") ($ARCH)"
    else echo "$(. /etc/os-release; echo "$NAME $VERSION_ID") ($ARCH)"; fi
}

# ── Generic helpers ──────────────────────────────────────────────
have() { command -v "$1" &>/dev/null; }

SUDO=""
if $IS_LINUX && [[ $EUID -ne 0 ]]; then SUDO="sudo"; fi

require_sudo() {
    [[ -z "$SUDO" ]] && return 0
    if ! sudo -n true 2>/dev/null; then
        info "sudo is required for apt; you may be prompted for your password."
        sudo -v </dev/tty || { err "sudo authentication failed"; exit 1; }
    fi
}

# Install a missing prerequisite command via the platform package manager.
ensure_cmd() {
    local cmd="$1" pkg="${2:-$1}"
    have "$cmd" && return 0
    info "Installing prerequisite '$pkg'..."
    if $IS_MAC; then
        have brew || { err "'$cmd' missing and Homebrew not available. Run the packages module first."; exit 1; }
        brew install "$pkg"
    else
        require_sudo
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg"
    fi
}

# Update an existing git checkout in place
git_pull() {
    local dir="$1" label="${2:-$(basename "$1")}"
    if [[ -d "$dir/.git" ]]; then
        info "Updating $label..."
        if git -C "$dir" pull --ff-only --quiet 2>/dev/null; then ok "$label updated"
        else warn "$label: could not fast-forward (skipping)"; fi
    fi
}

# Latest GitHub release tag for owner/repo, with fallback (works without API token).
github_latest_tag() {
    local repo="$1" fallback="$2" url tag
    url="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest" 2>/dev/null || true)"
    tag="${url##*/}"
    if [[ -n "$tag" && "$tag" != "latest" ]]; then echo "$tag"; else echo "$fallback"; fi
}

# Resolve the physical directory of a path (portable, no readlink -f / realpath).
physical_dir() { (cd "$1" 2>/dev/null && pwd -P); }

# Physical directory containing a symlink's destination (relative links resolved).
link_dest_dir() {
    local link="$1" dest
    dest="$(readlink "$link")"
    case "$dest" in /*) ;; *) dest="$(dirname "$link")/$dest" ;; esac
    physical_dir "$(dirname "$dest")"
}

# True if a symlink points somewhere inside $DOTFILES.
link_into_repo() {
    local d
    d="$(link_dest_dir "$1" || true)"
    [[ -n "$d" && ( "$d" == "$DOTFILES" || "$d" == "$DOTFILES"/* ) ]]
}

# Compare dotted versions: returns 0 if $1 >= $2
version_ge() {
    [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" == "$2" ]]
}

# ── Available modules ────────────────────────────────────────────
ALL_MODULES=(submodules packages extras omz stow tpm nvm doctor)

valid_module() {
    local mod="$1"
    for m in "${ALL_MODULES[@]}"; do [[ "$m" == "$mod" ]] && return 0; done
    return 1
}

# ── CLI argument parsing ─────────────────────────────────────────
INTERACTIVE=true
UPDATE_MODE=false
# Enabled set kept as a space-delimited string: stock macOS bash is 3.2 and
# has no associative arrays.
ENABLED_SET=" ${ALL_MODULES[*]} "
enabled()     { [[ "$ENABLED_SET" == *" $1 "* ]]; }
enable_mod()  { enabled "$1" || ENABLED_SET="${ENABLED_SET}$1 "; }
disable_mod() { ENABLED_SET="${ENABLED_SET// $1 / }"; }
enable_all()  { ENABLED_SET=" ${ALL_MODULES[*]} "; }
disable_all() { ENABLED_SET=" "; }

usage() {
    cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Options:
  --all                 Run all modules non-interactively
  --only mod1,mod2      Run only the listed modules
  --exclude mod1,mod2   Run all modules except the listed ones
  --check               Alias for --only doctor (verify the setup)
  -u, --update          Update existing installs (brew/apt upgrade, nvim,
                        git pull omz/p10k/plugins/tpm, reinstall nvm)
  -h, --help            Show this help message

Modules:
  submodules  Initialise git submodules
  packages    CLI tools via Homebrew (macOS) or apt (Linux); Neovim tarball on Linux
  extras      rustup, miniforge, uv, duckdb, gh, fonts (macOS)
  omz         Oh My Zsh, plugins, Powerlevel10k
  stow        Symlink config packages into $HOME (conflicts backed up)
  tpm         Tmux Plugin Manager + plugins
  nvm         Node Version Manager
  doctor      Verify tools, versions and symlinks
EOF
    exit 0
}

set_only() {
    INTERACTIVE=false
    disable_all
    IFS=',' read -ra MODS <<< "$1"
    for m in "${MODS[@]}"; do
        valid_module "$m" || { err "Unknown module: $m"; exit 1; }
        enable_mod "$m"
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all) INTERACTIVE=false; shift ;;
        --only) set_only "$2"; shift 2 ;;
        --check) set_only doctor; shift ;;
        --exclude)
            INTERACTIVE=false
            IFS=',' read -ra MODS <<< "$2"
            for m in "${MODS[@]}"; do
                valid_module "$m" || { err "Unknown module: $m"; exit 1; }
                disable_mod "$m"
            done
            shift 2 ;;
        -u|--update) UPDATE_MODE=true; shift ;;
        -h|--help) usage ;;
        *) err "Unknown option: $1"; usage ;;
    esac
done

# ── Interactive menu (reads from the terminal even when piped) ───
if $INTERACTIVE; then
    if ! { exec 3</dev/tty; } 2>/dev/null; then
        warn "No terminal available; running all modules non-interactively."
        INTERACTIVE=false
    fi
fi
if $INTERACTIVE; then
    echo ""
    if $UPDATE_MODE; then echo "Dotfiles installer — $(os_label) [UPDATE MODE]"
    else echo "Dotfiles installer — $(os_label)"; fi
    echo "========================"
    echo ""
    echo "Toggle modules by number, then press Enter to start."
    echo "  a = select all | n = deselect all"
    echo ""
    while true; do
        for i in "${!ALL_MODULES[@]}"; do
            m="${ALL_MODULES[$i]}"
            if enabled "$m"; then printf "  %d) [x] %s\n" "$((i+1))" "$m"
            else printf "  %d) [ ] %s\n" "$((i+1))" "$m"; fi
        done
        echo ""
        read -rp "Choice [1-${#ALL_MODULES[@]}/a/n/Enter]: " choice <&3
        case "$choice" in
            a) enable_all ;;
            n) disable_all ;;
            "") break ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#ALL_MODULES[@]} )); then
                    m="${ALL_MODULES[$((choice-1))]}"
                    if enabled "$m"; then disable_mod "$m"; else enable_mod "$m"; fi
                else
                    warn "Invalid choice: $choice"
                fi ;;
        esac
        printf "\033[%dA\033[J" "$(( ${#ALL_MODULES[@]} + 2 ))"
    done
    exec 3<&-
fi

info "Detected: $(os_label)"
cd "$DOTFILES"

# ── Neovim (Linux): official tarball into /opt ───────────────────
nvim_tarball_name() {
    case "$ARCH" in
        x86_64)  echo "nvim-linux-x86_64" ;;
        aarch64|arm64) echo "nvim-linux-arm64" ;;
        *) return 1 ;;
    esac
}

install_nvim_linux() {
    local name latest current="" tmp
    name="$(nvim_tarball_name)" || { warn "No Neovim tarball for $ARCH; skipping"; return 0; }
    latest="$(github_latest_tag neovim/neovim "")"
    if [[ -x "$NVIM_OPT_LINK/bin/nvim" ]]; then
        current="$("$NVIM_OPT_LINK/bin/nvim" --version | head -n1 | awk '{print $2}')"
    fi
    if [[ -n "$current" ]] && ! $UPDATE_MODE; then
        ok "Neovim $current already installed at $NVIM_OPT_LINK"
    elif [[ -n "$current" && -n "$latest" && "$current" == "$latest" ]]; then
        ok "Neovim $current is already the latest"
    else
        info "Installing Neovim ${latest:-latest} ($name) to /opt..."
        tmp="$(mktemp -d)"
        curl -fsSL -o "$tmp/nvim.tar.gz" "https://github.com/neovim/neovim/releases/latest/download/$name.tar.gz"
        $SUDO rm -rf "/opt/$name"
        $SUDO tar -C /opt -xzf "$tmp/nvim.tar.gz"
        $SUDO ln -sfn "/opt/$name" "$NVIM_OPT_LINK"
        rm -rf "$tmp"
        ok "Neovim $("$NVIM_OPT_LINK/bin/nvim" --version | head -n1 | awk '{print $2}') installed"
    fi
    if have dpkg && dpkg -s neovim &>/dev/null; then
        warn "apt 'neovim' package is also installed (old). Remove it to avoid confusion: sudo apt remove neovim"
    fi
}

# ── Module: submodules ───────────────────────────────────────────
if enabled submodules; then
    section "submodules"
    if $UPDATE_MODE; then
        info "Updating submodules to latest remote..."
        git submodule update --init --recursive --remote
        ok "Submodules updated"
    else
        git submodule update --init --recursive
        ok "Submodules initialised"
    fi
fi

# ── Module: packages ─────────────────────────────────────────────
if enabled packages; then
    section "packages"
    if $IS_MAC; then
        if ! have brew; then
            info "Installing Homebrew..."
            NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        if [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [[ -x /usr/local/bin/brew ]]; then eval "$(/usr/local/bin/brew shellenv)"; fi
        ok "Homebrew available"
        if $UPDATE_MODE; then
            info "Updating Homebrew..."; brew update
            info "Upgrading Homebrew packages..."; brew upgrade
        fi
        info "Installing packages from Brewfile..."
        brew bundle --file="$DOTFILES/Brewfile" --no-upgrade
        ok "Brew packages installed"
    else
        require_sudo
        info "Updating apt package index..."
        $SUDO apt-get update -qq
        if $UPDATE_MODE; then
            info "Upgrading apt packages..."
            $SUDO apt-get upgrade -y -qq
        fi
        APT_PACKAGES=(
            bat build-essential curl dos2unix eza fd-find fzf gh git git-delta
            ripgrep stow tldr tmux unzip wget zoxide
        )
        $IS_WSL && APT_PACKAGES+=(wslu)
        info "Installing apt packages..."
        $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${APT_PACKAGES[@]}"
        ok "apt packages installed"
        install_nvim_linux
    fi
fi

# ── Module: extras ───────────────────────────────────────────────
# Tools the shell configs assume but no package manager module installs.
# None of these installers are allowed to edit rc files (stowed, tracked).
if enabled extras; then
    section "extras"
    ensure_cmd curl

    # rustup / cargo (~/.cargo/env is sourced by .bashrc/.zshenv)
    if [[ -x "$HOME/.cargo/bin/rustup" ]]; then
        if $UPDATE_MODE; then "$HOME/.cargo/bin/rustup" update; fi
        ok "rustup already installed"
    else
        info "Installing rustup (no rc edits)..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path --quiet
        ok "rustup installed"
    fi

    # miniforge -> ~/miniforge3 (path assumed by 50-conda.* .d files)
    if [[ -x "$HOME/miniforge3/bin/conda" ]]; then
        if $UPDATE_MODE; then "$HOME/miniforge3/bin/conda" update -n base -y -q conda mamba || warn "conda self-update failed"; fi
        ok "miniforge already installed"
    else
        info "Installing miniforge to ~/miniforge3 (no conda init)..."
        MF_TMP="$(mktemp -d)"
        curl -fsSL -o "$MF_TMP/miniforge.sh" "https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname)-$(uname -m).sh"
        bash "$MF_TMP/miniforge.sh" -b -p "$HOME/miniforge3"
        rm -rf "$MF_TMP"
        ok "miniforge installed"
    fi

    if $IS_MAC; then
        # uv, duckdb, gh, fonts, terminal apps come from the Brewfile (casks).
        have uv     && ok "uv available (brew)"     || warn "uv missing — run the packages module"
        have duckdb && ok "duckdb available (brew)" || warn "duckdb missing — run the packages module"
        have gh     && ok "gh available (brew)"     || warn "gh missing — run the packages module"
    else
        mkdir -p "$HOME/.local/bin"
        # uv
        if [[ -x "$HOME/.local/bin/uv" ]] && ! $UPDATE_MODE; then
            ok "uv already installed"
        else
            info "Installing uv (no rc edits)..."
            curl -LsSf https://astral.sh/uv/install.sh | env UV_NO_MODIFY_PATH=1 UV_INSTALL_DIR="$HOME/.local/bin" sh
            ok "uv installed"
        fi
        # duckdb CLI -> ~/.local/bin (direct release download; installer script edits rc files)
        if [[ -x "$HOME/.local/bin/duckdb" ]] && ! $UPDATE_MODE; then
            ok "duckdb already installed"
        else
            case "$ARCH" in
                x86_64) DDB_ARCH=amd64 ;;
                aarch64|arm64) DDB_ARCH=arm64 ;;
                *) DDB_ARCH="" ;;
            esac
            if [[ -n "$DDB_ARCH" ]]; then
                info "Installing duckdb CLI..."
                DDB_TMP="$(mktemp -d)"
                curl -fsSL -o "$DDB_TMP/duckdb.zip" "https://github.com/duckdb/duckdb/releases/latest/download/duckdb_cli-linux-$DDB_ARCH.zip"
                unzip -qo "$DDB_TMP/duckdb.zip" -d "$HOME/.local/bin"
                chmod +x "$HOME/.local/bin/duckdb"
                rm -rf "$DDB_TMP"
                ok "duckdb $("$HOME/.local/bin/duckdb" --version) installed"
            else
                warn "No duckdb CLI build for $ARCH; skipping"
            fi
        fi
        if $IS_WSL; then
            echo ""
            info "Windows-side (cannot be done from WSL) — run in PowerShell:"
            echo "    winget install --id Microsoft.WindowsTerminal -e"
            echo "    winget install --id DEVCOM.JetBrainsMonoNerdFont -e"
            echo "    winget install --id Microsoft.CascadiaCode -e      # includes 'Cascadia Mono NF'"
            echo "  then set the terminal font to a Nerd Font for icons in eza/p10k."
        fi
    fi
fi

# ── Module: omz ──────────────────────────────────────────────────
if enabled omz; then
    section "omz"
    if ! have zsh; then
        warn "zsh not installed; skipping Oh My Zsh (WSL uses bash by design)"
    else
        if [[ ! -d "$OMZ_DIR" ]]; then
            info "Installing Oh My Zsh..."
            ZSH="$OMZ_DIR" sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended --keep-zshrc
        elif $UPDATE_MODE; then
            git_pull "$OMZ_DIR" "Oh My Zsh"
        else
            ok "Oh My Zsh already installed"
        fi

        for repo in zsh-users/zsh-autosuggestions zsh-users/zsh-syntax-highlighting zsh-users/zsh-completions; do
            name="${repo##*/}"
            dest="$OMZ_CUSTOM/plugins/$name"
            if [[ ! -d "$dest" ]]; then
                info "Cloning $name..."
                git clone --depth=1 --quiet "https://github.com/$repo.git" "$dest"
            elif $UPDATE_MODE; then git_pull "$dest" "$name"
            else ok "$name already installed"; fi
        done

        P10K_DIR="$OMZ_CUSTOM/themes/powerlevel10k"
        if [[ ! -d "$P10K_DIR" ]]; then
            info "Cloning Powerlevel10k..."
            git clone --depth=1 --quiet https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
        elif $UPDATE_MODE; then git_pull "$P10K_DIR" "Powerlevel10k"
        else ok "Powerlevel10k already installed"; fi
    fi
fi

# ── Module: stow ─────────────────────────────────────────────────
# Files in $HOME that would conflict are moved to $BACKUP_DIR (never adopted
# into the repo). Packages are stowed with --no-folding so directories like
# ~/.ssh and ~/.local/bin stay real directories owned by $HOME.
stow_packages() {
    local pkgs=("$@") pkg rel target tdir pdir backed_up=0
    for pkg in "${pkgs[@]}"; do
        [[ -d "$DOTFILES/$pkg" ]] || { warn "Package '$pkg' not found; skipping"; continue; }
        while IFS= read -r rel; do
            [[ -z "$rel" ]] && continue
            git -C "$DOTFILES" check-ignore -q "$pkg/$rel" 2>/dev/null && continue
            target="$HOME/$rel"
            tdir="$(dirname "$target")"
            # Parent dir already a folded symlink into the repo -> owned by stow.
            pdir="$(physical_dir "$tdir" || true)"
            [[ -n "$pdir" && "$pdir" == "$DOTFILES"/* ]] && continue
            if [[ -L "$target" ]]; then
                # Symlink: fine if it points into the repo, otherwise back it up.
                link_into_repo "$target" && continue
                mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
                mv "$target" "$BACKUP_DIR/$rel"; backed_up=$((backed_up+1))
                warn "Backed up foreign symlink ~/$rel"
            elif [[ -e "$target" ]]; then
                mkdir -p "$BACKUP_DIR/$(dirname "$rel")"
                mv "$target" "$BACKUP_DIR/$rel"; backed_up=$((backed_up+1))
                warn "Backed up existing ~/$rel"
            fi
        done < <(cd "$DOTFILES/$pkg" && find . \( -type f -o -type l \) -not -path '*/.git/*' -not -name .git -not -name .gitignore -not -name .gitmodules | sed 's|^\./||')
        stow --dir="$DOTFILES" --target="$HOME" --no-folding -R "$pkg"
        ok "Stowed $pkg"
    done
    if (( backed_up > 0 )); then
        warn "$backed_up file(s) moved to $BACKUP_DIR"
    fi
}

if enabled stow; then
    section "stow"
    ensure_cmd stow
    ensure_cmd git

    # Directories that must be real (not folded symlinks into the repo).
    mkdir -p "$HOME/.config" "$HOME/.local/bin" "$HOME/.config/tmux" "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    SHARED_PACKAGES=(shell zsh bash git nvim tmux ghostty alacritty ssh conda local)
    if $IS_MAC; then OS_PACKAGES=(zsh-macos git-macos)
    elif $IS_WSL; then OS_PACKAGES=(bash-linux git-wsl)
    else OS_PACKAGES=(bash-linux git-linux); fi

    # Legacy: tmux plugins used to live inside the (then folded) repo dir.
    # stow ignores .gitignore, so they must be moved out *before* stowing or
    # every plugin file gets symlinked. Unstow tmux first to drop any such links.
    LEGACY_TPM="$DOTFILES/tmux/.config/tmux/plugins"
    TPM_STAGING="$HOME/.config/tmux-plugins.migrating"
    if [[ -d "$LEGACY_TPM" ]]; then
        stow --dir="$DOTFILES" --target="$HOME" -D tmux 2>/dev/null || true
        rm -rf "$TPM_STAGING"
        mv "$LEGACY_TPM" "$TPM_STAGING"
        mkdir -p "$HOME/.config/tmux"
    fi

    stow_packages "${SHARED_PACKAGES[@]}" "${OS_PACKAGES[@]}"

    if [[ -d "$TPM_STAGING" ]]; then
        if [[ -f "$HOME/.config/tmux/plugins/tpm/tpm" && ! -L "$HOME/.config/tmux/plugins/tpm/tpm" ]]; then
            rm -rf "$TPM_STAGING"      # a real plugin install already exists
        else
            rm -rf "$HOME/.config/tmux/plugins"   # only stale symlinks / empty dirs
            mv "$TPM_STAGING" "$HOME/.config/tmux/plugins"
            info "Moved tmux plugins out of the repo to ~/.config/tmux/plugins"
        fi
    fi

    # Remove dangling symlinks left behind by packages that no longer exist.
    DOTFILES_BASE="$(basename "$DOTFILES")"
    while IFS= read -r link; do
        if [[ ! -e "$link" ]] && [[ "$(readlink "$link")" == *"$DOTFILES_BASE"/* ]]; then
            rm -f "$link"
            info "Removed dangling symlink ${link/#$HOME/~}"
        fi
    done < <(
        find "$HOME" -maxdepth 1 -type l 2>/dev/null
        for d in .config .bashrc.d .zshrc.d .ssh .local/bin; do
            [[ -d "$HOME/$d" ]] && find "$HOME/$d" -maxdepth 2 -type l 2>/dev/null
        done
    )

    if $IS_MAC; then
        GHOSTTY_XDG="$HOME/.config/ghostty/config"
        GHOSTTY_APP="$HOME/Library/Application Support/com.mitchellh.ghostty"
        if [[ -f "$GHOSTTY_XDG" ]]; then
            mkdir -p "$GHOSTTY_APP"
            ln -sfn "$GHOSTTY_XDG" "$GHOSTTY_APP/config"
            ok "Linked Ghostty Application Support config to dotfiles"
        fi
    fi
fi

# ── Module: tpm ──────────────────────────────────────────────────
if enabled tpm; then
    section "tpm"
    TPM_DIR="$HOME/.config/tmux/plugins/tpm"
    if [[ ! -d "$TPM_DIR" ]]; then
        info "Cloning TPM..."
        git clone --depth=1 --quiet https://github.com/tmux-plugins/tpm "$TPM_DIR"
    elif $UPDATE_MODE; then
        git_pull "$TPM_DIR" "TPM"
    else
        ok "TPM already installed"
    fi
    if have tmux && [[ -x "$TPM_DIR/bin/install_plugins" ]]; then
        info "Installing tmux plugins..."
        "$TPM_DIR/bin/install_plugins" >/dev/null 2>&1 && ok "tmux plugins installed" || warn "tmux plugin install failed (run prefix + I inside tmux)"
        if $UPDATE_MODE && [[ -x "$TPM_DIR/bin/update_plugins" ]]; then
            "$TPM_DIR/bin/update_plugins" all >/dev/null 2>&1 && ok "tmux plugins updated" || warn "tmux plugin update failed"
        fi
    fi
fi

# ── Module: nvm ──────────────────────────────────────────────────
if enabled nvm; then
    section "nvm"
    NVM_VERSION="$(github_latest_tag nvm-sh/nvm "$NVM_FALLBACK_VERSION")"
    if [[ ! -d "$HOME/.nvm" ]] || $UPDATE_MODE; then
        info "Installing NVM ${NVM_VERSION} (no rc edits)..."
        PROFILE=/dev/null bash -c "$(curl -fsSL "https://raw.githubusercontent.com/nvm-sh/nvm/${NVM_VERSION}/install.sh")"
        ok "NVM ${NVM_VERSION} installed"
    else
        ok "NVM already installed"
    fi
fi

# ── Module: doctor ───────────────────────────────────────────────
if enabled doctor; then
    section "doctor"
    DOCTOR_FAIL=0
    dr_ok()   { printf "  \033[1;32m✔\033[0m %-14s %s\n" "$1" "$2"; }
    dr_warn() { printf "  \033[1;33m!\033[0m %-14s %s\n" "$1" "$2"; }
    dr_fail() { printf "  \033[1;31m✘\033[0m %-14s %s\n" "$1" "$2"; DOCTOR_FAIL=$((DOCTOR_FAIL+1)); }

    # Make the check see the same PATH a fresh shell would.
    if $IS_LINUX; then
        for d in "$NVIM_OPT_LINK/bin" /opt/nvim-linux-x86_64/bin; do
            [[ -d "$d" ]] && PATH="$d:$PATH" && break
        done
    fi
    PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
    $IS_MAC && [[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

    echo "Tools:"
    check_tool() {
        local cmd="$1" alt="${2:-}" path ver
        if have "$cmd"; then path="$(command -v "$cmd")"
        elif [[ -n "$alt" ]] && have "$alt"; then path="$(command -v "$alt")"
        else dr_fail "$cmd" "not found"; return; fi
        ver="$( { "$path" --version 2>/dev/null || "$path" -V 2>/dev/null || "$path" version 2>/dev/null; } | head -n3 | grep -oE '[0-9]+(\.[0-9]+)+' | head -n1 || true)"
        dr_ok "$cmd" "${ver:-?}  $path"
    }
    for t in git stow tmux fzf rg zoxide eza delta tldr gh; do check_tool "$t"; done
    check_tool bat batcat
    check_tool fd fdfind
    if have cargo; then check_tool cargo; else dr_warn "cargo" "not installed (extras module)"; fi
    if [[ -x "$HOME/miniforge3/bin/conda" ]]; then dr_ok "conda" "$("$HOME/miniforge3/bin/conda" --version 2>/dev/null | awk '{print $2}')  ~/miniforge3"; else dr_warn "conda" "~/miniforge3 missing (extras module)"; fi
    check_tool uv
    check_tool duckdb
    [[ -s "$HOME/.nvm/nvm.sh" ]] && dr_ok "nvm" "~/.nvm" || dr_warn "nvm" "not installed"

    # Neovim: must be >= 0.10 and, on Linux, not the apt build.
    if have nvim; then
        NVIM_PATH="$(command -v nvim)"
        NVIM_VER="$(nvim --version | head -n1 | awk '{print $2}' | tr -d v)"
        if ! version_ge "$NVIM_VER" "0.10.0"; then
            dr_fail "nvim" "$NVIM_VER at $NVIM_PATH (LazyVim needs >= 0.10)"
        elif $IS_LINUX && [[ "$NVIM_PATH" == /usr/bin/* ]]; then
            dr_fail "nvim" "$NVIM_VER resolves to $NVIM_PATH (apt build shadows /opt); check PATH order"
        else
            dr_ok "nvim" "$NVIM_VER  $NVIM_PATH"
        fi
        $IS_LINUX && have dpkg && dpkg -s neovim &>/dev/null && dr_warn "nvim" "apt package 'neovim' still installed: sudo apt remove neovim"
    else
        dr_fail "nvim" "not found"
    fi

    echo "Shell:"
    if $IS_MAC; then
        [[ "$SHELL" == */zsh ]] && dr_ok "login shell" "$SHELL" || dr_warn "login shell" "$SHELL (expected zsh; chsh -s /bin/zsh)"
        [[ -d "$OMZ_DIR" ]] && dr_ok "oh-my-zsh" "$OMZ_DIR" || dr_fail "oh-my-zsh" "missing"
        [[ -d "$OMZ_CUSTOM/themes/powerlevel10k" ]] && dr_ok "powerlevel10k" "installed" || dr_fail "powerlevel10k" "missing"
    else
        [[ "$SHELL" == */bash ]] && dr_ok "login shell" "$SHELL" || dr_warn "login shell" "$SHELL (WSL config targets bash)"
    fi
    if [[ -f "$HOME/.config/tmux/plugins/tpm/tpm" && ! -L "$HOME/.config/tmux/plugins/tpm/tpm" ]]; then dr_ok "tpm" "~/.config/tmux/plugins/tpm"
    elif [[ -e "$HOME/.config/tmux/plugins/tpm" ]]; then dr_fail "tpm" "plugins are symlinks into the repo; re-run the stow module"
    else dr_warn "tpm" "missing (tpm module)"; fi

    echo "Symlinks:"
    check_link() {
        local rel="$1" target="$HOME/$1"
        if [[ -L "$target" ]]; then
            if [[ -e "$target" ]] && link_into_repo "$target"; then dr_ok "~/$rel" "-> $(readlink "$target")"
            elif [[ ! -e "$target" ]]; then dr_fail "~/$rel" "dangling symlink"
            else dr_fail "~/$rel" "symlink not into dotfiles: $(readlink "$target")"; fi
        elif [[ -e "$target" ]]; then dr_fail "~/$rel" "exists but is not a symlink (stow module will back it up)"
        else dr_fail "~/$rel" "missing (stow module)"; fi
    }
    LINKS=(.gitconfig .gitconfig.local .config/shell/common.sh .config/nvim/init.lua .config/tmux/tmux.conf .ssh/config .condarc .local/bin/env)
    if $IS_MAC; then LINKS+=(.zshrc .zshenv .p10k.zsh .zshrc.d/00-brew.zsh .config/ghostty/config)
    else LINKS+=(.bashrc .bash_profile .bashrc.d/00-linux.sh); fi
    for l in "${LINKS[@]}"; do check_link "$l"; done

    echo "Permissions:"
    SSH_MODE="$(stat -c %a "$HOME/.ssh" 2>/dev/null || stat -f %Lp "$HOME/.ssh" 2>/dev/null || echo "?")"
    [[ "$SSH_MODE" == "700" ]] && dr_ok "~/.ssh" "mode $SSH_MODE" || dr_warn "~/.ssh" "mode $SSH_MODE (expected 700): chmod 700 ~/.ssh"
    for d in .ssh .local/bin .config; do
        [[ -L "$HOME/$d" ]] && dr_fail "~/$d" "is a symlink into the repo (should be a real directory)"
    done

    echo "Repo:"
    if [[ -n "$(git -C "$DOTFILES" status --porcelain --untracked-files=no)" ]]; then
        dr_warn "git status" "tracked files modified in $DOTFILES (an installer edited a stowed file?)"
    else
        dr_ok "git status" "clean"
    fi

    if $IS_WSL; then
        echo "Windows side (manual):"
        dr_warn "terminal font" "set Windows Terminal font to a Nerd Font (winget install DEVCOM.JetBrainsMonoNerdFont)"
    fi

    echo ""
    if (( DOCTOR_FAIL > 0 )); then
        err "doctor: $DOCTOR_FAIL problem(s) found"
        DOCTOR_EXIT=1
    else
        ok "doctor: all checks passed"
        DOCTOR_EXIT=0
    fi
fi

# ── Done ─────────────────────────────────────────────────────────
CURRENT_MODULE="done"
echo ""
if [[ "${DOCTOR_EXIT:-0}" -ne 0 ]]; then
    warn "Finished with doctor warnings — see above."
elif $UPDATE_MODE; then ok "Dotfiles update complete!"
else ok "Dotfiles installation complete!"; fi
if enabled stow || enabled packages; then
    echo ""
    info "Open a new terminal (or: exec \$SHELL -l) to pick up the new configuration."
    $IS_MAC && echo "  Optional: run 'p10k configure' to re-tune the prompt."
fi
exit "${DOCTOR_EXIT:-0}"
