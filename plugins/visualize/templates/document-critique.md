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

## Revision highlights

When re-rendering a report to a new version (e.g. v1 to v2 after changes), the renderer can visually mark what changed so a reviewer only re-reads the deltas. Two mechanisms work together:

### 1. Revision overview section (`.rev-overview`)

Add **one** `<section class="section rev-overview rev-block">` near the top of the report listing the deltas as a table:

```html
<section class="section rev-overview rev-block" data-screen-label="What's New in v2" id="section-overview">
  <div class="section-header">
    <span class="section-number" style="background:var(--accent)">&Delta;</span>
    <h2>What's New in v2</h2>
    <span class="rev-pill">NEW</span>
  </div>
  <div class="section-body" data-section-body="-1">
    <p>Summary of changes since v1.</p>
    <div class="table-wrap"><table class="data-table">
      <thead><tr><th>Section</th><th>What changed</th></tr></thead>
      <tbody>
        <tr><td>Executive Summary</td><td>Updated cost estimates from $1.2M to $1.45M</td></tr>
        <tr><td>Architecture Plan</td><td>Added API Gateway section, revised diagram</td></tr>
      </tbody>
    </table></div>
  </div>
</section>
```

### 2. Marking changed sections (`.rev-block` + `.rev-pill`)

On sections that changed, add `class="rev-block"` to the `<section>` and insert a pill:

```html
<span class="rev-pill changed">CHANGED</span>
```

inside the `.section-header` (next to the section number or heading). For brand-new sections use `rev-pill` (without `.changed`) with text "NEW".

### 3. Nav-dot badges

On the corresponding `.nav-dot` in the nav rail, add `class="rev"`:

```html
<button class="nav-dot rev" data-label="Architecture" data-section="2"></button>
```

This renders a tiny accent dot on the nav marker.

### 4. Inline text diffs

Wrap changed phrases/values with `<mark class="rev-ins">updated text</mark>` for inline highlighting.

### 5. Legend chip

Place a dismissible legend near the top of the report:

```html
<span class="rev-legend" onclick="this.remove()" title="Dismiss">
  <span class="legend-dot"></span> Accent = new/changed this revision
</span>
```

### Section numbering constraint

The shell's JavaScript iterates a fixed section count (nav-dot scrolling, scroll-spy, section status, feedback badge). The `.rev-overview` **must not disturb this count**. Recommended approaches:

- **Option A (safe, recommended):** Render `.rev-overview` as a non-numbered informational block placed **before** `section-0`. Give it `data-section-body="-1"` (out of range — the JS loops 0..4, so -1 is ignored) and do **not** add a nav-dot for it. It will display but won't participate in scroll-spy or approve/reject. Section numbering of the original sections stays intact.
- **Option B (if nav visibility is needed):** Add a nav-dot for the overview, renumber ALL sections (`section-0` .. `section-N`), update every `data-section` attribute on nav-dots, and update the `data-section-comments` indices. Then verify: approve/reject buttons work, scroll-spy tracks all sections, feedback drawer shows the correct section heading per annotation, and the feedback badge count is accurate. The JS uses `Object.keys(state.sectionStatus)` loops and `document.querySelectorAll('.section')` — both pick up any number of sections, so nothing is hardcoded to 5. **However**, the existing `state.sectionStatus` and `state.sectionComments` objects are seeded with indices 0..4 — adding a section shifts indices, which will orphan any persisted review state from the prior version. Prefer Option A unless you also re-key the persisted state.

After any renumbering, verify the interactive chrome still works: approve/reject on each section, annotation section tracking, nav-dot scroll-spy, and the feedback drawer.

## Inline diff highlights

For *edited* content inside a section (a word swapped, a value updated, a phrase reworded), wrap the change inline — reviewer reads the delta in context, no need to diff two pages mentally. This complements the block-level marks above; the two layers are independent.

| Class | Use for | Markup |
|---|---|---|
| `.rev-del` | Removed text | `<span class="rev-del">old</span>` |
| `.rev-ins2` | Added text | `<span class="rev-ins2">new</span>` (or `<mark class="rev-ins2">…</mark>`) |
| `.rev-swap` | Optional wrapper keeping a del+ins pair adjacent | `<span class="rev-swap"><span class="rev-del">…</span> <span class="rev-ins2">…</span></span>` |
| `.rev-line` | A whole changed line / list item / table row | `<tr class="rev-line">…</tr>` or `<li class="rev-line">…</li>` |

**When to use what:**

- **Inline marks (`.rev-del` / `.rev-ins2`)** — for *edited* content where the section itself is unchanged but a phrase/value/word inside it changed. The reviewer sees the old text struck-through in red next to the new text highlighted in green.
- **`.rev-line`** — for a whole changed row/list item/line where marking every word would be noisy; soft green background + left border flags the line.
- **Block marks (`.rev-block` / `.rev-pill`)** — for *whole new or heavily-changed sections*. The pill sits in the section header; the block gets a tinted background.
- **`.rev-overview`** — the top-level "What's new" section summarizing all deltas.

**Example (word swap):**

```html
<p>The cache layer uses
   <span class="rev-del">in-memory</span>
   <span class="rev-ins2">Postgres</span>
   for persistence.</p>
```

Renders as: "The cache layer uses <s>in-memory</s> <u>Postgres</u> for persistence." — struck-through red old word immediately followed by green-underlined new word, all inside the same sentence.

**Script-safety:** inline diff marks are pure CSS classes — they do **not** touch the shell's `<script>` section, so the interactive chrome (approve/reject, annotations, nav rail, feedback drawer, appearance panel) is completely unaffected. Add or remove them freely without re-testing JS behavior.

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
