---
event: Stop
description: "Warn if a process loop is active with incomplete tasks"
---

# Stop Check

Before stopping, check if there are active tasks from a `/run-loop` execution.

If tasks exist with status `in_progress`, warn the user:
"A process loop is still active with incomplete steps. Consider finishing or explicitly canceling."

Do NOT block stopping — just warn. The user can always override.
