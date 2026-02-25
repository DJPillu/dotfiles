# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).

## Quick Start

```bash
git clone git@github.com:DJPillu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The install script is idempotent — safe to re-run at any time.

## Structure

Each top-level directory is a stow package that mirrors `$HOME`:

```
.dotfiles/
├── zsh/          .zshrc, .zshenv, .p10k.zsh
├── bash/         .bashrc, .bash_profile
├── git/          .gitconfig, .gitconfig-xai
├── nvim/         .config/nvim/ (LazyVim)
├── tmux/         .config/tmux/tmux.conf
├── ghostty/      .config/ghostty/
├── alacritty/    .config/alacritty/
├── ssh/          .ssh/config
├── conda/        .condarc
├── Brewfile      Homebrew packages
└── install.sh    Bootstrap script
```

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

## What the Install Script Does

1. Installs Homebrew (if missing)
2. Installs all packages from `Brewfile`
3. Installs Oh My Zsh, custom plugins, and Powerlevel10k
4. Stows all config packages
5. Installs TPM (Tmux Plugin Manager) and NVM
