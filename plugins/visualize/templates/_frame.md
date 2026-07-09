# Shared Frame — Modern-Minimal (visualize templates)

All non-Atlas templates (`code-map`, `concept-map`, `data-explorer`, `design-playground`, `diff-review`) share this frame. Clone it; only the body content differs per template.

## Design language

Modern-minimal (Linear / Vercel family) — the same family as the Atlas viewer. Light `oklch` surface, system-font stack, indigo accent. **Not dark, not brutalist, no Google Fonts.** System fonts only.

## Layout — standard review frame

```
┌─[nav:240px]────┬──[content:flex, max 760px centered]──┬──[notes tab]──┐
│ OUTLINE         │  Title (system-ui, weight 600)        │   NOTES (2)  │
│ ◆ Overview      │  h2: weight 600, indigo square ◆      │               │
│ ● Section       │  Body: system-ui 16px, #1b1d22         │               │
│   └ Sub         │  Code: mono 13px, indigo #4a6cff       │               │
│ ◆ Section       │  Section note: "note" link → inline card│              │
└─────────────────┴───────────────────────────────────────┴──[drawer:360]─┘
                                                            (slides out on click)
```

Three zones:
- **Left nav** (240px), collapsible. `☰ Outline` toggle pinned top-left. Active link gets indigo left border + tinted bg. Sub-items indented with `└ `.
- **Center content**: flex, reading surface max 760px, generous vertical rhythm (h2 margin-top: 48px).
- **Right notes drawer**: hidden, slides out 360px on click. `position:fixed; transform:translateX(100%)`. Vertical "NOTES" tab on right edge.

## CSS variables (the canonical token block — include verbatim in the page `<style>`)

```css
:root {
  --bg:          #fbfbfd;   /* oklch(99% 0.002 240) — page background */
  --surface:     #ffffff;   /* oklch(100% 0)        — cards, nav, drawer */
  --raised:      #f4f5f7;   /* oklch(97% 0.004 250) — code blocks, raised surfaces */
  --line:        #e6e7ea;   /* oklch(92% 0.005 250) — hairlines */
  --line-strong: #d6d7db;   /* oklch(89% 0.006 250) — stronger borders */
  --text:        #1b1d22;   /* oklch(18% 0.012 250) — body text */
  --text-dim:    #71747e;   /* oklch(54% 0.012 250) — secondary text */
  --text-strong: #0f1115;   /* near-black — headings */
  --accent:      #4a6cff;   /* oklch(58% 0.18 255) — indigo, primary signal */
  --accent-dim:  #8aa0ff;   /* lighter indigo for hovers/borders */
  --blue:        #4a6cff;   /* alias of accent (info / link) */
  --green:       #1f9d57;   /* oklch(62% 0.16 145) — success / add */
  --red:         #d63a4a;   /* oklch(54% 0.20 20)  — danger / delete */
  --amber:       #d97706;   /* oklch(68% 0.15 80)  — warning / question */
  --purple:      #8b5cf6;   /* category accent */

  --font-body: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, system-ui, sans-serif;
  --font-mono: 'SF Mono', 'JetBrains Mono', 'IBM Plex Mono', ui-monospace, Menlo, monospace;
  --reading-width: 760px;
}
```

Background `#fbfbfd`. Surface `#ffffff`. Lines `#e6e7ea`. Text `#1b1d22` (dim `#71747e`, strong `#0f1115`). Single accent: indigo `#4a6cff`.

## Typography

```css
h1 { font: 600 34px/1.15 var(--font-body); letter-spacing: -.5px; color: var(--text-strong); }
h2 { font: 600 22px var(--font-body); margin-top: 48px; color: var(--text-strong); }
h2::before { content: ''; display: inline-block; width: 8px; height: 8px;
  background: var(--accent); margin-right: 12px; vertical-align: middle; }
h3 { font: 600 17px var(--font-body); margin-top: 28px; color: var(--text-strong); }
p  { font: 400 16px/1.65 var(--font-body); margin-bottom: 12px; color: var(--text); }
code { font: 400 13px var(--font-mono); background: var(--raised); padding: 2px 6px;
  color: var(--accent); border-radius: 4px; }
pre { background: var(--raised); border: 1px solid var(--line); padding: 16px 20px;
  font: 400 13px/1.55 var(--font-mono); border-radius: 8px; }
pre code { background: none; padding: 0; color: var(--text); }
```

## Notes drawer

Slide-out panel. Triggered by a vertical tab pinned to the right edge:

```css
#notes-drawer { position: fixed; top:0; right:0; bottom:0; width:360px;
  background: var(--surface); border-left: 1px solid var(--line);
  transform: translateX(100%); transition: transform .25s cubic-bezier(.4,0,.2,1); z-index:9;
  box-shadow: -8px 0 24px rgba(15,17,21,.04); }
#notes-drawer.open { transform: translateX(0); }
#drawer-overlay { position: fixed; inset:0; background: rgba(15,17,21,.18); z-index:8; display:none; }
#drawer-overlay.show { display: block; }
#notes-tab { position: fixed; top:50%; right:0; transform: translateY(-50%) rotate(-90deg);
  background: var(--surface); border: 1px solid var(--line); border-bottom:none;
  padding: 8px 16px; font: 500 10px var(--font-mono); text-transform: uppercase;
  letter-spacing: 1.2px; color: var(--text-dim); cursor: pointer; z-index:7;
  transition: right .25s cubic-bezier(.4,0,.2,1); }
#notes-tab.has-notes { color: var(--accent); }
#notes-tab.drawer-open { right: 360px; }
```

Note cards use `--raised` background, `--line` border, section name in mono indigo label.

## Notes persistence

Notes persist client-side via `localStorage` (keyed by page slug). The visualize server is a plain file server with no `/_notes` route — do not depend on one. If you wire up add/remove handlers, keep them in-page only.

## Scroll spy

IntersectionObserver on all `h2[id], h3[id]`. Root margin `-20% 0px -70% 0px`. Active nav link gets `color: var(--accent)` + indigo left border.

## Findings mode (shared severity styling)

For finding/severity cards anywhere:

```css
.finding { padding: 12px 16px; margin-bottom: 8px; border-left: 3px solid var(--line);
  background: var(--surface); border: 1px solid var(--line); border-radius: 8px; }
.finding.crit   { border-left-color: var(--red);   background: color-mix(in srgb, var(--red) 4%, var(--surface)); }
.finding.warn   { border-left-color: var(--amber); background: color-mix(in srgb, var(--amber) 5%, var(--surface)); }
.finding.info   { border-left-color: var(--blue);  background: color-mix(in srgb, var(--blue) 4%, var(--surface)); }
.finding.ok     { border-left-color: var(--green); }
.finding.resolved { opacity: .5; }
.finding.resolved .finding-title { text-decoration: line-through; }
```
