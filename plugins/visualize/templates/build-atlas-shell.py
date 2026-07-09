#!/usr/bin/env python3
"""
Build atlas-shell.html from the Open Design artifact index.html
(co-located with this script in the visualize plugin's templates/ directory).

Usage (re-sync from Open Design):
    curl -sS 'http://design.lab.tf/api/projects/9f4c0a34-6f34-473c-b6b7-573d728a6241/files/index.html' \\
         -o /tmp/od-artifacts/index.html
    python3 build-atlas-shell.py

What this does (all idempotent, all asserted against the source):
  1. Inject HTML-comment guide markers into the body so the shell documents itself
     for the visualize skill (clone-and-fill rules, per-section pattern labels,
     nav-dot sync note).
  2. Apply the visualize patches (marked in the output with flag-banner comments):
       PATCH-1  page-scoped state key (location.pathname) so multiple reports on
                the same visualize origin don't collide on one annotation store.
       PATCH-2  persist per-section comments: push to state on post, render from
                state on load (via safe DOM methods), and persist the resolved flag.

The patches intentionally diverge from the Open Design source. Re-running this
script on a freshly-fetched index.html re-applies them, so re-sync never drops them.
"""
import os, sys

SRC = os.environ.get('ATLAS_SRC', '/tmp/od-artifacts/index.html')
HERE = os.path.dirname(os.path.abspath(__file__))
DST = os.environ.get('ATLAS_DST', os.path.join(HERE, 'atlas-shell.html'))

html = open(SRC, encoding='utf-8').read()


def replace_once(old, new, label):
    global html
    n = html.count(old)
    if n != 1:
        sys.exit(f'[{label}] expected exactly 1 match, found {n}')
    html = html.replace(old, new, 1)
    print(f'  applied: {label}')


# ── 1. Body guide markers ──────────────────────────────────────────────────

guide = """
<!-- =====================================================================
     ATLAS — AI Agent Report Viewer  ·  visualize template shell
     (drives the `document-critique` slot — see document-critique.md)
     ---------------------------------------------------------------------
     HOW TO RENDER (visualize skill):
       1. Copy this file to ~/.local/share/claude-visualize/pages/<slug>.html
            cp atlas-shell.html \\
               ~/.local/share/claude-visualize/pages/<slug>.html
       2. Update <title> and the .report-header (title + meta row) to the content.
       3. Replace each <section class="section"> below with ONE section per
          logical part of the user's content. Reuse the closest pattern — each
          section is labelled below (summary / spec-cards / diagram / table /
          checklist). Keep the section's classes and data-screen-label.
       4. Sync the .nav-rail button.nav-dot list: exactly one dot per section,
          in order, with matching data-section="N" and data-label.
       5. Section comments are auto-stripped on load, so a fresh clone starts
          empty. The seeded inline annotation highlights (a1..a5) and drawer
          cards are left as markup examples — clear them only if you want a
          fully bare page. Everything persists per-page to localStorage.
       6. Keep everything else byte-identical: the entire <style> block, the
          entire <script> block, and all chrome (nav rail, feedback drawer,
          annotation composer, appearance/settings panel).
     APPEARANCE PANEL (gear, top-right) ships at runtime:
       darkmode toggle · font-size (small/medium/large) · 5 style themes
       (modern-minimal default, brutalist-experimental, editorial-monocle,
       human-approachable, tech-utility). Persisted to localStorage:
       atlas-theme / atlas-font-size / atlas-style (global, intentional).
     FEEDBACK/COMMENTS persist per-page to localStorage (atlas-state:<pathname>)
     — see the flag-patch banners in the <script>.
     Self-contained single HTML — no server route needed.
     ===================================================================== -->

"""

nav_note = """<!-- NAV RAIL: one button.nav-dot per <section>, in order.
     data-section index (0-based) and data-label must match each section.
     Active dot gets class "nav-dot active". The first one is active by default. -->
"""

