# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).
Works on **macOS** (zsh) and **WSL/Linux** (bash).

See [CHANGELOG.md](CHANGELOG.md) for recent changes.

## Quick Start

```bash
git clone --recurse-submodules git@github.com:DJPillu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The install script is idempotent — safe to re-run at any time.

## Structure

Each top-level directory is a stow package that mirrors `$HOME`.
OS-specific shell configs use a `.d` source directory pattern.

```
.dotfiles/
├── zsh/            .zshrc, .zshenv, .p10k.zsh (shared)
├── zsh-macos/      .zshrc.d/ (brew, conda, rancher, gcloud) — macOS only
├── bash/           .bashrc, .bash_profile (shared)
├── bash-linux/     .bashrc.d/ (WSL, apt-compat, conda) — Linux/WSL only
├── local/          .local/bin/ (env, tmux-copy)
├── git/            .gitconfig, .gitconfig-xai
├── nvim/           .config/nvim/ (LazyVim)
├── tmux/           .config/tmux/tmux.conf
├── ghostty/        .config/ghostty/ (shaders as submodule)
├── alacritty/      .config/alacritty/
├── ssh/            .ssh/config
├── conda/          .condarc
├── Brewfile        Homebrew packages (macOS)
└── install.sh      Bootstrap script
```

**Platform model:** macOS uses zsh (`zsh-macos` stowed); WSL uses bash (`bash-linux` stowed).

## Install Script

The installer is modular — run it interactively to pick modules, or use CLI flags.

**Interactive mode** (default):

```bash
./install.sh
```

Displays a toggle menu where you select which modules to install.

**Run everything non-interactively:**

```bash
./install.sh --all
```

**Run only specific modules:**

```bash
./install.sh --only packages,stow
```

**Exclude specific modules:**

```bash
./install.sh --exclude packages,tpm
```

**Available modules:** `submodules`, `packages`, `omz`, `stow`, `tpm`, `nvm`

### What Each Module Does

| Module | Description |
|-----------|----------------------------------------------------------|
| submodules | Initializes git submodules |
| packages | Installs CLI tools via Homebrew (macOS) or apt (Linux/WSL) |
| omz | Installs Oh My Zsh, custom plugins, and Powerlevel10k |
| stow | Symlinks all config packages to `$HOME` |
| tpm | Installs Tmux Plugin Manager |
| nvm | Installs Node Version Manager |

## OS-Specific Config (.d Pattern)

Shell configs use a `.d` source directory pattern for OS-specific setup.

- **macOS:** shared `.zshrc` sources `~/.zshrc.d/*.zsh` before Oh My Zsh; install stows `zsh-macos/`.
- **WSL/Linux:** shared `.bashrc` sources `~/.bashrc.d/*.sh` at the end; install stows `bash-linux/`.

For example, on macOS `~/.zshrc.d/00-brew.zsh` sets up Homebrew and adds the
`brew` omz plugin. On WSL, `~/.bashrc.d/50-apt-compat.sh` aliases `fdfind`
to `fd` and `batcat` to `bat` for Debian/Ubuntu compatibility.

## Ghostty (macOS)

Ghostty reads config from both `~/.config/ghostty/config` and
`~/Library/Application Support/com.mitchellh.ghostty/config`. On macOS,
`./install.sh` symlinks the Application Support path to the stowed dotfiles config
so a single file is the source of truth.

## Usage

**Stow a single package:**

```bash
cd ~/.dotfiles && stow nvim
```

**Unstow (remove symlinks):**

```bash
cd ~/.dotfiles && stow -D nvim
```

**Re-stow (refresh after changes):**

```bash
cd ~/.dotfiles && stow -R nvim
```

**Add a new config:**

```bash
mkdir -p ~/.dotfiles/newpkg/.config/newpkg
mv ~/.config/newpkg/config ~/.dotfiles/newpkg/.config/newpkg/
cd ~/.dotfiles && stow newpkg
```

**Update submodules (e.g. ghostty shaders):**

```bash
cd ~/.dotfiles/ghostty/.config/ghostty/shaders
git pull origin main
cd ~/.dotfiles
git add ghostty/.config/ghostty/shaders
git commit -m "update ghostty shaders"
```
