# Atlas — AI Agent Report Viewer (`document-critique`)

Use when content is a **report, audit, spec review, proposal, finding list, planning doc, design doc, or any structured document** meant to be read section by section and optionally annotated.

This template is driven by a ready-made shell: **`atlas-shell.html`** in this directory. You do not hand-write the page — you clone the shell and fill it.

## How to render

```bash
cp ${CLAUDE_PLUGIN_ROOT}/templates/atlas-shell.html ~/.local/share/claude-visualize/pages/<slug>.html
```

Then edit `~/.local/share/claude-visualize/pages/<slug>.html`:

1. **`<title>`** and the **`.report-header`** (title + meta row) → the content's title and a one-line summary.
2. **Sections** → replace each `<section class="section">` with one section per logical part of the content. The shell ships a working example of every pattern (each is labelled with an HTML comment) — copy the closest one and swap the inner content. Keep each section's classes and `data-screen-label="NN Title"`.
3. **Nav rail** → exactly one `button.nav-dot` per section, in order, with `data-section="N"` and `data-label="…"` matching each section. First dot carries `active`.
4. **Sample annotations/comments** → for a clean render, delete the seeded annotation ids (`a1`…) and drawer comment threads. Leave them only if you want markup examples. They persist to the server via `/_feedback/<slug>`.
5. **Keep everything else byte-identical** — the entire `<style>` block, the entire `<script>` block, and all chrome (nav rail, feedback drawer, annotation composer, appearance panel).

## Design language

Modern-minimal (Linear / Vercel family). Light `oklch` surface, system-font stack, indigo accent. Not dark, not brutalist. The reader can toggle **darkmode**, **font size**, and **5 style themes** at runtime via the appearance panel (gear, top-right) — keep that panel intact.

## Tokens (already in the shell `:root` — do not change)

```css
--bg:      oklch(99% 0.002 240);   /* page background, near-white */
--surface: oklch(100% 0 0);        /* cards, nav, drawer */
--fg:      oklch(18% 0.012 250);   /* body text */
--muted:   oklch(54% 0.012 250);   /* secondary text */
--border:  oklch(92% 0.005 250);   /* hairlines */
--accent:  oklch(58% 0.18 255);    /* indigo — primary signal */
--accent-soft: oklch(95% 0.03 255);
--success: oklch(62% 0.16 145);  --success-soft: oklch(94% 0.04 145);
--warning: oklch(68% 0.15 80);   --warning-soft: oklch(95% 0.05 80);
--danger:  oklch(54% 0.20 20);   --danger-soft:  oklch(95% 0.03 20);

--font-display / --font-body: system-ui stack;   --font-mono: SF Mono / JetBrains Mono stack.
```

## Required DOM markers — keep these when filling sections

The JS listens for these. Event delegation (document-level) means they work even when sections are added or reordered.

| Feature | Required | Where |
|---|---|---|
| Section container | `class="section"` + `id="section-N"` (N=0,1,2…) | Every section |
| Section body | `data-section-body="N"` on a child div (selection handler targets this) | Inside each section |
| Section label | `data-screen-label="NN Title"` on the `<section>` (nav scroll-spy header) | Every section |
| Comment thread | `<div class="comment-thread" data-section-comments="N">` containing an `<h4>`, a `.comment-input-row` with `<textarea data-comment-input="N">` and `<button data-comment-submit="N">` | One per section |
| Nav dot | `<button class="nav-dot" data-section="N" data-label="…">` | One per section in `.nav-rail` |
| Approve/reject | `<button class="btn-approve" data-section="N">` / `<button class="btn-reject" data-section="N">` | Inside `.section-header` |
| Checklist checkbox | `<input type="checkbox" id="…" class="checklist…">` (any `id`; id used as state key) | Inside `.checklist` |
| Annotatable text | `<span class="annotatable" data-annotation-id="aN">` (optional — seed data; not needed for user-created annotations) | Anywhere in section body |

## Section patterns → map content to the right one

Build one `<section>` per logical part. Reuse the matching example in the shell:

