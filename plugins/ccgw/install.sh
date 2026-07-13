#!/usr/bin/env bash
# Install ccgw. `ccgw` is already on PATH when this plugin is enabled (bin/).
# This script is the OPT-IN step that makes bare `claude` default to gateway mode
# by pointing ~/bin/claude at ccgw. Reversible (see below).
set -euo pipefail
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${CCGW_BIN_DIR:-$HOME/bin}"
mkdir -p "$BIN_DIR"
ln -sfn "$PLUGIN_DIR/bin/ccgw" "$BIN_DIR/ccgw"
ln -sfn "$PLUGIN_DIR/bin/ccgw" "$BIN_DIR/claude"
printf 'ccgw installed. `claude` and `ccgw` -> %s/bin/ccgw\n' "$PLUGIN_DIR"
printf 'Revert `claude` with:  ln -sfn ~/.local/share/deepclaude/deepclaude %s/claude\n' "$BIN_DIR"
