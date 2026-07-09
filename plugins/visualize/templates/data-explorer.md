# Data Explorer Template

Use when content is structured data: tables, JSON arrays, CSVs, query results, metrics comparisons.

## Frame

Standard modern-minimal frame: 240px nav, centered content, slide-out notes drawer. See `_frame.md` for the full frame reference.

## Table rendering

Minimal borders, alternating row backgrounds, mono for values, body for headers:

```css
.data-table { width: 100%; border-collapse: collapse; font-size: 14px; }
.data-table th {
  position: sticky; top: 0; background: var(--surface);
  font: 500 10px var(--font-mono); text-transform: uppercase; letter-spacing: .8px;
  color: var(--text-dim); padding: 8px 12px; text-align: left;
  border-bottom: 2px solid var(--line-strong); cursor: pointer;
}
.data-table th.sorted { color: var(--accent); }
.data-table td {
  padding: 7px 12px; border-bottom: 1px solid var(--line);
  font: 400 13px/1.5 var(--font-mono);
}
.data-table tr:nth-child(even) td { background: rgba(15,17,21,.015); }
.data-table tr:hover td { background: rgba(74,108,255,.04); }

/* Number alignment */
.data-table td.num { text-align: right; font-variant-numeric: tabular-nums; }
.data-table td.boolean { text-align: center; }
.data-table td.boolean.true { color: var(--green); }
.data-table td.boolean.false { color: var(--red); }
```

## Cell formatting

| Type | Align | Font | Format |
|------|-------|------|--------|
| Number | Right | mono | `toLocaleString()` 2 decimals |
| Percentage | Right | mono | Bar behind (width = %) |
| Date | Left | mono | Relative (<7d) or absolute |
| Text | Left | body | Truncate at 200 chars, expand on click |
| Boolean | Center | mono | ✓ green / ✗ red |
| Code | Left | mono | Accent color |

## Filters

Chip-style above the table. Active filters filled amber:

```css
.filter-row { display: flex; gap: 8px; margin-bottom: 16px; flex-wrap: wrap; }
.filter-chip { padding: 4px 12px; border: 1px solid var(--line); background: transparent;
  color: var(--text-dim); cursor: pointer; font: 400 12px var(--font-mono); }
.filter-chip.active { background: rgba(74,108,255,.1); border-color: var(--accent-dim); color: var(--accent); }
```

## Summary footer

One line of stats below the table. Mono 11px, `var(--text-dim)`:

```
Showing 342 rows · 12 columns · 3 annotations
```

## Notes

Click any cell → annotate with a note. Annotated cells show a subtle amber underline. All annotations appear in the notes drawer with row/column reference.