| Content shape | Pattern | Shell example |
|---|---|---|
| Summary, intro, overview, prose | report-header + prose paragraphs | Section 1 (Executive Summary) |
| Spec, requirements, decisions, **findings** | spec/finding cards grid (severity-coloured) | Section 2 (Design System) |
| System, architecture, data flow, components | architecture diagram (nodes + edges) | Section 3 (Architecture Plan) |
| Metrics, rows, comparison, tables | data table | Section 4 (Performance Data) |
| Steps, todos, sequencing, pipeline | checklist | Section 5 (Implementation Checklist) |

**Findings / severity:** map critical → `--danger`, warning → `--warning`, info/success → `--success`. Use the soft variants for card backgrounds, full variants for left borders and badges.

**Inline annotations** (when the content itself flags points): three intents — feedback (blue/accent), question (amber/warning), suggestion (violet). Selecting text in the rendered page opens the composer; seeded annotations live in the drawer.

## Chrome (keep intact)

All interactive features use **event delegation** (document-level listeners with selector matching) — they work for any number of sections, any content, and dynamically-added elements. The fill step only needs to preserve the required DOM markers below.

- **Nav rail** (left, 56px) — section dots, scroll-spy, active highlight.
- **Feedback drawer** (right, 360px) — comment threads, badge counter, resolve.
- **Annotation composer** — appears on text selection; intent toggle + post.
- **Appearance panel** (gear) — darkmode switch, font-size S/M/L, 5 style themes.
- **Checklists** — any `.checklist input[type="checkbox"]` with an `id` is persisted to server state via document-level `change` delegation.
- All review state persists server-side (`/_feedback/<slug>`); appearance prefs stay in `localStorage`.

## Notes

- **Self-contained render + server-primary state.** The page needs no server route to *render*. State is loaded from `GET /_feedback/<slug>` on open (or clean defaults if 404) and persisted via debounced `POST /_feedback/<slug>` on every change — no `localStorage` for review data. Appearance prefs (`atlas-theme` / `atlas-font-size` / `atlas-style`) stay in `localStorage` by design.
- **Clean by default.** Hardcoded sample section comments are auto-stripped on load (a fresh clone starts at 0 comments). Seeded inline annotation highlights (`a1`–`a5`) and their drawer cards remain as markup examples — leave them, or clear them for a fully bare page.
- **Review loop (PATCH-1 — how feedback gets back to the agent).** State is server-primary: on page load, `GET /_feedback/<slug>` loads saved state; on every change the page `POST`s its full state to `/_feedback/<slug>` (debounced 400ms). The server writes `~/.local/share/claude-visualize/feedback/<slug>.json`. **That file is what the agent reads to incorporate the review** — e.g. `Read ~/.local/share/claude-visualize/feedback/<slug>.json` to see annotations, section comments, and approve/reject status. The browser is a client — two concurrent reviewers on the same report would last-writer-wins the server file; assume single-reviewer-per-report.
- **Re-syncing from Open Design:** `atlas-shell.html` carries visualize-specific patches (server-persisted state, section-comment persistence, sample-comment strip) that diverge from upstream `index.html`. To update after the user edits the project in Open Design: refetch `index.html`, then run `python3 build-atlas-shell.py` (same directory) — it re-injects the guide markers *and* re-applies every patch. Then verify with `node test-atlas-shell.mjs` (same directory) — a self-contained live-reload test (serves the shell, spawns headless Chrome, drives the real UI). Do **not** copy upstream `index.html` directly over the shell, or the patches are lost. The feedback POST route (`do_POST`) lives in `visualize/SKILL.md`'s server script — if that script changes, restart the visualize server (kill the pid in `~/.local/share/claude-visualize/server.json`, relaunch `python3 ${CLAUDE_PLUGIN_ROOT}/server.py 8766`).
- A finding/severity list maps cleanly onto Section 2's card grid — this template fully covers the old "findings/audit mode."
- If the content is a single unstructured blob with no sections, prefer `generic-render` instead.
