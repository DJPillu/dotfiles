# hostname(1) returns the LAN IP on this Mac; zsh %m truncates at "." → "192" in tab titles
if _cn=$(scutil --get ComputerName 2>/dev/null) && [[ -n "$_cn" ]]; then
  HOST="$_cn"
fi
unset _cn
