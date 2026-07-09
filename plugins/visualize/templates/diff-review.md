# Diff Review Template

Use when content is code changes: git diffs, patches, PRs, before/after.

## Frame

Same modern-minimal frame as the other templates: 240px nav, centered content, slide-out notes drawer. Fonts: system mono + system body. Indigo accent. See `_frame.md` for the full frame CSS/HTML reference.

## Diff-specific content

### File header

Each file is a collapsible card. Mono for paths and stats:

```html
<div class="file-card">
  <div class="file-header" onclick="toggleFile(this)">
    <span class="file-path">src/utils/handler.py</span>
    <span class="file-stats"><span class="add">+12</span> <span class="del">-3</span></span>
    <span class="collapse-icon">▾</span>
  </div>
  <div class="file-diff"><!-- hunks --></div>
</div>
```

```css
.file-card { margin-bottom: 12px; border: 1px solid var(--line); background: var(--raised); }
.file-header { padding: 10px 14px; cursor: pointer; display: flex; align-items: center; gap: 12px;
  font-family: var(--font-mono); font-size: 12px; }
.file-header:hover { background: rgba(15,17,21,.015); }
.file-header .add { color: var(--green); }
.file-header .del { color: var(--red); }
```

### Line rendering

Mono 13px, left border + subtle tint:

```css
.diff-line { display: flex; font: 400 13px/1.55 var(--font-mono); padding: 0; }
.diff-line .ln { width: 50px; text-align: right; padding: 1px 12px 1px 0; color: var(--text-dim); user-select: none; flex-shrink: 0; }
.diff-line .content { flex: 1; white-space: pre-wrap; padding: 1px 8px; }

.diff-line.add { background: rgba(31,157,87,.08); border-left: 3px solid var(--green); }
.diff-line.del { background: rgba(214,58,74,.08); border-left: 3px solid var(--red); }
.diff-line.ctx { border-left: 3px solid transparent; }

.diff-line:hover { background: rgba(74,108,255,.05); cursor: pointer; }
.diff-line.has-comment::after { content: '●'; color: var(--accent); margin-left: 8px; font-size: 8px; }
```

### Inline comments

Click a line → comment box slides open below it, bordered indigo:

```css
.comment-box { margin: 0 0 0 50px; padding: 10px 14px;
  background: var(--raised); border: 1px solid var(--line); border-left: 3px solid var(--accent-dim); }
.comment-box textarea { width: 100%; background: var(--bg); border: 1px solid var(--line);
  color: var(--text); font: 400 13px var(--font-body); padding: 8px; resize: vertical; min-height: 50px; }
.comment-box textarea:focus { outline: none; border-color: var(--accent-dim); }
.comment-box button { padding: 6px 14px; border: 1px solid var(--accent-dim); background: transparent;
  color: var(--accent); cursor: pointer; font: 500 10px var(--font-mono); text-transform: uppercase; letter-spacing: .6px; }
```

### File stat header

Above the diff, a compact stat bar with file chips:

```
src/utils/handler.py  +12  -3  ● 3 comments
src/api/routes.ts     +45 -18  ● 1 comment
```

Each chip is mono 11px. The `●` indigo dot shows comment count.

### Notes

Same drawer system. Click a diff line → comment is pinned to that line. All line comments also appear in the notes drawer with file:line references.
