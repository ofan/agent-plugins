# Code Map Template

Use when content describes system structure: architecture, components, data flow, dependency maps.

## Frame

Standard modern-minimal frame: 240px nav, centered content, slide-out notes drawer. See `_frame.md` for the full frame reference.

## SVG canvas

The diagram is an inline `<svg>` element within the content area. It fills the available width (max 780px) with a fixed height (typically 500-700px depending on node count).

```html
<svg id="diagram" viewBox="0 0 780 600" style="width:100%;height:auto;background:var(--raised);border:1px solid var(--line)">
  <!-- nodes + edges -->
</svg>
```

## Node rendering

Rounded rects with the same color palette. Size encodes importance:

```javascript
const layerColors = {
  client:  { fill: 'rgba(74,108,255,0.10)',  stroke: '#4a6cff' },  /* indigo */
  server:  { fill: 'rgba(139,92,246,0.10)',  stroke: '#8b5cf6' },  /* violet */
  core:    { fill: 'rgba(82,88,102,0.10)',   stroke: '#525866' },  /* slate */
  data:    { fill: 'rgba(31,157,87,0.10)',   stroke: '#1f9d57' },  /* green */
  external:{ fill: 'rgba(214,58,74,0.10)',   stroke: '#d63a4a' },  /* red */
};

function drawNode(n) {
  const w = n.importance === 'core' ? 150 : 120;
  const h = n.importance === 'core' ? 52 : 42;
  const rx = 6;
  const c = layerColors[n.layer];
  return `<rect x="${n.x}" y="${n.y}" width="${w}" height="${h}" rx="${rx}"
    fill="${c.fill}" stroke="${c.stroke}" stroke-width="1.5"
    class="node" data-id="${n.id}" onclick="selectNode('${n.id}')"/>
    <text x="${n.x + w/2}" y="${n.y + 22}" text-anchor="middle"
      font-family="var(--font-body)" font-size="14" font-weight="550"
      fill="var(--text)">${n.label}</text>
    <text x="${n.x + w/2}" y="${n.y + h - 14}" text-anchor="middle"
      font-family="var(--font-mono)" font-size="10"
      fill="var(--text-dim)">${n.subtitle || ''}</text>`;
}
```

## Edge rendering

Bezier paths with arrowheads. Color per relationship type, stroke-dasharray per type:

```javascript
const edgeStyles = {
  'data-flow':  { stroke: '#4a6cff', width: 2, dash: '' },      /* indigo */
  'call':       { stroke: '#1f9d57', width: 1.5, dash: '6,3' }, /* green */
  'event':      { stroke: '#d63a4a', width: 1.5, dash: '4,4' }, /* red */
  'dependency': { stroke: '#71747e', width: 1, dash: '2,4' },   /* muted */
};
```

Arrow marker defs in SVG `<defs>`. Label at edge midpoint in mono 9px `var(--text-dim)`.

## Interaction

- Click node → indigo border highlight + inline note field below the SVG
- Shift+click two nodes → draw edge between them
- Double-click empty → pan canvas

## Notes

Clicking a node opens the notes drawer with the node name pre-filled as the section. Node-specific notes render as indigo dots on the node.
