#!/usr/bin/env bash
# Install the deepclaude launcher and proxy from this plugin.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${DEEPCLAUDE_HOME:-$HOME/.local/share/deepclaude}"
BIN_DIR="${DEEPCLAUDE_BIN_DIR:-$HOME/bin}"

mkdir -p "$INSTALL_ROOT/proxy"

# Main script
cp "$PLUGIN_DIR/deepclaude" "$INSTALL_ROOT/deepclaude"
chmod +x "$INSTALL_ROOT/deepclaude"

# Proxy (Node.js)
cp "$PLUGIN_DIR/proxy/"*.js "$INSTALL_ROOT/proxy/"

# Windows launcher
cp "$PLUGIN_DIR/deepclaude.ps1" "$INSTALL_ROOT/deepclaude.ps1"

# Optional PATH symlinks
if [ -d "$HOME/bin" ]; then
    ln -sf "$INSTALL_ROOT/deepclaude" "$HOME/bin/deepclaude" 2>/dev/null || \
        echo "Warning: could not symlink to ~/bin/deepclaude" >&2
    ln -sf "$INSTALL_ROOT/deepclaude" "$HOME/bin/claude" 2>/dev/null || \
        echo "Warning: could not symlink to ~/bin/claude" >&2
fi

printf 'deepclaude installed: %s/deepclaude\n' "$INSTALL_ROOT"
