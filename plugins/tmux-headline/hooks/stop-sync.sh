#!/usr/bin/env bash
# Stop hook: poll subscription usage in the background.
#
# Title management moved to UserPromptSubmit (see headline-reminder.sh) — Claude
# Code now drives pane_title natively via the sessionTitle hook output, so this
# hook no longer writes files or pane_title.

set -euo pipefail

PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"

# Background usage poll (throttled to once per 60s inside the script)
"${PLUGIN_ROOT}/scripts/usage-poll.sh" &

echo '{}'
exit 0
