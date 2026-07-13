---
name: visualize
description: Renders text content as clean, reviewable HTML served on a local HTTP server reachable from your browser. Use when the user says "visualize", "render", "show me", "visualize as <type>", or asks to see output in a browser. Picks the right visual format based on what the content IS.
---

# Visualize

Render any text content as an HTML page and serve it on a persistent HTTP server reachable from your browser.

## When to use

User says "visualize [content]", "render this", "show me in browser", "visualize as <type>", or asks to see output visually. Also triggered by `/visualize [type] [content]`.

## Server lifecycle

The server persists across sessions. Any session running this skill discovers and reuses the same server.

### Check for existing server first

```bash
# Read state file, check if PID is alive
cat ~/.local/share/claude-visualize/server.json 2>/dev/null \
  && kill -0 $(python3 -c "import json;print(json.load(open('~/.local/share/claude-visualize/server.json'))['pid'])") 2>/dev/null \
  && echo "REUSE" || echo "START_NEW"
```

If `REUSE`: use the IP and port from the state file, skip to "Add a page."
If `START_NEW`: continue below.

### Start a new server

1. **Find the best IP.** Run both, use the first non-empty:
   ```
   tailscale ip -4 2>/dev/null          # tailnet IP (preferred)
   hostname -I 2>/dev/null | awk '{print $1}'  # primary local IP
   ```
   If multiple IPs are available and the choice is ambiguous, ask the user which to bind to.

2. **Find a free port.** Start at `8765`, try up to `8770`:
   ```bash
   for port in 8765 8766 8767 8768 8769 8770; do
     python3 -c "import socket; s=socket.socket(); s.bind(('', $port)); s.close()" 2>/dev/null && { echo "$port"; break; }
   done
   ```

3. **Start the server.** Run the script bundled with the skill:

```bash
python3 ${CLAUDE_PLUGIN_ROOT}/server.py <port> &
```

Wait for `SERVER_READY:<port>` on stdout.

4. **Track the server.** Write `~/.local/share/claude-visualize/server.json`:
```json
{"pid": <pid>, "ip": "<ip>", "port": <port>}
```

The server has no idle timeout — it stays up until the machine reboots or the PID is killed. New sessions discover it via the state file.

### Add a page

Write the HTML to `~/.local/share/claude-visualize/pages/<slug>.html` using **bash** (not the Write tool — it may be sandboxed):
```bash
cat > ~/.local/share/claude-visualize/pages/<slug>.html << 'HTMLEOF'
...content...
HTMLEOF
```

Where `<slug>` is a kebab-case name from the content (e.g., `setup-audit`, `design-doc`).

Print the URL: `http://<ip>:<port>/<slug>.html`
Also the index: `http://<ip>:<port>/`

## Core rules

1. **Read the content** — understand what it IS before picking a format
2. **Pick the best template** from the list below based on what the content IS, not what the user called it
3. **If the user says "as <type>"**, use that template regardless of detection
4. **If no template fits**, use `generic-render`
5. **Ensure server is running** — start or reuse as described above
6. **Write page to `~/.local/share/claude-visualize/pages/<slug>.html`** and print the URL
7. **Single self-contained HTML file.** Modern-minimal theme: light `oklch` surface, system-font stack, indigo (`oklch(58% 0.18 255)`) accent. The report viewer (document-critique) ships an appearance panel with darkmode, font-size, and style-theme toggles. No required external dependencies (system fonts; no Google Fonts needed).
8. **Diagrams = declarative, never hand-placed coordinates.** For any architecture / data-flow / pipeline / sequence / state diagram, use the `svg-diagram` template: declare `{nodes, edges}` as data and call `renderDiagram(spec)`. NEVER hand-write SVG `x`/`y` coordinates (LLMs mis-place them — boxes overlap, arrows tangle), and don't fall back to `<div>` boxes with `→` glyphs — the helper makes real SVG easier and better.

## Templates

Pick ONE based on what the content actually contains:

### `generic-render`
Clean rendered page. No interactive chrome, no controls, no approve/reject. Just well-formatted content optimized for reading.
Use for: conversation summaries, explainer text, general output, anything that doesn't fit below.

### `document-critique` (Atlas viewer)
Atlas report viewer: left nav rail, multi-section body, inline annotations (feedback/question/suggestion), feedback drawer with comment threads, per-section approve/reject, plus an appearance panel (darkmode, font size, 5 style themes). Driven by `atlas-shell.html`.
Use for: reports, audits, finding lists, spec reviews, planning docs, design docs, any structured document.

### `diff-review`
Line-by-line diff viewer with commenting. Side-by-side or unified view.
Use for: git diffs, code changes, patches.

### `svg-diagram`
Clean, **auto-laid-out** SVG diagram from a declarative `{nodes, edges}` spec (embedded zero-dependency helper — you never write coordinates). Boxes + routed arrows, semantic shapes (process, decision diamond, data cylinder, external) and colors, edge labels, LR/TB layout. Renders at legible size in a **bounded zoom/pan viewport** (auto fit-to-width floored at 70%, `+/−/Fit/1:1` controls, ⌘/Ctrl+wheel zoom, drag pan) and **word-wraps** long labels — so wide flows stay readable instead of shrinking to microscopic text.
Use for: architecture, data/request flow, pipelines, sequence of components, state machines, dependency maps — the default for "show me how it works" pictures.

