# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).
Works on **macOS** and **Linux** (Debian/Ubuntu/WSL2).

## Quick Start

```bash
git clone --recurse-submodules git@github.com:DJPillu/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

The install script is idempotent — safe to re-run at any time.

## Structure

Each top-level directory is a stow package that mirrors `$HOME`.
OS-specific configs live in `*-macos/` and `*-linux/` packages using a `.d` source directory pattern.

```
.dotfiles/
├── zsh/            .zshrc, .zshenv, .p10k.zsh (shared)
├── zsh-macos/      .zshrc.d/ (brew, conda, rancher)
├── zsh-linux/      .zshrc.d/ (apt compatibility aliases)
├── bash/           .bashrc, .bash_profile (shared)
├── bash-macos/     .bashrc.d/ (brew, conda, rancher)
├── bash-linux/     .bashrc.d/ (apt compatibility aliases)
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

**Update existing installs:**

```bash
./install.sh --update            # update everything
./install.sh --update --only omz # update only OMZ + plugins + p10k
```

In update mode each module upgrades what it installed (`brew upgrade`,
`apt upgrade`, `git pull` for OMZ/plugins/p10k/tpm, re-runs the NVM
installer at the pinned version, and refreshes submodules to their
latest remote commit). Without `--update`, an existing install is left
untouched.

**Available modules:** `submodules`, `packages`, `omz`, `stow`, `tpm`, `nvm`

### What Each Module Does

| Module | Description |
|-----------|----------------------------------------------------------|
| submodules | Initializes git submodules |
| packages | Installs CLI tools via Homebrew (macOS) or apt (Linux) |
| omz | Installs Oh My Zsh, custom plugins, and Powerlevel10k |
| stow | Symlinks all config packages to `$HOME` |
| tpm | Installs Tmux Plugin Manager |
| nvm | Installs Node Version Manager |

## OS-Specific Config (.d Pattern)

Shell configs use a `.d` source directory pattern for OS-specific setup.
The shared `.zshrc` sources all files in `~/.zshrc.d/` before loading Oh My Zsh,
and the install script stows either `zsh-macos/` or `zsh-linux/` based on the detected OS.

For example, on macOS `~/.zshrc.d/00-brew.zsh` sets up Homebrew and adds the
`brew` omz plugin. On Linux, `~/.zshrc.d/50-apt-compat.zsh` aliases `fdfind`
to `fd` and `batcat` to `bat` for Debian/Ubuntu compatibility.

## Using on Multiple Machines (macOS + WSL Linux)

The repo is designed to be cloned and updated on multiple machines without
clashes:

- **Per-machine state** lives outside the repo. Oh My Zsh
  (`~/.config/oh-my-zsh`), its plugins, Powerlevel10k, TPM
  (`~/.tmux/plugins/tpm`), and NVM (`~/.nvm`) are cloned into `$HOME` —
  not into the dotfiles repo. Updating them on one machine never touches
  the other.
- **Repo content is shared.** The OS-specific bits live in separate stow
  packages (`zsh-macos/` vs `zsh-linux/`), so each machine only stows
  what's relevant to it. The shared `.zshrc` / `.bashrc` work on both.
- **Brewfile is macOS-only**; the apt package list is inline in
  `install.sh`. They're independent — adding a tool to one doesn't
  silently affect the other.

Recommended workflow on a second machine:

```bash
cd ~/.dotfiles
git pull
./install.sh --update         # pull latest plugins + upgrade packages
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

**Update submodules (e.g. ghostty shaders):**

```bash
cd ~/.dotfiles/ghostty/.config/ghostty/shaders
git pull origin main
cd ~/.dotfiles
git add ghostty/.config/ghostty/shaders
git commit -m "update ghostty shaders"
```