patterns = {
    'id="section-0"': 'SECTION 1 · pattern: SUMMARY / PROSE  (report-header + intro paragraphs)',
    'id="section-1"': 'SECTION 2 · pattern: SPEC CARDS  (requirements / decisions / finding cards)',
    'id="section-2"': 'SECTION 3 · pattern: ARCHITECTURE DIAGRAM  (nodes + edges / data flow)',
    'id="section-3"': 'SECTION 4 · pattern: DATA TABLE  (metrics / rows / comparison)',
    'id="section-4"': 'SECTION 5 · pattern: CHECKLIST  (steps / todos / sequencing)',
}

replace_once('<main class="main" id="mainContent">',
             '<main class="main" id="mainContent">' + guide,
             'guide comment after <main>')
replace_once('<nav class="nav-rail"',
             nav_note + '<nav class="nav-rail"',
             'nav-sync note before <nav class="nav-rail">')

for section_id, label in patterns.items():
    idx = html.find(section_id)
    if idx == -1:
        sys.exit(f'[section marker] {section_id} not found')
    start = html.rfind('<section', 0, idx)
    if start == -1:
        sys.exit(f'[section marker] <section open tag not found before {section_id}')
    marker = f"<!-- v {label} — replace inner content, keep classes & data-screen-label -->\n"
    if html[start - len(marker):start] != marker:  # idempotent
        html = html[:start] + marker + html[start:]
    print(f'  applied: section marker {section_id}')

# ── 2. Visualize patches ──────────────────────────────────────────────────

# PATCH-1: page-scoped state key (prevents cross-report collision on one origin).
replace_once(
"""/* Load persisted */
try {
  const saved = JSON.parse(localStorage.getItem('atlas-state'));
  if (saved) Object.assign(state, saved);
} catch(e) {}

function persist() {
  localStorage.setItem('atlas-state', JSON.stringify(state));
}""",
"""/* [visualize PATCH-1] definitions for server-persisted state — no calls here
   (the bootstrap calls live in PATCH-2b, after all functions are defined).
   Re-apply via build-atlas-shell.py on re-sync from Open Design. */
const SLUG = (location.pathname.replace(/^\//, '').replace(/\.html$/, '') || 'page');

let _syncTimer = null;
function persist() {
  clearTimeout(_syncTimer);
  _syncTimer = setTimeout(async () => {
    try {
      await fetch('/_feedback/' + encodeURIComponent(SLUG), {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(state)
      });
    } catch(e) {}
  }, 400);
}

async function loadState() {
  try {
    const ctrl = new AbortController();
    const timer = setTimeout(() => ctrl.abort(), 5000);
    const resp = await fetch('/_feedback/' + encodeURIComponent(SLUG), { signal: ctrl.signal });
    clearTimeout(timer);
    if (resp.ok) {
      Object.assign(state, await resp.json());
      renderSectionComments();
      rehydrateAnnotations();
      syncCheckboxes();
      for (let i = 0; i < 5; i++) updateSectionButtons(i);
      updateNavDots();
      updateFeedbackBadge();
    }
  } catch(e) {}
  persist();
}""",
    'PATCH-1 server-persisted state')

