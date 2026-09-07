# Linux / WSL specific setup. Sourced by ~/.bashrc before common.sh.

# wslu: open URLs in the Windows default browser (WSL only)
if grep -qi microsoft /proc/version 2>/dev/null; then
  export BROWSER=wslview
fi

# Neovim from the official pre-built tarball (installed to /opt by install.sh).
# Prepend so it wins over the older apt-packaged /usr/bin/nvim. Existing
# entries are stripped first so re-sourcing always ends with it at the front.
for _nvim_dir in /opt/nvim/bin /opt/nvim-linux-x86_64/bin /opt/nvim-linux-arm64/bin; do
  if [ -x "$_nvim_dir/nvim" ]; then
    PATH=":${PATH}:"
    while [[ "$PATH" == *":$_nvim_dir:"* ]]; do
      PATH="${PATH//:$_nvim_dir:/:}"
    done
    PATH="${PATH#:}"; PATH="${PATH%:}"
    export PATH="$_nvim_dir:$PATH"
    break
  fi
done
unset _nvim_dir