### `code-map`
Architecture diagram rendered as an **interactive** graph (draggable/zoomable, click-to-annotate). Heavier than `svg-diagram`; use only when the user needs to *explore* a large graph, not just see it.
Use for: large explorable dependency graphs where interaction matters.

### `design-playground`
Interactive visual explorer with live controls (sliders, color pickers, toggles). Renders a preview that updates instantly.
Use for: UI component mockups, layout exploration, visual design decisions.

### `data-explorer`
Structured data viewer with filter, sort, search. Table or card layout.
Use for: query results, CSVs, JSON data, metrics tables, comparison grids.

### `concept-map`
Interactive graph of concepts and relationships. Zoomable, draggable nodes.
Use for: complex topics, knowledge graphs, concept relationships, taxonomies.

### `concept-map` (logic-flow mode)
Same engine, configured as linear/stepped flow. Nodes are steps, edges show sequence.
Use for: logic flows, sequencing, step-by-step processes, pipelines.

## Output requirements

- **Server running** before writing pages — see Server lifecycle above
- **URL printed** in the response so user can click to open
- **Index page** at `http://<ip>:<port>/` lists all visualizations
- **Templates**: loaded from `${CLAUDE_PLUGIN_ROOT}/templates/<name>.md` and adapted to the content
- **generic-render**: no template needed — write a clean page directly:
  - Light surface (`#fbfbfd` / `oklch(99% 0.002 240)`), dark text (`#1b1d22` / `oklch(18% 0.012 250)`), system-font stack
  - Max-width 800px centered, good line-height, readable font-size
  - Render markdown: `#` → h1/h2, `**` → strong, `` ` `` → code, `-` → list items
  - Code blocks get a soft surface (`#f4f5f7`), monospace font; inline code tinted indigo (`#4a6cff`)
  - No interactions, no buttons, no controls. Just content.

## Examples

### Example 1: Audit findings → document-critique

User: "visualize the setup audit"

Content is a list of 7 issues, each with severity (critical/warning/info), title, body, and action. This IS a findings list.

→ Ensure server running on tailnet IP. Pick `document-critique`. Write to `~/.local/share/claude-visualize/pages/setup-audit.html`. Print `http://<ip>:8765/setup-audit.html`.

### Example 2: Conversation summary → generic-render

User: "visualize what we decided"

Content is a paragraph of decisions and next steps. No structure, no findings, no data.

→ Pick `generic-render`. Write to `~/.local/share/claude-visualize/pages/decisions.html`. Print URL.

### Example 3: Explicit override

User: "visualize as architecture the setup audit"

Content is findings, but user said "as architecture."

→ Pick `code-map`. Render the setup components (plugins, settings, memory, CLAUDE.md) as nodes with dependency edges.

### Example 4: Git diff → diff-review

User: "visualize this diff"

Content has `+++`, `---`, `@@ -1,4 +1,4 @@`, hunks.

→ Pick `diff-review`. Side-by-side diff viewer with line commenting.

### Example 5: Query results → data-explorer

User: "visualize the search results"

Content is a JSON array of objects with title, url, snippet.

→ Pick `data-explorer`. Filterable table with sort, search.

### Example 6: Design spec → document-critique

User: "visualize the design doc"

Content is a markdown spec with sections, requirements, decisions.

→ Pick `document-critique`. Structured review with sections as finding groups.

### Example 7: Data flow description → svg-diagram

User: "visualize how requests flow through the proxy"

Content describes a pipeline: Claude Code → deepclaude launcher → proxy → provider API.

→ Pick `svg-diagram`. Declare each component as a node (client=external, proxy=process, provider=external) and the hops as edges; call `renderDiagram({dir:'LR', nodes, edges})`. Never hand-place coordinates.

### Example 8: Unknown/mixed → generic-render

User: "visualize those notes"

Content is a mix of bullet points, code snippets, URLs, no clear dominant structure.

→ Pick `generic-render`. Clean page, no template is a good match.

### Example 9: Step-by-step process → concept-map (logic-flow mode)

User: "visualize the release process"

Content lists steps in order: bump version → update changelog → commit → tag → push.

→ Pick `concept-map` in logic-flow mode. Vertical sequence of steps with directional edges.

### Example 10: UI mockup → design-playground

User: "visualize a login form with dark theme"

Content describes a UI component with styling parameters.

→ Pick `design-playground`. Live controls for colors, spacing, border-radius with preview pane.

## How to pick

Ask yourself: **what IS this content?** Not what the user called it, not what surrounds it. Read the actual bytes.

| Content looks like | Template |
|---|---|
| A list of issues, findings, problems with severity | `document-critique` |
| A spec, proposal, or document for review | `document-critique` |
| `+++`/`---`/`@@` diff markers | `diff-review` |
| Architecture, data flow, pipeline, sequence, state machine | `svg-diagram` |
| Large graph the user needs to *explore* interactively | `code-map` |
| UI descriptions with visual parameters | `design-playground` |
| Tabular data, JSON arrays, CSVs | `data-explorer` |
| Concepts and relationships, taxonomies | `concept-map` |
| Sequential steps, pipeline stages, ordered flow | `concept-map` (logic-flow) |
| Paragraphs, mixed text, no clear structure | `generic-render` |

When in doubt, `generic-render`. It's fast, always looks good, never the wrong shape.