# PATCH-2b: render persisted section comments on load. Built with safe DOM
# methods (textContent/createElement) — never innerHTML — since these fields
# are persisted user input.
render_section_comments = """/* [visualize PATCH-2b/3] on load: strip hardcoded sample section comments so a fresh
   clone starts empty (PATCH-3), then render persisted comments from state (PATCH-2b).
   Safe DOM only. */
function stripSeedSectionComments() {
  document.querySelectorAll('[data-section-comments]').forEach(thread => {
    thread.querySelectorAll(':scope > .comment').forEach(c => c.remove());
    const h4 = thread.querySelector('h4');
    if (h4) h4.textContent = 'Discussion';
    thread.classList.remove('open');
  });
}
function renderSectionComments() {
  Object.keys(state.sectionComments || {}).forEach(idx => {
    const thread = document.querySelector(`[data-section-comments=\"${idx}\"]`);
    if (!thread) return;
    (state.sectionComments[idx] || []).forEach(c => {
      const div = document.createElement('div');
      div.className = 'comment';
      div.dataset.commentId = c.id;

      const avatar = document.createElement('div');
      avatar.className = 'comment-avatar';
      avatar.textContent = 'YO';

      const body = document.createElement('div');
      body.className = 'comment-body';

      const author = document.createElement('div');
      author.className = 'comment-author';
      author.textContent = c.author || 'You';

      const text = document.createElement('div');
      text.className = 'comment-text';
      text.textContent = c.text;

      const meta = document.createElement('div');
      meta.className = 'comment-meta';
      meta.textContent = 'saved session';

      body.appendChild(author);
      body.appendChild(text);
      body.appendChild(meta);
      if (!c.resolved) {
        const btn = document.createElement('button');
        btn.className = 'comment-resolve';
        btn.dataset.comment = c.id;
        btn.textContent = 'Mark resolved';
        body.appendChild(btn);
      }

      div.appendChild(avatar);
      div.appendChild(body);
      if (c.resolved) { div.style.opacity = '0.4'; div.style.textDecoration = 'line-through'; }
      thread.insertBefore(div, thread.lastElementChild);
      thread.classList.add('open');
    });
    const h4 = thread.querySelector('h4');
    const count = thread.querySelectorAll('.comment').length;
    if (h4 && count) h4.textContent = 'Discussion (' + count + ')';
  });
}
"""
replace_once('/* ── Comment threads ── */',
             render_section_comments + '/* ── Comment threads ── */',
             'PATCH-2b renderSectionComments on load')

# Bootstrap call: sync render + async server load.
# Must run AFTER const navDots / sections are initialized (lines ~1980-1981),
# otherwise updateNavDots hits the temporal-dead-zone ReferenceError.
replace_once(
    'const sections = document.querySelectorAll(\'.section\');',
    r'''const sections = document.querySelectorAll('.section');
/* [visualize PATCH-8] rehydrate inline annotation highlights from saved state.
   Seeded annotations (a1-a5) have spans in the source HTML; reviewer-added
   annotations need their text re-found and re-wrapped after a reload. */
function rehydrateAnnotations() {
  /* group pending annotations by section, then walk each section body
     ONCE looking for all pending texts in that section. O(nodes + anns). */
  const bySection = {};
  state.annotations.forEach(a => {
    if (document.querySelector('[data-annotation-id="' + a.id + '"]')) return;
    const sec = document.getElementById('section-' + a.section);
    if (!sec) return;
    const body = sec.querySelector('[data-section-body]');
    if (!body) return;
    if (!bySection[a.section]) bySection[a.section] = { body, anns: [] };
    bySection[a.section].anns.push(a);
  });
  Object.values(bySection).forEach(({ body, anns }) => {
    const remaining = new Map(anns.map(a => [a.text, a]));
    const walker = document.createTreeWalker(body, NodeFilter.SHOW_TEXT);
    let node;
    while ((node = walker.nextNode()) && remaining.size) {
      if (node.parentElement && node.parentElement.closest('.annotatable')) continue;
      const content = node.textContent;
      for (const [text, a] of remaining) {
        const idx = content.indexOf(text);
        if (idx === -1) continue;
        const range = document.createRange();
        range.setStart(node, idx);
        range.setEnd(node, idx + text.length);
        const span = document.createElement('span');
        span.className = 'annotatable highlighted type-' + (a.type || 'feedback');
        span.dataset.annotationId = a.id;
        if (a.resolved) span.classList.add('resolved');
        try { range.surroundContents(span); } catch (_) {
          try { const f = range.extractContents(); span.appendChild(f); range.insertNode(span); } catch (_2) {}
        }
        remaining.delete(text);
        break;
      }
    }
  });
}
/* instant render with defaults (no server round-trip) */
stripSeedSectionComments();
/* ensure all section comment threads are open (otherwise only section 0 is) */
document.querySelectorAll('[data-section-comments]').forEach(t => t.classList.add('open'));
renderSectionComments();
for (let i = 0; i < 5; i++) updateSectionButtons(i);
updateNavDots();
updateFeedbackBadge();
/* async: load saved state from server, re-render if changed */
loadState();''',
    'PATCH-bootstrap calls (after navDots/sections init)')

