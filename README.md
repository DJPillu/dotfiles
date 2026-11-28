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
├── git-windows/    .gitconfig.local (Windows host: CRLF, pager fallback) — copied by the windows module, not stowed
├── systemd-linux/  .config/systemd/user/dotfiles-sync.{service,timer} — Linux/WSL only
├── local/          .local/bin/ (env, tmux-copy, dotfiles-sync)
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

**Platform model:** macOS uses zsh (`zsh-macos` + `git-macos` stowed); WSL uses bash (`bash-linux` + `git-wsl` stowed). From WSL, the `windows` module also keeps the Windows host's git config in sync (see [Windows side](#windows-side-wsl)).

## Install Script

The installer is modular — run it interactively to pick modules, or use CLI flags.

```bash
./install.sh                     # interactive toggle menu
./install.sh --all               # everything, non-interactive
./install.sh --only packages,stow
./install.sh --exclude omz,tpm
./install.sh --check             # run only the doctor
./install.sh --check-urls        # check every download source still resolves
./install.sh --only windows      # WSL: re-sync the Windows git config
./install.sh --all --update      # upgrade brew/apt, nvim, omz, plugins, tpm, nvm
```

| Module     | Description |
|------------|-------------|
| submodules | Initialises git submodules (ghostty shaders) |
| packages   | CLI tools via Homebrew (macOS) or apt (Ubuntu). On Linux also installs the latest Neovim tarball to `/opt/nvim` (apt's neovim is too old for LazyVim) |
| extras     | Tools the shell configs assume: `rustup`, `miniforge` (`~/miniforge3`), `uv`, `duckdb`, `gh`; Nerd Fonts and the Ghostty cask on macOS. None of these installers are allowed to edit rc files |
| omz        | Oh My Zsh, zsh-autosuggestions / syntax-highlighting / completions, Powerlevel10k |
| stow       | Symlinks all packages into `$HOME`. Existing files that would conflict are moved to `~/.dotfiles-backup/<timestamp>/` (never adopted into the repo). Uses `--no-folding` so `~/.ssh`, `~/.local/bin`, `~/.config/*` stay real directories |
| tpm        | Tmux Plugin Manager, then installs the plugins listed in `tmux.conf` |
| nvm        | Node Version Manager (latest release, no rc edits) |
| windows    | WSL only: copies the git config to the Windows host and backs up whatever it replaces (see [Windows side](#windows-side-wsl)). No-op elsewhere |
| schedule   | Runs `dotfiles-sync` daily: a systemd user timer on Linux/WSL, a launchd agent on macOS (see [Staying in sync](#staying-in-sync)) |
| doctor     | Verifies tool paths and versions (flags `nvim` < 0.10 or the apt build shadowing `/opt`), stow symlinks, `~/.ssh` permissions, and that the repo is clean. On WSL it also checks the Git Credential Manager path and that the Windows git config matches the repo |

`doctor` runs at the end of `--all` and exits non-zero on problems.

## Staying in sync

`dotfiles-sync` (in `~/.local/bin`, installed by the `schedule` module as part of `--all`) keeps each machine aligned with the repo:

- **Every day at 10:00** in the machine's time zone (WSL normally runs in UTC, so 15:30 IST), give or take 15 minutes:
  - Fast-forwards `~/.dotfiles`, which never touches local edits.
  - Re-stows, re-syncs the Windows git config (WSL), and runs `doctor`.
- **Every 7 days:** also runs `install.sh --update` for the tools that need no sudo: Oh My Zsh / Powerlevel10k / plugins, tmux plugins, nvm, rustup, conda, uv and duckdb, plus Homebrew on macOS.
- **Never:** committing, pushing, or anything that needs sudo. Uncommitted or unpushed changes, a diverged branch, waiting apt upgrades and a newer Neovim are reported instead. Ubuntu's `unattended-upgrades` still applies apt security updates on its own.

If the machine (or WSL) was off at 10:00, the run happens at the next start: systemd catches it up via `Persistent=true`, and launchd runs it after wake.

When the last run needs attention, or no run has happened for 3 days, new terminals show one line pointing at the details:

```bash
dotfiles-sync --status      # what needs you, plus the log path (~/.local/state/dotfiles/sync.log)
dotfiles-sync               # run now (also updates tools if 7+ days since the last update)
dotfiles-sync --update      # run now and update tools
```

Pause or remove the schedule:

```bash
systemctl --user disable --now dotfiles-sync.timer                 # Linux / WSL
launchctl bootout gui/$(id -u)/com.djpillu.dotfiles-sync           # macOS
```

`doctor` reports whether the schedule is active and when it last ran.

## OS-Specific Config (.d Pattern)

- **Shared:** `~/.config/shell/common.sh` holds everything common to bash and zsh (eza/bat/fd/rg aliases, fzf, zoxide, nvm, `EDITOR=nvim`, PATH additions). Every tool is guarded, so a machine without it never sees errors on shell start.
- **macOS:** `.zshrc` sources `~/.zshrc.d/*.zsh` before Oh My Zsh; install stows `zsh-macos/`.
- **WSL/Linux:** `.bashrc` sources `~/.bashrc.d/*.sh` before `common.sh`; install stows `bash-linux/`. `00-linux.sh` puts `/opt/nvim/bin` first on `PATH` and sets `BROWSER=wslview` only when running under WSL.

## Windows side (WSL)

Windows programs can't follow symlinks into the WSL filesystem, so the Windows host gets copies instead of stow links. The `windows` module (part of `--all`, a no-op outside WSL) writes these into `%USERPROFILE%`:

| Windows file | Source |
|---|---|
| `.gitconfig` | `git/.gitconfig`: shared settings and identity rules |
| `.gitconfig-xai` | `git/.gitconfig-xai`: work identity |
| `.gitconfig.local` | `git-windows/.gitconfig.local`: keeps `core.autocrlf = true`; uses `less` as pager while `delta.exe` isn't installed on Windows |

Sync is one-way: edit the repo copy, then re-run `./install.sh --only windows`. A Windows file that differs is saved to `~/.dotfiles-backup/<timestamp>/windows/` before being replaced, and `doctor` warns when the Windows copies drift.

**Git identity** is the same on every machine: personal by default, and the work identity (`~/.gitconfig-xai`) for repos under `~/xAI/` or whose remote is the teachx GitLab (`git@ssh.nova.teachx.ai:…` or `ssh://git@ssh.nova.teachx.ai/…`).

**Credentials:** Windows git uses its own `credential.helper = manager`. Inside WSL, `git-wsl/.gitconfig.local` points git at that same Git Credential Manager (`C:\Program Files\Git\ucrt64\bin\`), so HTTPS logins are shared; `doctor` fails if that path disappears after a Git for Windows update.

Not synced on purpose: the Windows `~/.ssh/config` (some hosts use keys that only exist in WSL), the PowerShell profile, Windows Terminal settings and `.wslconfig`.

The terminal font is a one-time manual step, in PowerShell:

```powershell
winget install --id Microsoft.WindowsTerminal -e
winget install --id DEVCOM.JetBrainsMonoNerdFont -e
```

Then set the Windows Terminal font to `JetBrainsMono Nerd Font` so eza / p10k icons render. `doctor` reminds you of this on WSL.

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

CI (`.github/workflows/ci.yml`) runs on every push and weekly on Mondays:

- `shellcheck`.
- A smoke run on Ubuntu and macOS: stow, shell startup, git identity routing, the `windows` module against a fake `%USERPROFILE%` (`WIN_HOME=<dir>`), the `schedule` module, and `dotfiles-sync` under `/bin/bash` (3.2 on macOS).
- `./install.sh --check-urls`, which checks every download source the modules use. The weekly run catches renamed release assets before a machine's scheduled update does.

GitHub disables scheduled workflows after 60 days without repository activity; it emails a warning first. Locally:

```bash
shellcheck install.sh bootstrap.sh bash/.bashrc bash-linux/.bashrc.d/*.sh shell/.config/shell/common.sh local/.local/bin/dotfiles-sync
```
