# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- `ssh/.ssh/config`: `pc` host (192.168.0.23)

- `dotfiles-sync` (`local/.local/bin`): daily alignment (fast-forward the repo without touching local edits, restow, Windows git sync, `doctor`) and a weekly no-sudo tool update. Commits, pushes and sudo steps are reported, never done. Status and log go to `~/.local/state/dotfiles/`, and `--status` shows the details
- `install.sh` `schedule` module (part of `--all`): runs `dotfiles-sync` daily from a systemd user timer on Linux/WSL (`systemd-linux/` package, `Persistent=true` catch-up) or a launchd agent on macOS; `doctor` reports whether it's active and when it last ran
- `common.sh`: one-line notice in new terminals when the last sync needs attention or no sync has run for 3 days (in zsh it releases Powerlevel10k's instant prompt first, so p10k doesn't warn)
- `install.sh --check-urls`: probes every download source the modules use (all architectures), driven by the same URL helpers the modules call
- CI: weekly scheduled run, `workflow_dispatch`, a download-sources job, and smoke steps for the `schedule` module and `dotfiles-sync` (under `/bin/bash` 3.2 on macOS)

- `install.sh` `windows` module (WSL only, part of `--all`): copies `.gitconfig`, `.gitconfig-xai` and `git-windows/.gitconfig.local` to the Windows host (`%USERPROFILE%`), backing up anything it replaces to `~/.dotfiles-backup/<timestamp>/windows/`
- `git-windows/.gitconfig.local`: Windows keeps `core.autocrlf = true`; `less` replaces the delta pager while `delta.exe` isn't installed on Windows
- `doctor` on WSL: fails when the Git Credential Manager path in `git-wsl/.gitconfig.local` doesn't exist, warns when the Windows git config drifts from the repo
- `.gitconfig`: the work identity also applies to any repo whose remote is the teachx GitLab, not only to repos under `~/xAI/`
- CI: git identity routing check and a `windows` module run against a fake `%USERPROFILE%` (`WIN_HOME`)

- `bootstrap.sh`: zero-prerequisite one-liner (`curl ... | bash`) that installs git/curl (Xcode CLT + Homebrew on macOS), clones over HTTPS, and runs `install.sh --all` with a single up-front `sudo` prompt
- `install.sh` `extras` module: rustup, miniforge (`~/miniforge3`), uv, duckdb, gh; Nerd Fonts and Ghostty/Alacritty casks on macOS; winget hints for the Windows side on WSL
- `install.sh` `doctor` module / `--check`: verifies tool paths and versions (incl. `nvim` >= 0.10 and not the apt build), stow symlinks, `~/.ssh` permissions, tmux plugins location, and repo cleanliness
- `install.sh`: Linux installs the latest Neovim release tarball to `/opt/nvim-linux-<arch>` with an `/opt/nvim` symlink (arch-aware)
- `install.sh`: tmux plugins are installed automatically after TPM is cloned
- `shell/` stow package: `~/.config/shell/common.sh`, shared by bash and zsh (guarded aliases, fzf, zoxide, nvm, `EDITOR=nvim`, PATH additions)
- `git-macos/`, `git-wsl/`, `git-linux/` stow packages providing `~/.gitconfig.local` with the per-OS credential helper
- `.gitconfig`: delta, `zdiff3` conflict style, `push.autoSetupRemote`, `fetch.prune`, `rerere`
- `.shellcheckrc` and GitHub Actions CI (shellcheck + `install.sh --only stow,doctor` smoke run on Ubuntu and macOS)
- `.gitignore` guards for `ssh/.ssh/id_*`, known_hosts and untracked binaries in `local/.local/bin`
- `local/` stow package (`~/.local/bin/env`, `~/.local/bin/tmux-copy`)
- `bash-linux` `.d` files for WSL (`wslview`, nvim path, conda/mamba)
- `zsh-macos/60-gcloud.zsh` for conditional gcloud SDK loading
- `git-delta` to Brewfile; `git-delta` and `wslu` to apt install list
- Ghostty shell navigation keybinds (alt/super + arrow) restored after `keybind=clear`
- `install.sh` macOS step: symlink Application Support Ghostty config → `~/.config/ghostty/config`

### Changed