# PATCH-5: don't focus the composer input in showComposer — it fires
# on the first character of a drag-select, steals focus, and cancels the
# selection mid-drag. The composer is already focussable on explicit click
# via its mousedown handler (which keeps its stopPropagation + focus).
replace_once(
"""  composer.style.left = Math.max(8, left) + 'px';
  composer.style.top = Math.max(8, top) + 'px';
  composer.classList.add('visible');
  composerInput.value = '';
  requestAnimationFrame(() => composerInput.focus());""",
"""  composer.style.left = Math.max(8, left) + 'px';
  composer.style.top = Math.max(8, top) + 'px';
  composer.classList.add('visible');
  composerInput.value = '';
  /* [visualize PATCH-5] don't focus here — focus during a drag-select cancels
     the selection. The input gets focus on explicit click (composer mousedown). */""",
    'PATCH-5 no-auto-focus in showComposer')

# PATCH-6: wrap selection BEFORE the input steals focus, so the highlight stays
# visible while the user types. The pre-wrap span is then reused by PATCH-7.
replace_once(
"""composer.addEventListener('mousedown', (e) => {
  e.stopPropagation();
  requestAnimationFrame(() => composerInput.focus());
});""",
"""composer.addEventListener('mousedown', (e) => {
  e.stopPropagation();
  /* [visualize PATCH-6] wrap selection before focus — prevents the
     highlight from vanishing when the input steals focus */
  if (lastSelection && lastSelection.range && !lastSelection._wrapped) {
    const s = document.createElement('span');
    s.className = 'annotatable highlighted type-feedback annotation-pending';
    s.style.boxShadow = '0 0 0 2px var(--accent-soft)';
    try {
      lastSelection.range.surroundContents(s);
    } catch(_) {
      /* selection overlaps an existing element — extract + re-wrap */
      try { const frag = lastSelection.range.extractContents(); s.appendChild(frag); lastSelection.range.insertNode(s); } catch(_2) {}
    }
    lastSelection._wrapped = s;
  }
  requestAnimationFrame(() => composerInput.focus());
});""",
    'PATCH-6 early-wrap selection before focus')

# PATCH-7: reuse the pre-wrap span from PATCH-6 in postAnnotation
replace_once(
"""  /* Wrap annotated text */
  if (lastSelection.range) {
    const span = document.createElement('span');
    span.className = 'annotatable highlighted type-' + composerIntent;
    span.dataset.annotationId = id;
    try { lastSelection.range.surroundContents(span); } catch (e) {}
  }""",
"""  /* Wrap annotated text — reuse PATCH-6 pre-wrap if present */
  if (lastSelection._wrapped) {
    lastSelection._wrapped.dataset.annotationId = id;
    lastSelection._wrapped.className = 'annotatable highlighted type-' + composerIntent;
    lastSelection._wrapped.style.boxShadow = '';
    lastSelection._wrapped = null;
  } else if (lastSelection.range) {
    const span = document.createElement('span');
    span.className = 'annotatable highlighted type-' + composerIntent;
    span.dataset.annotationId = id;
    try {
      lastSelection.range.surroundContents(span);
    } catch (_) {
      /* selection overlaps an existing annotation — extract + re-wrap */
      try { const frag = lastSelection.range.extractContents(); span.appendChild(frag); lastSelection.range.insertNode(span); } catch (_2) {}
    }
  }""",
    'PATCH-7 reuse pre-wrap in postAnnotation')

# PATCH-9: if the selection overlaps an existing annotation span, don't show
# the composer. Instead open that annotation's thread in the drawer and focus
# the reply input.
replace_once(
"""  if (!sectionBody) return;

  lastSelection = {""",
"""  if (!sectionBody) return;

  /* [visualize PATCH-9] if the selection overlaps an existing annotation,
     open that thread instead of showing a new composer. */
  {
    const atStart = range.startContainer.nodeType === 3
      ? range.startContainer.parentElement?.closest('.annotatable')
      : range.startContainer.closest?.('.annotatable');
    const atEnd = range.endContainer.nodeType === 3
      ? range.endContainer.parentElement?.closest('.annotatable')
      : range.endContainer.closest?.('.annotatable');
    const existing = atStart || atEnd;
    if (existing && existing.dataset.annotationId) {
      state.activeAnnotationId = existing.dataset.annotationId;
      openDrawer();
      requestAnimationFrame(() => {
        const rf = document.querySelector('[data-ann-reply="' + existing.dataset.annotationId + '"]');
        if (rf) rf.focus();
      });
      return;
    }
  }

  lastSelection = {""",
    'PATCH-9 no-overlap: redirect to existing annotation thread')

