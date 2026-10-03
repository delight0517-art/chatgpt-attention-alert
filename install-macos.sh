#!/bin/zsh
set -euo pipefail

root=${0:A:h}
share="$HOME/.local/share/chatgpt-attention-alert"
bin="$HOME/.local/bin"
mkdir -p "$share" "$bin"
cp "$root/plugin/companion/macos/alert.swift" "$share/alert.swift"
cp "$root/plugin/companion/macos/drive-state.py" "$share/drive-state.py"
cp "$root/plugin/companion/macos/chatgpt-attention-alert" "$bin/chatgpt-attention-alert"
chmod +x "$bin/chatgpt-attention-alert"
print "Installed ChatGPT Attention Alert. Ensure $bin is on PATH."