- `extras --update`: uv and duckdb are only re-downloaded when a newer release exists
- `windows` module: decides the delta pager fallback with Windows' own `where.exe` rather than WSL's `PATH`, so scheduled runs (which don't inherit the Windows `PATH`) write the same file as interactive ones
- `.gitconfig`: `~/.gitconfig.local` is included last, so per-OS files can override shared settings
- CI: `actions/checkout@v5` (Node 20 deprecation warning)
- `install.sh` stow module no longer uses `stow --adopt` (which overwrote tracked files with whatever was in `$HOME`). Conflicting files are moved to `~/.dotfiles-backup/<timestamp>/` and packages are stowed with `--no-folding`
- `install.sh`: installers may not edit rc files (`PROFILE=/dev/null` for nvm, `rustup --no-modify-path`, miniforge `-b`, `UV_NO_MODIFY_PATH`, `NONINTERACTIVE=1` Homebrew)
- `install.sh`: detects macOS / WSL / Debian explicitly, errors on unsupported distros, reads the interactive menu from `/dev/tty`, and names the failing module on error
- `install.sh`: nvm version resolved from the latest GitHub release (pinned fallback)
- apt list: dropped `neovim` (too old for LazyVim), added `gh`, `curl`, `unzip`, `build-essential`; `wslu` only on WSL
- `Brewfile`: added `gh`, `duckdb`, `uv`, `git`, casks for Ghostty, Alacritty, Cascadia Mono NF and JetBrainsMono Nerd Font
- `bash-linux/.bashrc.d/00-wsl.sh` renamed to `00-linux.sh`; `BROWSER=wslview` only under WSL; `/opt/nvim/bin` is prepended (was appended, so apt's 0.9.5 won)
- `bash/.bashrc`: history raised to 50000 with timestamps; tool aliases moved to `common.sh`; `.bashrc.d` is sourced before `common.sh`
- `zsh/.zshrc`: tool aliases/fzf/zoxide/nvm moved to `common.sh`; `z` plugin dropped (redundant with `zoxide --cmd cd`); falls back to `compinit` if Oh My Zsh is missing
- `zsh-macos/00-brew.zsh`: supports Intel (`/usr/local`) as well as Apple Silicon Homebrew
- `tmux.conf`: reload binding points at `~/.config/tmux/tmux.conf`
- tmux plugins now live in `~/.config/tmux/plugins` (real directory) instead of inside the repo; the stow module migrates an existing install
- `zsh/.zshrc`: shared cross-platform config; sources `~/.zshrc.d/` before OMZ
- `bash/.bashrc`: WSL/conda moved to `bash-linux/.bashrc.d/`
- `bash/.bash_profile`: sources `~/.bashrc` only
- `install.sh`: mac stows `zsh-macos` only; Linux stows `bash-linux` + `local`
- `ghostty/config`: restore Option/Cmd+arrow line/word navigation keybinds

### Fixed

- `zsh/.zshrc`: grok completions are put on `fpath` before `compinit`, replacing the block the grok installer appended (two `PATH` prepends, one hardcoding `/Users/rujul`, and a second `compinit -C`); `common.sh` already adds `~/.grok/bin`

- WSL git credential helper pointed at `Git/mingw64/bin/git-credential-manager.exe`, which current Git for Windows no longer ships (now `Git/ucrt64/bin/`)
- `extras` WSL hint and README suggested `winget install Microsoft.CascadiaCode`, a package ID that doesn't exist
- `extras` on Linux: duckdb 2.x publishes `duckdb-cli-linux-<arch>.tar.gz` (the old `duckdb_cli-linux-<arch>.zip` 404s); a symlink left by the official installer is replaced rather than written through
- `common.sh`: `~/.duckdb/cli/latest` is appended to `PATH` instead of prepended, so an old official-installer duckdb no longer shadows the managed one
- Shell start errors on a fresh machine: `~/.cargo/env`, `~/.local/bin/env`, conda, fzf and zoxide are all guarded
- Hardcoded `/Users/rujul/.duckdb` path in `.zshrc`
- `EDITOR` was `vim` in zsh and unset in bash; now `nvim` on both
- Ghostty on macOS ignoring dotfiles config when auto-generated Application Support template exists
- Ghostty Option/Cmd+arrow keys printing literal `C`/`D` instead of word/line navigation
- Tab title showing `user@192` when system hostname is a LAN IP (use macOS ComputerName)

### Removed

- `bash-linux/.bashrc.d/50-apt-compat.sh` (fdfind/batcat handling moved to `common.sh`)
- `bash-macos/` package (mac uses zsh)
- `zsh-linux/` package (WSL uses bash)
- Hardcoded `/Users/rujul` and `/home/rujul` paths from shared shell configs
