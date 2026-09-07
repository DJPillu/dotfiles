# ~/.bashrc: executed by bash(1) for non-login shells.
# Shared cross-platform bash config. Tool aliases/PATH live in
# ~/.config/shell/common.sh (shared with zsh); OS-specific bits in ~/.bashrc.d/.
# Deliberately no "return if non-interactive" guard so PATH is also correct
# for `bash -c ...` and `ssh host cmd`.

# ── History ──────────────────────────────────────────────────────
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=50000
HISTFILESIZE=50000
HISTTIMEFORMAT='%F %T  '
shopt -s checkwinsize
shopt -s globstar 2>/dev/null

if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# ── Prompt ───────────────────────────────────────────────────────
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# ── Colours for coreutils (overridden by eza aliases when installed) ──
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi
alias l='ls -CF'

alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# ── Completion ───────────────────────────────────────────────────
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi
[ -r "$HOME/.grok/completions/bash/grok.bash" ] && . "$HOME/.grok/completions/bash/grok.bash"

# ── OS-specific setup (WSL, apt-compat, conda) — stowed from bash-linux/ ──
# Runs before common.sh so PATH entries added here (e.g. /opt/nvim) are visible
# to the tool guards in common.sh.
if [ -d "$HOME/.bashrc.d" ]; then
  for f in "$HOME/.bashrc.d"/*.sh; do [ -f "$f" ] && . "$f"; done
fi

# ── Shared cross-shell config (aliases, fzf, zoxide, nvm, EDITOR) ─
[ -f "$HOME/.config/shell/common.sh" ] && . "$HOME/.config/shell/common.sh"
