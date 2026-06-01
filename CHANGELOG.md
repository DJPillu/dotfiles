# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/).

## [Unreleased]

### Added

- `local/` stow package (`~/.local/bin/env`, `~/.local/bin/tmux-copy`)
- `bash-linux` `.d` files for WSL (`wslview`, nvim path, conda/mamba)
- `zsh-macos/60-gcloud.zsh` for conditional gcloud SDK loading
- `git-delta` to Brewfile; `git-delta` and `wslu` to apt install list
- Ghostty shell navigation keybinds (alt/super + arrow) restored after `keybind=clear`
- `install.sh` macOS step: symlink Application Support Ghostty config → `~/.config/ghostty/config`

### Changed

- `zsh/.zshrc`: shared cross-platform config; sources `~/.zshrc.d/` before OMZ
- `bash/.bashrc`: WSL/conda moved to `bash-linux/.bashrc.d/`
- `bash/.bash_profile`: sources `~/.bashrc` only
- `install.sh`: mac stows `zsh-macos` only; Linux stows `bash-linux` + `local`
- `ghostty/config`: restore Option/Cmd+arrow line/word navigation keybinds

### Fixed

- Ghostty on macOS ignoring dotfiles config when auto-generated Application Support template exists
- Ghostty Option/Cmd+arrow keys printing literal `C`/`D` instead of word/line navigation
- Tab title showing `user@192` when system hostname is a LAN IP (use macOS ComputerName)

### Removed

- `bash-macos/` package (mac uses zsh)
- `zsh-linux/` package (WSL uses bash)
- Hardcoded `/Users/rujul` and `/home/rujul` paths from shared shell configs
