# fd is packaged as fd-find on Debian/Ubuntu
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
    alias fd=fdfind
fi

# bat is packaged as batcat on older Debian/Ubuntu
if command -v batcat &>/dev/null && ! command -v bat &>/dev/null; then
    alias bat=batcat
fi