# PATCH-10: persist checklist checkbox state.
# Add taskStatus to the default state object.
replace_once(
    '  activeAnnotationId: null',
    '  activeAnnotationId: null,\n  taskStatus: {}',
    'PATCH-10a add taskStatus to state')

# Wire up checkbox change handlers and restore from saved state on load.
# Inserted right after the thread-open call (the bootstrap sync render block,
# which is already in place).
replace_once(
    "document.querySelectorAll('[data-section-comments]').forEach(t => t.classList.add('open'));",
    r"""document.querySelectorAll('[data-section-comments]').forEach(t => t.classList.add('open'));
/* [visualize PATCH-10b] checkbox persistence with event delegation —
   works for any .checklist checkboxes regardless of when they appear. */
function syncCheckboxes() {
  document.querySelectorAll('.checklist input[type="checkbox"]').forEach(cb => {
    const id = cb.id;
    if (!id) return;
    if (!state.taskStatus) state.taskStatus = {};
    if (id in state.taskStatus) {
      cb.checked = state.taskStatus[id];
    } else {
      state.taskStatus[id] = cb.checked;
    }
  });
}
document.addEventListener('change', (e) => {
  const cb = e.target;
  if (!cb.matches('.checklist input[type="checkbox"]') || !cb.id) return;
  if (!state.taskStatus) state.taskStatus = {};
  state.taskStatus[cb.id] = cb.checked;
  persist();
});
syncCheckboxes();""",
    'PATCH-10b checkbox state sync + persist')

# PATCH-2a: push posted section comments into state.
replace_once(
"""    const commentId = 'sc' + Date.now();
    const thread = document.querySelector(`[data-section-comments=\"${idx}\"]`);
    const h4 = thread.querySelector('h4');""",
"""    const commentId = 'sc' + Date.now();
    /* [visualize PATCH-2a] persist the new section comment. */
    if (!state.sectionComments[idx]) state.sectionComments[idx] = [];
    state.sectionComments[idx].push({ id: commentId, author: 'You', text, resolved: false });
    const thread = document.querySelector(`[data-section-comments=\"${idx}\"]`);
    const h4 = thread.querySelector('h4');""",
    'PATCH-2a push section comment to state')

# PATCH-2c: persist the resolved flag when a section comment is marked resolved.
replace_once(
"""document.addEventListener('click', (e) => {
  if (e.target.classList.contains('comment-resolve')) {
    const commentEl = e.target.closest('.comment');
    commentEl.style.opacity = '0.4';
    commentEl.style.textDecoration = 'line-through';
    e.target.remove();
  }
});""",
"""document.addEventListener('click', (e) => {
  if (e.target.classList.contains('comment-resolve')) {
    const commentEl = e.target.closest('.comment');
    commentEl.style.opacity = '0.4';
    commentEl.style.textDecoration = 'line-through';
    e.target.remove();
    /* [visualize PATCH-2c] persist resolved state for section comments. */
    const cid = commentEl && commentEl.dataset.commentId;
    if (cid) {
      Object.keys(state.sectionComments || {}).forEach(k => {
        const c = (state.sectionComments[k] || []).find(x => x.id === cid);
        if (c) c.resolved = true;
      });
      persist();
    }
  }
});""",
    'PATCH-2c persist resolved flag')

open(DST, 'w', encoding='utf-8').write(html)
print(f'\nwrote {DST} ({os.path.getsize(DST)} bytes)')
print('patches present:',
      'STATE_KEY' in html,
      'renderSectionComments' in html,
      'stripSeedSectionComments' in html,
      'PATCH-2a' in html,
      'PATCH-2c' in html)
