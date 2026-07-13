# SVG Diagram Template (`svg-diagram`)

Use when content IS a **diagram**: architecture, data flow, request/pipeline flow, sequence of components, state machine, dependency map — anything you'd draw as **boxes + arrows**. Produces a clean, auto-laid-out SVG in a bounded, **zoomable/pannable** viewport (not a heavy interactive graph — that's `code-map`).

## THE ONE RULE

**Never hand-write SVG `x`/`y` coordinates.** LLMs mis-place them — boxes overlap, arrows cut through nodes, labels spill out. This is a well-documented failure mode. Instead you **declare nodes and edges as data** and call `renderDiagram(spec)`; the embedded helper computes all coordinates deterministically (longest-path layering + word-wrap auto-sizing + edge routing). You author *what*, the helper handles *where*.

This also replaces the `<div>`-with-arrow-glyphs pattern: that's a fallback people reach for *because* raw-SVG coords are hard. With this helper, real SVG is easier than the div hack and looks far better.

## Readability model (why this version has zoom + wrap)

A wide `LR` flow has a large intrinsic width. If you force it to `width:100%` inside a narrow column, the browser **shrinks the whole SVG** and the text becomes microscopic — the #1 reason hand-rolled SVG diagrams read badly. This helper fixes that structurally:

- **Fonts never shrink below legible.** The SVG renders at (near) natural pixel size; it is **not** squished to the column width. Instead the diagram lives in a **bounded viewport** (`max-width` + `max-height`) that **scrolls and zooms**.
- **Fit-to-width, floored.** On mount it auto-fits to the container but never below ~70% scale — past that it scrolls rather than turning text to mush.
- **Zoom controls** — `+ / − / Fit / 1:1` buttons, ⌘/Ctrl+wheel to zoom (cursor-anchored), drag to pan. Zero-dependency, inline.
- **Labels word-wrap** — long `label`/`sub` text wraps onto multiple lines inside a sensibly-capped node width instead of forcing a 400px-wide box or overflowing.

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
  - `label` — supports `\n` for hard line breaks; long lines also **auto-wrap** on word boundaries. `sub` — small caption under the label (also wraps).
  - `kind` — semantic style: `process`/`rounded` (indigo, default for named steps), `box` (slate, plain), `data`/`store`/`cylinder` (green DB), `decision`/`diamond` (amber), `external` (red, edge of system), `pill`/`start`/`end` (indigo capsule), `note` (muted). Unknown maps to default.
  - `layer?` — force a column/row index (0-based). Omit to let longest-path layering decide.
- **edge**: `{ from, to, label?, kind? }` — `kind`: `solid` (default), `dashed`, `dotted`, `thick`. `label` sits at the edge midpoint with a small background chip.
- **spec options**: `dir` (`LR`/`TB`), `gapX`, `gapY` (spacing overrides), `width` (max viewport px, default 900), `maxHeight` (viewport px before it scrolls, default 520), `wrap` (max chars per label line before wrapping, default 22).

### Guidance

- **Keep to ~15 nodes per diagram.** More than that is unreadable even hand-drawn — split into multiple `renderDiagram` calls (multiple mounts), one per concern. Zoom/scroll is a safety net for the occasional wide flow, not a license for 40-node monsters.
- **Direction:** `LR` for request/data flows and pipelines; `TB` for hierarchies / org-style trees / layered stacks. `TB` often reads better than `LR` when there are many layers (a tall diagram scrolls more naturally in a document column than a very wide one).
- **Let layering work:** just declare edges in logical order and omit `layer`. Only set `layer` to force alignment (e.g., put two peers in the same column).
- **Colors are semantic, not decorative:** external systems red, decisions amber, data stores green, your components indigo. Consistency across a page reads as one system.
- Multiple diagrams per page is normal and good — a page of 3-4 focused flows beats one 30-node monster. Each mount gets its own independent zoom/pan controls.

## The helper (embed verbatim; theme-aware via CSS vars, dark-mode safe; zero-dependency)

