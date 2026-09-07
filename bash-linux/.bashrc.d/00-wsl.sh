export BROWSER=wslview

# Neovim from the official pre-built tarball (neovim.io/doc/install).
# Prepend so it wins over the older apt-packaged /usr/bin/nvim.
# Strip any existing (possibly trailing) entries first so re-sourcing
# always ends with it at the front.
if [[ -d /opt/nvim-linux-x86_64/bin ]]; then
  PATH=":${PATH}:"
  while [[ "$PATH" == *":/opt/nvim-linux-x86_64/bin:"* ]]; do
    PATH="${PATH//:\/opt\/nvim-linux-x86_64\/bin:/:}"
  done
  PATH="${PATH#:}"; PATH="${PATH%:}"
  export PATH="/opt/nvim-linux-x86_64/bin:$PATH"
fi
