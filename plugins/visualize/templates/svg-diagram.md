# SVG Diagram Template (`svg-diagram`)

Use when content IS a **diagram**: architecture, data flow, request/pipeline flow, sequence of components, state machine, dependency map — anything you'd draw as **boxes + arrows**. Produces a clean, static, auto-laid-out SVG (not an interactive graph — that's `code-map`).

## THE ONE RULE

**Never hand-write SVG `x`/`y` coordinates.** LLMs mis-place them — boxes overlap, arrows cut through nodes, labels spill out. This is a well-documented failure mode. Instead you **declare nodes and edges as data** and call `renderDiagram(spec)`; the embedded helper computes all coordinates deterministically (longest-path layering + auto-sizing + edge routing). You author *what*, the helper handles *where*.

This also replaces the `<div>`-with-arrow-glyphs pattern: that's a fallback people reach for *because* raw-SVG coords are hard. With this helper, real SVG is easier than the div hack and looks far better.

## How to use

1. Start from `generic-render` (a clean light page) or embed inside any page/section.
2. Drop in the `<script>` helper below (once per page).
3. Add a mount element: `<div id="d1"></div>`.
4. Call `renderDiagram(spec, 'd1')` with your declarative spec. That's the only thing you author.

```html
<div id="d1"></div>
<script>
renderDiagram({
  dir: 'LR',                          // 'LR' (flow, default) or 'TB' (hierarchy)
  nodes: [
    { id: 'client', label: 'Client',        kind: 'external' },
    { id: 'proxy',  label: 'Proxy',  sub: 'router + auth', kind: 'process' },
    { id: 'route',  label: 'resolveModel?',  kind: 'decision' },
    { id: 'a',      label: 'Backend A' },
    { id: 'b',      label: 'Backend B' },
    { id: 'db',     label: 'Store',           kind: 'data' },
  ],
  edges: [
    { from: 'client', to: 'proxy', label: 'request' },
    { from: 'proxy',  to: 'route' },
    { from: 'route',  to: 'a', label: 'match' },
    { from: 'route',  to: 'b', label: 'wildcard', kind: 'dashed' },
    { from: 'proxy',  to: 'db', kind: 'dotted', label: 'usage' },
  ],
}, 'd1');
</script>
```

### Spec reference

- **node**: `{ id, label, sub?, kind?, layer? }`
  - `label` — supports `\n` for multi-line. `sub` — small caption line under the label.
  - `kind` — semantic style: `process`/`rounded` (indigo, default for named steps), `box` (slate, plain), `data`/`store`/`cylinder` (green DB), `decision`/`diamond` (amber), `external` (red, edge of system), `pill`/`start`/`end` (indigo capsule), `note` (muted). Unknown maps to default.
  - `layer?` — force a column/row index (0-based). Omit to let longest-path layering decide.
- **edge**: `{ from, to, label?, kind? }` — `kind`: `solid` (default), `dashed`, `dotted`, `thick`. `label` sits at the edge midpoint with a small background chip.
- **spec options**: `dir` (`LR`/`TB`), `gapX`, `gapY` (spacing overrides), `width` (max px, default 860).

### Guidance

- **Keep to ~15 nodes per diagram.** More than that is unreadable even hand-drawn — split into multiple `renderDiagram` calls (multiple mounts), one per concern.
- **Direction:** `LR` for request/data flows and pipelines; `TB` for hierarchies / org-style trees / layered stacks.
- **Let layering work:** just declare edges in logical order and omit `layer`. Only set `layer` to force alignment (e.g., put two peers in the same column).
- **Colors are semantic, not decorative:** external systems red, decisions amber, data stores green, your components indigo. Consistency across a page reads as one system.
- Multiple diagrams per page is normal and good — a page of 3-4 focused flows beats one 30-node monster.

## The helper (embed verbatim; theme-aware via CSS vars, dark-mode safe)

