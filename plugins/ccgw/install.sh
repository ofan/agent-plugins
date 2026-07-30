#!/usr/bin/env bash
# Install ccgw launchers. `ccgw` is already on PATH when this plugin is enabled
# (bin/); this script is the OPT-IN step that makes bare `claude` default to
# gateway mode by pointing ~/bin/claude at ccgw.
#
# Tries symlink first (propagates plugin updates for free); falls back to a
# thin wrapper if symlinks aren't supported (NTFS without Dev Mode, FAT, etc.).
# The wrapper content is byte-identical cross-platform and does NOT export
# CCGW_CLAUDE_BIN — the plugin's bin/ccgw has its own PATH-aware resolver that
# prefers the active node's claude and only falls back to node/lts.
set -euo pipefail
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${CCGW_BIN_DIR:-$HOME/bin}"
mkdir -p "$BIN_DIR"

install_launcher() {
  local dst="$BIN_DIR/$1"
  # Try symlink first — propagates plugin updates for free.
  if ln -sfn "$PLUGIN_DIR/bin/ccgw" "$dst" 2>/dev/null && [ -L "$dst" ]; then
    return 0
  fi
  # Fallback: thin wrapper. Bytes are identical cross-platform so the file is
  # safe to track in a dotfiles repo and sync across Linux/Windows/macOS.
  rm -f "$dst"
  cat > "$dst" <<'WRAPPER'
#!/usr/bin/env bash
# ccgw launcher — execs the plugin binary. Identical on Linux/macOS/WSL/Git-Bash.
# Do not edit; rerun ccgw/install.sh to regenerate.
set -euo pipefail
exec "$HOME/.claude/plugins/marketplaces/ofan-plugins/plugins/ccgw/bin/ccgw" "$@"
WRAPPER
  chmod +x "$dst"
}

install_launcher ccgw
install_launcher claude

printf 'ccgw installed. `claude` and `ccgw` -> %s/bin/ccgw\n' "$PLUGIN_DIR"
printf 'Revert `claude` with:  ln -sfn ~/.local/share/deepclaude/deepclaude %s/claude\n' "$BIN_DIR"
