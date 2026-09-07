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
  colored-man-pages
  fzf
)

if [[ -f "$ZSH/oh-my-zsh.sh" ]]; then
  source "$ZSH/oh-my-zsh.sh"
else
  # Degraded mode (omz module not run yet): plain completion, ignore the
  # "insecure directories" prompt that group-writable dirs (e.g. CI) trigger.
  autoload -Uz compinit && compinit -u
fi

export TERM=xterm-256color

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
setopt EXTENDED_HISTORY          # timestamps and duration
setopt INC_APPEND_HISTORY_TIME   # append immediately with duration tracked
export REPORTTIME=3              # print timing for commands > 3s

# ── Shared cross-shell config (aliases, fzf, zoxide, nvm, EDITOR, PATH) ─
[[ -f "$HOME/.config/shell/common.sh" ]] && source "$HOME/.config/shell/common.sh"

[[ ! -f "${POWERLEVEL9K_CONFIG_FILE}" ]] || source "${POWERLEVEL9K_CONFIG_FILE}"
