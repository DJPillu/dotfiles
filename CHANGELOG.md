# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

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
