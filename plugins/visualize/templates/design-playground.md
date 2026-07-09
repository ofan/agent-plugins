# Design Playground Template

Use when content describes visual decisions: UI components, layouts, spacing, color, typography.

## Frame

Standard modern-minimal frame: 240px nav, centered content, slide-out notes drawer. See `_frame.md` for the full frame reference.

## Preview rendering

The preview IS the content. Render the component at real size in a mock context. Use a `<div id="preview">` that applies state values directly to inline styles:

```javascript
function renderPreview() {
  const el = document.getElementById('preview');
  el.style.borderRadius = state.radius + 'px';
  el.style.padding = state.padding + 'px';
  el.style.fontSize = state.fontSize + 'px';
  el.style.fontWeight = state.weight;
  el.style.boxShadow = state.shadow > 0
    ? `0 ${state.shadow}px ${state.shadow*2}px rgba(15,17,21,0.12)`
    : 'none';
  el.style.background = state.bgColor;
  el.style.color = state.textColor;
}
```

## Controls

Floating glass panel overlays the preview. Minimal controls — only what this component needs:

```css
.controls {
  background: rgba(255,255,255,.92); backdrop-filter: blur(12px);
  border: 1px solid var(--line); padding: 16px;
  max-width: 260px;
  box-shadow: 0 8px 24px rgba(15,17,21,.08);
}
.controls label {
  display: flex; justify-content: space-between; align-items: center;
  font: 400 11px var(--font-mono); color: var(--text-dim); margin-bottom: 6px;
}
.controls label span { color: var(--text); }
.controls input[type=range] { accent-color: var(--accent); }
```

## Presets

3-5 named presets as clickable chips. Each snaps all controls:

```javascript
const presets = {
  Minimal:     { radius: 2,  padding: 12, shadow: 0, weight: 400 },
  Comfortable: { radius: 8,  padding: 20, shadow: 8, weight: 500 },
  Bold:        { radius: 14, padding: 24, shadow: 20, weight: 600 },
};
```

Active preset gets indigo fill.

## Typography display

When designing type, show the actual scale rendered:

```html
<div class="type-scale">
  <div class="type-row" style="font-size:42px;font-weight:600">Heading 1 — The quick brown fox</div>
  <div class="type-row" style="font-size:22px;font-weight:550">Heading 2 — Jumps over the lazy dog</div>
  <div class="type-row" style="font-size:17px;font-weight:400">Body — Lorem ipsum dolor sit amet, consectetur adipiscing elit.</div>
  <div class="type-row" style="font-size:11px;font-weight:500;font-family:var(--font-mono);text-transform:uppercase;letter-spacing:.6px">Caption — SECONDARY INFORMATION</div>
</div>
```

Each row shows font name, weight, size, and line-height in `var(--text-dim)` beside it.

## Color palette display

Swatches with hex values. Click to copy:

```html
<div class="palette">
  <div class="swatch" style="background:var(--accent)" onclick="copy('#4a6cff')">
    <span class="name">Accent</span><span class="hex">#4a6cff</span>
  </div>
</div>
```

## Notes

Click any part of the preview → flag it. Notes drawer shows "Element #3" with the note text. Prompt output collects all flagged elements into a natural design instruction.
