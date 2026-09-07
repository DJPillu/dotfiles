# Dotfiles

Personal configuration files managed with [GNU Stow](https://www.gnu.org/software/stow/).
Works on **macOS** (zsh) and **WSL/Ubuntu** (bash).

See [CHANGELOG.md](CHANGELOG.md) for recent changes.

## Quick Start (new machine, one command)

```bash
curl -fsSL https://raw.githubusercontent.com/DJPillu/dotfiles/main/bootstrap.sh | bash
```

`bootstrap.sh` needs nothing pre-installed. It:

1. Installs `git`/`curl` (macOS: Xcode Command Line Tools + Homebrew; Ubuntu: apt).
2. Clones this repo over HTTPS to `~/.dotfiles` (or fast-forwards an existing checkout) and initialises submodules.
3. Runs `./install.sh --all` (one `sudo` prompt up front on Linux, then unattended).
4. Switches the git remote to SSH once an SSH key is authorised on GitHub.

Pass installer flags through, e.g. `... | bash -s -- --only stow,doctor`.

Already cloned? Just run:

```bash
cd ~/.dotfiles && ./install.sh --all
```

Both scripts are idempotent and safe to re-run at any time.

## Structure

Each top-level directory is a stow package that mirrors `$HOME`.
OS-specific shell configs use a `.d` source directory pattern.

```
.dotfiles/
├── shell/          .config/shell/common.sh (aliases, fzf, zoxide, nvm, EDITOR — shared by bash and zsh)
├── zsh/            .zshrc, .zshenv, .p10k.zsh (shared)
├── zsh-macos/      .zshrc.d/ (brew, hostname, conda, rancher, gcloud) — macOS only
├── bash/           .bashrc, .bash_profile (shared)
├── bash-linux/     .bashrc.d/ (nvim PATH, wslview, conda) — Linux/WSL only
├── git/            .gitconfig, .gitconfig-xai (shared)
├── git-macos/      .gitconfig.local (osxkeychain credential helper)
├── git-wsl/        .gitconfig.local (Git Credential Manager from Git for Windows)
├── git-linux/      .gitconfig.local (cache credential helper)
├── local/          .local/bin/ (env, tmux-copy)
├── nvim/           .config/nvim/ (LazyVim)
├── tmux/           .config/tmux/tmux.conf
├── ghostty/        .config/ghostty/ (shaders as submodule)
├── alacritty/      .config/alacritty/
├── ssh/            .ssh/config
├── conda/          .condarc
├── Brewfile        Homebrew packages, casks and fonts (macOS)
├── bootstrap.sh    Zero-prerequisite entrypoint (curl | bash)
└── install.sh      Modular installer
```

**Platform model:** macOS uses zsh (`zsh-macos` + `git-macos` stowed); WSL uses bash (`bash-linux` + `git-wsl` stowed).

## Install Script

The installer is modular — run it interactively to pick modules, or use CLI flags.

```bash
./install.sh                     # interactive toggle menu
./install.sh --all               # everything, non-interactive
./install.sh --only packages,stow
./install.sh --exclude omz,tpm
./install.sh --check             # run only the doctor
./install.sh --all --update      # upgrade brew/apt, nvim, omz, plugins, tpm, nvm
```

| Module     | Description |
|------------|-------------|
| submodules | Initialises git submodules (ghostty shaders) |
| packages   | CLI tools via Homebrew (macOS) or apt (Ubuntu). On Linux also installs the latest Neovim tarball to `/opt/nvim` (apt's neovim is too old for LazyVim) |
| extras     | Tools the shell configs assume: `rustup`, `miniforge` (`~/miniforge3`), `uv`, `duckdb`, `gh`; Nerd Fonts and Ghostty/Alacritty casks on macOS. None of these installers are allowed to edit rc files |
| omz        | Oh My Zsh, zsh-autosuggestions / syntax-highlighting / completions, Powerlevel10k |
| stow       | Symlinks all packages into `$HOME`. Existing files that would conflict are moved to `~/.dotfiles-backup/<timestamp>/` (never adopted into the repo). Uses `--no-folding` so `~/.ssh`, `~/.local/bin`, `~/.config/*` stay real directories |
| tpm        | Tmux Plugin Manager, then installs the plugins listed in `tmux.conf` |
| nvm        | Node Version Manager (latest release, no rc edits) |
| doctor     | Verifies tool paths and versions (flags `nvim` < 0.10 or the apt build shadowing `/opt`), stow symlinks, `~/.ssh` permissions, and that the repo is clean |

`doctor` runs at the end of `--all` and exits non-zero on problems.

## OS-Specific Config (.d Pattern)

- **Shared:** `~/.config/shell/common.sh` holds everything common to bash and zsh (eza/bat/fd/rg aliases, fzf, zoxide, nvm, `EDITOR=nvim`, PATH additions). Every tool is guarded, so a machine without it never sees errors on shell start.
- **macOS:** `.zshrc` sources `~/.zshrc.d/*.zsh` before Oh My Zsh; install stows `zsh-macos/`.
- **WSL/Linux:** `.bashrc` sources `~/.bashrc.d/*.sh` before `common.sh`; install stows `bash-linux/`. `00-linux.sh` puts `/opt/nvim/bin` first on `PATH` and sets `BROWSER=wslview` only when running under WSL.

## Windows side (WSL)

Everything inside WSL is handled by the installer. Two things live on the Windows host and must be done once, in PowerShell:

```powershell
winget install --id Microsoft.WindowsTerminal -e
winget install --id DEVCOM.JetBrainsMonoNerdFont -e     # or Microsoft.CascadiaCode for "Cascadia Mono NF"
```

Then set the terminal font to the Nerd Font so eza / p10k icons render. `doctor` reminds you of this on WSL.

## Ghostty (macOS)

Ghostty reads config from both `~/.config/ghostty/config` and
`~/Library/Application Support/com.mitchellh.ghostty/config`. On macOS,
`./install.sh` symlinks the Application Support path to the stowed dotfiles config
so a single file is the source of truth.

## Usage

**Stow a single package:**

```bash
cd ~/.dotfiles && stow --no-folding nvim
```

**Unstow (remove symlinks):**

```bash
cd ~/.dotfiles && stow -D nvim
```

**Re-stow (refresh after adding files to a package):**

```bash
cd ~/.dotfiles && ./install.sh --only stow
```

**Add a new config:**

```bash
mkdir -p ~/.dotfiles/newpkg/.config/newpkg
mv ~/.config/newpkg/config ~/.dotfiles/newpkg/.config/newpkg/
# add "newpkg" to SHARED_PACKAGES in install.sh, then:
cd ~/.dotfiles && ./install.sh --only stow
```

**Update submodules (e.g. ghostty shaders):**

```bash
cd ~/.dotfiles && ./install.sh --only submodules --update
git add ghostty/.config/ghostty/shaders && git commit -m "chore: update ghostty shaders"
```

## Development

`shellcheck` runs on every push (see `.github/workflows/ci.yml`) along with a
smoke run of `./install.sh --only stow,doctor` on Ubuntu and macOS. Locally:

```bash
shellcheck install.sh bootstrap.sh bash/.bashrc bash-linux/.bashrc.d/*.sh shell/.config/shell/common.sh
```