```html
<script>
function renderDiagram(spec, mountId){
  const dir = spec.dir || 'LR';
  const nodes = spec.nodes || [], edges = (spec.edges||[]).filter(e=>e.from&&e.to);
  const byId = {}; nodes.forEach(n=>byId[n.id]=n);
  const gapMain = spec.gapX != null ? spec.gapX : (dir==='LR'?96:70);
  const gapCross= spec.gapY != null ? spec.gapY : (dir==='LR'?30:40);
  const PAD=20, MAXW=spec.width||900, MAXH=spec.maxHeight||520, WRAP=spec.wrap||22;
  const FS=14, LH=19, SUBFS=11.5, SUBLH=15;   // legible base fonts (never shrunk below this on screen)

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

  // word-wrap: honor explicit \n, then wrap each line to <= max chars on word boundaries
  const wrap = (s,max) => String(s).split('\n').flatMap(line=>{
    const words=line.split(/\s+/).filter(Boolean); const out=[]; let cur='';
    for(const w of words){ if(!cur) cur=w; else if((cur+' '+w).length<=max) cur+=' '+w; else { out.push(cur); cur=w; } }
    if(cur) out.push(cur); return out.length?out:[''];
  });

  // 1. longest-path layering (roots at layer 0), memoized + cycle-guarded
  const radj={}; nodes.forEach(n=>radj[n.id]=[]);
  edges.forEach(e=>{ if(byId[e.from]&&byId[e.to]) radj[e.to].push(e.from); });
  const layer={};
  const place=(id,seen)=>{ if(layer[id]!=null)return layer[id]; if(seen.has(id))return 0;
    seen.add(id); let L=0; for(const p of radj[id]) L=Math.max(L,place(p,seen)+1); seen.delete(id);
    return layer[id]=L; };
  nodes.forEach(n=> n.layer!=null ? layer[n.id]=n.layer : place(n.id,new Set()));

  // 2. wrap + size each node from its (wrapped) text
  nodes.forEach(n=>{
    n._lines = wrap(n.label, WRAP);
    n._sub   = n.sub ? wrap(n.sub, WRAP+6) : [];
    const chars=Math.max(...n._lines.map(l=>l.length), ...n._sub.map(l=>l.length), 3);
    n._w=Math.max(96, Math.min(300, Math.round(chars*8.2)+34));
    n._h=18 + n._lines.length*LH + (n._sub.length? n._sub.length*SUBLH+4 : 0);
    if(n.kind==='decision'||n.kind==='diamond'){ n._w=Math.max(n._w,120); n._h=Math.max(n._h,72); }
  });

  // 3. group by layer (declaration order preserved within a layer)
  const layers={}; nodes.forEach(n=>(layers[layer[n.id]]=layers[layer[n.id]]||[]).push(n));
  const Ls=Object.keys(layers).map(Number).sort((a,b)=>a-b);
  const mainOf=n=>dir==='LR'?n._w:n._h, crossOf=n=>dir==='LR'?n._h:n._w;
  let m=PAD; const layerMain={};
  Ls.forEach(L=>{ layerMain[L]=m; m+=Math.max(...layers[L].map(mainOf))+gapMain; });
  const layerCross={};
  Ls.forEach(L=>{ let c=0; layers[L].forEach(n=>{ n._c=c; c+=crossOf(n)+gapCross; }); layerCross[L]=c-gapCross; });
  const maxCross=Math.max(0,...Ls.map(L=>layerCross[L]));
  Ls.forEach(L=>{ const off=(maxCross-layerCross[L])/2; layers[L].forEach(n=>{
    if(dir==='LR'){ n.x=layerMain[L]; n.y=PAD+off+n._c; } else { n.y=layerMain[L]; n.x=PAD+off+n._c; }
  });});
  const W=(dir==='LR'? m-gapMain : PAD+maxCross)+PAD;
  const H=(dir==='LR'? PAD+maxCross : m-gapMain)+PAD;

  // 4. shape + text builders
  const esc=s=>String(s).replace(/[&<>]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;'}[c]));
  function shape(n){
    const c=col(n), x=n.x,y=n.y,w=n._w,h=n._h, k=n.kind;
    const base=`fill="${c.f}" stroke="${c.s}" stroke-width="1.6"`;
    if(k==='decision'||k==='diamond')
      return `<polygon points="${x+w/2},${y} ${x+w},${y+h/2} ${x+w/2},${y+h} ${x},${y+h/2}" ${base}/>`;
    if(k==='data'||k==='store'||k==='cylinder'){ const ry=7;
      return `<path d="M${x},${y+ry} a${w/2},${ry} 0 0 1 ${w},0 v${h-2*ry} a${w/2},${ry} 0 0 1 ${-w},0 Z" ${base}/>`
        +`<ellipse cx="${x+w/2}" cy="${y+ry}" rx="${w/2}" ry="${ry}" fill="none" stroke="${c.s}" stroke-width="1.6"/>`; }
    const rx=(k==='pill'||k==='start'||k==='end')?h/2:(k==='box'||k==='note'?4:12);
    return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" ${base}/>`;
  }
  function text(n){
    const cx=n.x+n._w/2;
    const total=n._lines.length*LH + (n._sub.length? n._sub.length*SUBLH+4 : 0);
    let ty=n.y+n._h/2-total/2+FS-1;
    let out=n._lines.map(l=>{const t=`<text x="${cx}" y="${ty}" text-anchor="middle" font-size="${FS}" font-weight="600" fill="var(--fg,#1b1d22)" font-family="var(--font-body,system-ui,sans-serif)">${esc(l)}</text>`;ty+=LH;return t;}).join('');
    if(n._sub.length){ ty+=2; out+=n._sub.map(l=>{const t=`<text x="${cx}" y="${ty}" text-anchor="middle" font-size="${SUBFS}" fill="var(--muted,#6b7280)" font-family="var(--font-mono,ui-monospace,monospace)">${esc(l)}</text>`;ty+=SUBLH;return t;}).join(''); }
    return out;
  }
  // 5. edges — smooth curve from source out-anchor to target in-anchor
  const anc=(n,out)=> dir==='LR'
    ? [out?n.x+n._w:n.x, n.y+n._h/2]
    : [n.x+n._w/2, out?n.y+n._h:n.y];
  function edge(e){
    const s=byId[e.from],t=byId[e.to]; if(!s||!t)return '';
    const a=anc(s,true),b=anc(t,false); const sx=a[0],sy=a[1],tx=b[0],ty=b[1];
    const d=Math.max(24, (dir==='LR'?Math.abs(tx-sx):Math.abs(ty-sy))/2);
    const path=dir==='LR'
      ? `M${sx},${sy} C${sx+d},${sy} ${tx-d},${ty} ${tx},${ty}`
      : `M${sx},${sy} C${sx},${sy+d} ${tx},${ty-d} ${tx},${ty}`;
    const k=e.kind||'solid';
    const dash=k==='dashed'?'stroke-dasharray="7,4"':k==='dotted'?'stroke-dasharray="1.5,4"':'';
    const wdt=k==='thick'?2.6:1.6;
    let out=`<path d="${path}" fill="none" stroke="var(--muted,#8a8f99)" stroke-width="${wdt}" ${dash} marker-end="url(#dgm-arrow)"/>`;
    if(e.label){ const mx=(sx+tx)/2,my=(sy+ty)/2, lw=e.label.length*6.4+12;
      out+=`<rect x="${mx-lw/2}" y="${my-10}" width="${lw}" height="18" rx="4" fill="var(--surface,#fff)" opacity="0.94"/>`
        +`<text x="${mx}" y="${my+3.5}" text-anchor="middle" font-size="11.5" fill="var(--muted,#6b7280)" font-family="var(--font-mono,ui-monospace,monospace)">${esc(e.label)}</text>`; }
    return out;
  }

  const svg=`<svg viewBox="0 0 ${W} ${H}" width="${W}" height="${H}" style="display:block" xmlns="http://www.w3.org/2000/svg">
    <defs><marker id="dgm-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse">
      <path d="M0,0 L10,5 L0,10 z" fill="var(--muted,#8a8f99)"/></marker></defs>
    ${edges.map(edge).join('')}
    ${nodes.map(n=>shape(n)+text(n)).join('')}
  </svg>`;

  // 6. bounded, zoomable, pannable viewport (no external deps)
  const bs='font:inherit;cursor:pointer;border:1px solid var(--border,#e5e7eb);background:var(--surface,#fff);color:var(--fg,#333);border-radius:6px;padding:2px 9px;min-width:26px;line-height:1.5';
  const btn=(z,t)=>`<button type="button" data-dgm="${z}" style="${bs}">${t}</button>`;
  const html=`<div class="dgm-wrap" style="position:relative;max-width:${MAXW}px;margin:10px auto;border:1px solid var(--border,#e5e7eb);border-radius:12px;background:var(--surface,#fff);overflow:hidden">
    <div style="display:flex;align-items:center;gap:6px;padding:6px 8px;border-bottom:1px solid var(--border,#eee);font-size:12px;color:var(--muted,#6b7280)">
      ${btn('out','&minus;')}${btn('in','+')}${btn('fit','Fit')}${btn('reset','1:1')}
      <span data-dgm="pct" style="font-family:var(--font-mono,ui-monospace,monospace);min-width:40px;text-align:center">100%</span>
      <span style="margin-left:auto;opacity:.85">drag to pan &middot; &#8984;/Ctrl+scroll to zoom</span>
    </div>
    <div data-dgm="vp" style="overflow:auto;max-height:${MAXH}px;cursor:grab;background:var(--bg,#fbfbfd)">${svg}</div>
  </div>`;
  const el=document.getElementById(mountId); if(!el) return svg; el.innerHTML=html;

  // 7. wire controls (scoped to this mount)
  const wrapEl=el.querySelector('.dgm-wrap'), vp=el.querySelector('[data-dgm=vp]');
  const svgEl=vp.querySelector('svg'), pct=el.querySelector('[data-dgm=pct]');
  const MIN=0.4, MAX=4; let scale=1;
  const avail=()=>Math.max(120,(vp.clientWidth||MAXW)-2);
  const fitScale=()=>Math.min(1, Math.max(0.7, avail()/W));   // fit to width, floored at 70% (scroll beyond)
  function apply(){ scale=Math.max(MIN,Math.min(MAX,scale));
    svgEl.setAttribute('width',(W*scale).toFixed(0)); svgEl.setAttribute('height',(H*scale).toFixed(0));
    if(pct) pct.textContent=Math.round(scale*100)+'%'; }
  scale=fitScale(); apply();
  wrapEl.querySelectorAll('button[data-dgm]').forEach(b=>b.addEventListener('click',()=>{
    const a=b.getAttribute('data-dgm');
    if(a==='in') scale*=1.2; else if(a==='out') scale/=1.2; else if(a==='reset') scale=1; else if(a==='fit') scale=fitScale();
    apply();
  }));
  vp.addEventListener('wheel',e=>{ if(!(e.ctrlKey||e.metaKey))return; e.preventDefault();
    const r=vp.getBoundingClientRect(), px=e.clientX-r.left+vp.scrollLeft, py=e.clientY-r.top+vp.scrollTop, old=scale;
    scale*= e.deltaY<0?1.12:1/1.12; apply(); const k=scale/old;
    vp.scrollLeft=px*k-(e.clientX-r.left); vp.scrollTop=py*k-(e.clientY-r.top);
  },{passive:false});
  let drag=false,dx,dy,sl,st;
  vp.addEventListener('mousedown',e=>{ if(e.button!==0)return; drag=true; dx=e.clientX; dy=e.clientY; sl=vp.scrollLeft; st=vp.scrollTop; vp.style.cursor='grabbing'; e.preventDefault(); });
  window.addEventListener('mousemove',e=>{ if(!drag)return; vp.scrollLeft=sl-(e.clientX-dx); vp.scrollTop=st-(e.clientY-dy); });
  window.addEventListener('mouseup',()=>{ if(drag){ drag=false; vp.style.cursor='grab'; } });
  return svg;
}
</script>
```

## Why this beats the alternatives here

- **vs raw hand-authored SVG** — removes the coordinate-hallucination failure mode entirely; the agent never writes an `x`/`y`.
- **vs Mermaid/PlantUML** — those need an external renderer (CDN/Kroki), breaking the skill's "single self-contained HTML, no required external dependencies" rule. This helper is ~140 lines, inline, zero-dep.
- **vs `<div>` flex + arrow glyphs** — real shapes (decision diamonds, data cylinders), routed arrows, edge labels, semantic color; and it's actually *less* work to author (just data).
- **vs squished `width:100%` SVG** — that shrinks text to nothing on wide flows. This renders at legible size in a zoom/pan viewport instead.
- **vs `code-map`** — `code-map` is the heavy interactive draggable/zoomable graph explorer. `svg-diagram` is the lightweight "here's how it works" picture you drop into a doc or section (now with a light zoom/pan viewport so wide flows stay readable). Use `svg-diagram` by default for design/data-flow; reach for `code-map` only when the user needs to explore a large graph interactively.

Sources: [Why AI agents can't draw SVG](https://dev.to/msteja/why-ai-agents-cant-draw-svg-and-what-to-do-instead-1ci) - [svg-pan-zoom-container (zero-dep viewport transform)](https://www.npmjs.com/package/svg-pan-zoom-container) - [See it. Say it. Sorted (compositional diagram gen)](https://ar5iv.labs.arxiv.org/html/2508.15222) - [SVG-vs-Mermaid-vs-Excalidraw skill design](https://dev.classmethod.jp/articles/build-svg-diagram-skill-for-claude-code/)
