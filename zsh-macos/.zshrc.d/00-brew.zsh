if [[ -x /opt/homebrew/bin/brew ]]; then        # Apple Silicon
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [[ -x /usr/local/bin/brew ]]; then         # Intel
  eval "$(/usr/local/bin/brew shellenv)"
fi
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  plugins+=(brew)
  [[ -d "$HOMEBREW_PREFIX/opt/openjdk/bin" ]] && export PATH="$HOMEBREW_PREFIX/opt/openjdk/bin:$PATH"
fi
