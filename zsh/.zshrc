# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

export ZSH="$HOME/.config/oh-my-zsh/"
ZSH_THEME="powerlevel10k/powerlevel10k"
POWERLEVEL9K_CONFIG_FILE="$HOME/.p10k.zsh"
ZSH_CUSTOM=~/.config/oh-my-zsh/custom/

zstyle ':omz:update' mode reminder

# OS-specific setup (brew, conda, rancher, gcloud) — stowed from zsh-macos/
if [[ -d "$HOME/.zshrc.d" ]]; then
  for f in "$HOME/.zshrc.d"/*.zsh(N); do source "$f"; done
fi

plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-completions
  docker
  npm
  pip
  rust
  sudo
  extract
  z
  colored-man-pages
  fzf
)

source $ZSH/oh-my-zsh.sh

export TERM=xterm-256color
export EDITOR=vim

alias python=python3
alias pip=pip3

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

. "$HOME/.local/bin/env"
. "$HOME/.cargo/env"

# ── History settings ──────────────────────────────────────────────
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_SAVE_NO_DUPS
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_REDUCE_BLANKS

# ── Modern CLI tool aliases ──────────────────────────────────────
alias ls="eza --icons --group-directories-first"
alias ll="eza -lah --icons --group-directories-first --git"
alias lt="eza --tree --level=2 --icons"
alias cat="bat --paging=never"
alias catp="bat"
alias find="fd"
alias grep="rg"

# ── fzf configuration ───────────────────────────────────────────
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
source <(fzf --zsh)

# ── zoxide (smarter cd) ─────────────────────────────────────────
eval "$(zoxide init zsh --cmd cd)"

[[ ! -f "${POWERLEVEL9K_CONFIG_FILE}" ]] || source "${POWERLEVEL9K_CONFIG_FILE}"

export PATH="$HOME/.grok/bin:$PATH"
export PATH="/Users/rujul/.duckdb/cli/latest":$PATH
export REPORTTIME=3

# Enable extended history tracking (records timestamps and duration)
setopt EXTENDED_HISTORY

# Append commands immediately to history with duration tracked
setopt INC_APPEND_HISTORY_TIME

