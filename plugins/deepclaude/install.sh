#!/usr/bin/env bash
# Install the packaged deepclaude launcher and proxy from this plugin.

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="${DEEPCLAUDE_HOME:-$HOME/.local/share/deepclaude}"
BIN_DIR="${DEEPCLAUDE_BIN_DIR:-$HOME/bin}"

mkdir -p "$INSTALL_ROOT/proxy" "$BIN_DIR"

cp "$PLUGIN_DIR/deepclaude.sh" "$INSTALL_ROOT/deepclaude.sh"
cp "$PLUGIN_DIR/deepclaude.ps1" "$INSTALL_ROOT/deepclaude.ps1"
cp "$PLUGIN_DIR/proxy/"*.js "$INSTALL_ROOT/proxy/"
cp "$PLUGIN_DIR/proxy/README.md" "$INSTALL_ROOT/proxy/"
cp "$PLUGIN_DIR/bin/deepclaude" "$BIN_DIR/deepclaude"

chmod +x "$INSTALL_ROOT/deepclaude.sh" "$INSTALL_ROOT/proxy/start-proxy.js" "$BIN_DIR/deepclaude"

printf 'Installed deepclaude launcher: %s\n' "$BIN_DIR/deepclaude"
printf 'Installed deepclaude runtime:  %s\n' "$INSTALL_ROOT"
