# Concept Map Template

Use when content is about concepts and relationships: taxonomies, knowledge graphs, logic flows, sequences, pipelines.

## Frame

Standard modern-minimal frame: 240px nav, centered content, slide-out notes drawer. See `_frame.md` for the full frame reference.

## Two modes

### Graph mode — concepts with relationships

SVG canvas with draggable nodes and directional edges. Same node/edge rendering as code-map (see `code-map.md` for draw functions).

Nodes vary in importance: core (150×52), major (130×44), minor (100×36). Shape varies by category:

| Category | rx | Use |
|----------|----|-----|
| concept | 18 | ideas, abstract concepts |
| system | 6 | concrete systems, components |
| process | 12 | actions, transformations |

Color categories use the same palette:
```javascript
const catColors = {
  structure:  { stroke: '#4a6cff' },  /* indigo */
  behavior:   { stroke: '#1f9d57' },  /* green */
  data:       { stroke: '#d97706' },  /* amber */
  interface:  { stroke: '#8b5cf6' },  /* violet */
  constraint: { stroke: '#d63a4a' },  /* red */
};
```

### Flow mode — sequences and pipelines

Linear layout. Steps arranged left-to-right with directional arrows. Step number in a border circle:

```css
.flow-step { display: flex; gap: 16px; align-items: flex-start; margin-bottom: 20px; }
.flow-step .num { min-width: 30px; height: 30px; border: 1px solid var(--line-strong);
  display: flex; align-items: center; justify-content: center;
  font: 500 12px var(--font-mono); color: var(--text-dim); flex-shrink: 0; }
.flow-step .body { flex: 1; }
.flow-step .connector { width: 2px; height: 20px; background: var(--line); margin: 4px auto; }
```

## Interaction

- **Drag** nodes to reposition
- **Click** node → select + open notes drawer
- **Shift+click** two nodes → create edge
- **Wheel** to zoom canvas (graph mode)

## Notes

Same drawer system. Click a node → notes drawer opens with node name pre-selected. Node gets an indigo dot when annotated.
