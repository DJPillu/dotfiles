# Shared interactive-shell setup, sourced by both ~/.bashrc and ~/.zshrc.
# Must stay bash- and zsh-compatible. Every tool is guarded so a fresh machine
# without it never prints errors on shell start.

if [ -n "${ZSH_VERSION:-}" ]; then _shell=zsh; else _shell=bash; fi

# ── PATH additions (all guarded) ─────────────────────────────────
[ -f "$HOME/.local/bin/env" ] && . "$HOME/.local/bin/env"
[ -f "$HOME/.cargo/env" ]     && . "$HOME/.cargo/env"
[ -d "$HOME/.grok/bin" ]      && export PATH="$HOME/.grok/bin:$PATH"
# Appended: the official duckdb installer's copy is only a fallback, so the
# managed one (~/.local/bin on Linux, Homebrew on macOS) wins.
[ -d "$HOME/.duckdb/cli/latest" ] && export PATH="$PATH:$HOME/.duckdb/cli/latest"

# ── Editor ───────────────────────────────────────────────────────
if command -v nvim >/dev/null 2>&1; then
  export EDITOR=nvim VISUAL=nvim
  alias vim=nvim
  alias vi=nvim
else
  export EDITOR=vim VISUAL=vim
fi

# ── Modern CLI replacements (only when installed) ────────────────
if command -v eza >/dev/null 2>&1; then
  alias ls="eza --icons --group-directories-first"
  alias ll="eza -lah --icons --group-directories-first --git"
  alias la="eza -a --icons --group-directories-first"
  alias lt="eza --tree --level=2 --icons"
else
  alias ll="ls -alF"
  alias la="ls -A"
fi

if command -v bat >/dev/null 2>&1; then
  alias cat="bat --paging=never"
  alias catp="bat"
elif command -v batcat >/dev/null 2>&1; then   # Debian/Ubuntu package name
  alias bat="batcat"
  alias cat="batcat --paging=never"
  alias catp="batcat"
fi

if command -v fd >/dev/null 2>&1; then
  _fd=fd
elif command -v fdfind >/dev/null 2>&1; then   # Debian/Ubuntu package name
  _fd=fdfind
  alias fd="fdfind"
else
  _fd=""
fi
[ -n "$_fd" ] && alias find="$_fd"

command -v rg >/dev/null 2>&1 && alias grep="rg"

alias python=python3
alias pip=pip3

# ── fzf ──────────────────────────────────────────────────────────
if command -v fzf >/dev/null 2>&1; then
  if [ -n "$_fd" ]; then
    export FZF_DEFAULT_COMMAND="$_fd --type f --hidden --follow --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="$_fd --type d --hidden --follow --exclude .git"
  fi
  # `fzf --bash|--zsh` needs >= 0.48; apt on Ubuntu 24.04 ships 0.44.
  _fzf_ver="$(fzf --version 2>/dev/null | awk '{print $1}')"
  if [ "$(printf '%s\n0.48.0\n' "$_fzf_ver" | sort -V | head -n1)" = "0.48.0" ]; then
    if [ "$_shell" = zsh ]; then source <(fzf --zsh); else eval "$(fzf --bash)"; fi
  elif [ "$_shell" = bash ]; then
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/doc/fzf/examples/completion.bash ]   && . /usr/share/doc/fzf/examples/completion.bash
  else
    [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ] && . /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ]   && . /usr/share/doc/fzf/examples/completion.zsh
  fi
  unset _fzf_ver
fi

# ── zoxide (smarter cd) ──────────────────────────────────────────
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init "$_shell" --cmd cd)"

# ── nvm ──────────────────────────────────────────────────────────
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# ── Scheduled dotfiles-sync: one line when it needs you ──────────
case "$-" in
  *i*)
    _ds_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/status"
    _ds_msg=""
    if [ -r "$_ds_file" ]; then
      read -r _ds_state _ds_when <"$_ds_file"
      if [ "$_ds_state" = attention ]; then
        _ds_msg="dotfiles: the $_ds_when sync needs attention: dotfiles-sync --status"
      elif [ -n "$(command find "$_ds_file" -mtime +2 2>/dev/null)" ]; then
        _ds_msg="dotfiles: no sync since $_ds_when; check: ~/.dotfiles/install.sh --check"
      fi
    fi
    if [ -n "$_ds_msg" ]; then
      # Powerlevel10k's instant prompt captures any output until the first
      # prompt (even from precmd hooks) and warns about it; release it first.
      if [ "$_shell" = zsh ] && type p10k >/dev/null 2>&1; then p10k clear-instant-prompt; fi
      printf '\033[33m%s\033[0m\n' "$_ds_msg"
    fi
    unset _ds_file _ds_state _ds_when _ds_msg ;;
esac

unset _shell _fd