```html
<script>
function renderDiagram(spec, mountId){
  const dir = spec.dir || 'LR';
  const nodes = spec.nodes || [], edges = (spec.edges||[]).filter(e=>e.from&&e.to);
  const byId = {}; nodes.forEach(n=>byId[n.id]=n);
  const gapMain = spec.gapX != null ? spec.gapX : (dir==='LR'?92:64);
  const gapCross= spec.gapY != null ? spec.gapY : (dir==='LR'?24:34);
  const PAD=18, MAXW=spec.width||860;

  // palette (oklch, matches modern-minimal; saturated strokes read on light+dark)
  const P={
    accent:{s:'oklch(58% 0.18 255)', f:'oklch(96% 0.03 255)'},
    green :{s:'oklch(60% 0.15 150)', f:'oklch(95% 0.04 150)'},
    amber :{s:'oklch(66% 0.15 78)',  f:'oklch(96% 0.05 78)'},
    red   :{s:'oklch(56% 0.20 22)',  f:'oklch(96% 0.03 22)'},
    slate :{s:'oklch(52% 0.02 255)', f:'oklch(96% 0.006 255)'},
  };
  const KIND={ process:'accent', rounded:'accent', pill:'accent', start:'accent', end:'accent',
    box:'slate', note:'slate', data:'green', store:'green', cylinder:'green',
    decision:'amber', diamond:'amber', external:'red', error:'red' };
  const col = n => P[KIND[n.kind]||'slate'];

  // 1. longest-path layering (roots at layer 0), memoized + cycle-guarded
  const radj={}; nodes.forEach(n=>radj[n.id]=[]);
  edges.forEach(e=>{ if(byId[e.from]&&byId[e.to]) radj[e.to].push(e.from); });
  const layer={};
  const place=(id,seen)=>{ if(layer[id]!=null)return layer[id]; if(seen.has(id))return 0;
    seen.add(id); let L=0; for(const p of radj[id]) L=Math.max(L,place(p,seen)+1); seen.delete(id);
    return layer[id]=L; };
  nodes.forEach(n=> n.layer!=null ? layer[n.id]=n.layer : place(n.id,new Set()));

  // 2. size each node from its text (deterministic estimate; supports \n + sub)
  nodes.forEach(n=>{
    const lines=String(n.label).split('\n');
    const chars=Math.max(...lines.map(l=>l.length), n.sub?String(n.sub).length:0);
    n._w=Math.max(88, Math.min(230, Math.round(chars*7.6)+30));
    n._h=26+lines.length*16+(n.sub?13:0);
    if(n.kind==='decision'||n.kind==='diamond'){ n._w=Math.max(n._w,110); n._h=Math.max(n._h,64); }
  });

  // 3. group by layer (declaration order preserved within a layer)
  const layers={}; nodes.forEach(n=>(layers[layer[n.id]]=layers[layer[n.id]]||[]).push(n));
  const Ls=Object.keys(layers).map(Number).sort((a,b)=>a-b);
  const mainOf=n=>dir==='LR'?n._w:n._h, crossOf=n=>dir==='LR'?n._h:n._w;

  // main axis: columns (LR) / rows (TB) placed by max extent per layer
  let m=PAD; const layerMain={};
  Ls.forEach(L=>{ layerMain[L]=m; m+=Math.max(...layers[L].map(mainOf))+gapMain; });
  // cross axis: stack within a layer, then center each layer against the widest
  const layerCross={};
  Ls.forEach(L=>{ let c=0; layers[L].forEach(n=>{ n._c=c; c+=crossOf(n)+gapCross; }); layerCross[L]=c-gapCross; });
  const maxCross=Math.max(0,...Ls.map(L=>layerCross[L]));
  Ls.forEach(L=>{ const off=(maxCross-layerCross[L])/2; layers[L].forEach(n=>{
    if(dir==='LR'){ n.x=layerMain[L]; n.y=PAD+off+n._c; } else { n.y=layerMain[L]; n.x=PAD+off+n._c; }
  });});
  const W=(dir==='LR'? m-gapMain : PAD+maxCross)+PAD;
  const H=(dir==='LR'? PAD+maxCross : m-gapMain)+PAD;

  // 4. shape builders
  const esc=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
  function shape(n){
    const c=col(n), x=n.x,y=n.y,w=n._w,h=n._h, k=n.kind;
    const base=`fill="${c.f}" stroke="${c.s}" stroke-width="1.5"`;
    if(k==='decision'||k==='diamond')
      return `<polygon points="${x+w/2},${y} ${x+w},${y+h/2} ${x+w/2},${y+h} ${x},${y+h/2}" ${base}/>`;
    if(k==='data'||k==='store'||k==='cylinder'){ const ry=7;
      return `<path d="M${x},${y+ry} a${w/2},${ry} 0 0 1 ${w},0 v${h-2*ry} a${w/2},${ry} 0 0 1 ${-w},0 Z" ${base}/>`
        +`<ellipse cx="${x+w/2}" cy="${y+ry}" rx="${w/2}" ry="${ry}" fill="none" stroke="${c.s}" stroke-width="1.5"/>`; }
    const rx=(k==='pill'||k==='start'||k==='end')?h/2:(k==='box'||k==='note'?4:11);
    return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" ${base}/>`;
  }
  function text(n){
    const lines=String(n.label).split('\n'); const cx=n.x+n._w/2;
    const total=lines.length*16+(n.sub?13:0); let ty=n.y+n._h/2-total/2+13;
    let out=lines.map(l=>{const t=`<text x="${cx}" y="${ty}" text-anchor="middle" font-size="13" font-weight="600" fill="var(--fg,#1b1d22)" font-family="var(--font-body,system-ui,sans-serif)">${esc(l)}</text>`;ty+=16;return t;}).join('');
    if(n.sub) out+=`<text x="${cx}" y="${ty+1}" text-anchor="middle" font-size="10.5" fill="var(--muted,#6b7280)" font-family="var(--font-mono,ui-monospace,monospace)">${esc(n.sub)}</text>`;
    return out;
  }
  // 5. edges — smooth curve from source out-anchor to target in-anchor
  const anc=(n,out)=> dir==='LR'
    ? [out?n.x+n._w:n.x, n.y+n._h/2]
    : [n.x+n._w/2, out?n.y+n._h:n.y];
  function edge(e){
    const s=byId[e.from],t=byId[e.to]; if(!s||!t)return '';
    const a=anc(s,true),b=anc(t,false); const sx=a[0],sy=a[1],tx=b[0],ty=b[1];
    const d=Math.max(22, (dir==='LR'?Math.abs(tx-sx):Math.abs(ty-sy))/2);
    const path=dir==='LR'
      ? `M${sx},${sy} C${sx+d},${sy} ${tx-d},${ty} ${tx},${ty}`
      : `M${sx},${sy} C${sx},${sy+d} ${tx},${ty-d} ${tx},${ty}`;
    const k=e.kind||'solid';
    const dash=k==='dashed'?'stroke-dasharray="7,4"':k==='dotted'?'stroke-dasharray="1.5,4"':'';
    const wdt=k==='thick'?2.4:1.5;
    let out=`<path d="${path}" fill="none" stroke="var(--muted,#8a8f99)" stroke-width="${wdt}" ${dash} marker-end="url(#dgm-arrow)"/>`;
    if(e.label){ const mx=(sx+tx)/2,my=(sy+ty)/2, lw=e.label.length*6+10;
      out+=`<rect x="${mx-lw/2}" y="${my-9}" width="${lw}" height="16" rx="4" fill="var(--surface,#fff)" opacity="0.92"/>`
        +`<text x="${mx}" y="${my+3}" text-anchor="middle" font-size="10.5" fill="var(--muted,#6b7280)" font-family="var(--font-mono,ui-monospace,monospace)">${esc(e.label)}</text>`; }
    return out;
  }

  const svg=`<svg viewBox="0 0 ${W} ${H}" width="100%" style="max-width:${MAXW}px;height:auto;display:block;margin:8px auto" xmlns="http://www.w3.org/2000/svg">
    <defs><marker id="dgm-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--muted,#8a8f99)"/></marker></defs>
    ${edges.map(edge).join('')}
    ${nodes.map(n=>shape(n)+text(n)).join('')}
  </svg>`;
  const el=document.getElementById(mountId); if(el) el.innerHTML=svg; return svg;
}
</script>
```

## Why this beats the alternatives here

- **vs raw hand-authored SVG** — removes the coordinate-hallucination failure mode entirely; the agent never writes an `x`/`y`.
- **vs Mermaid/PlantUML** — those need an external renderer (CDN/Kroki), breaking the skill's "single self-contained HTML, no required external dependencies" rule. This helper is ~120 lines, inline, zero-dep.
- **vs `<div>` flex + arrow glyphs** — real shapes (decision diamonds, data cylinders), routed arrows, edge labels, semantic color; and it's actually *less* work to author (just data).
- **vs `code-map`** — `code-map` is the heavy interactive draggable/zoomable graph explorer. `svg-diagram` is the lightweight static "here's how it works" picture you drop into a doc or a section. Use `svg-diagram` by default for design/data-flow; reach for `code-map` only when the user needs to explore a large graph interactively.

Sources: [Why AI agents can't draw SVG](https://dev.to/msteja/why-ai-agents-cant-draw-svg-and-what-to-do-instead-1ci) - [AIGP AI Graphic Protocol](https://github.com/AIGraphia/aigp) - [See it. Say it. Sorted (compositional diagram gen)](https://ar5iv.labs.arxiv.org/html/2508.15222) - [SVG-vs-Mermaid-vs-Excalidraw skill design](https://dev.classmethod.jp/articles/build-svg-diagram-skill-for-claude-code/)
