#!/usr/bin/env node
// Standalone test for atlas-shell.html patches. Self-contained: serves the shell
// + /_feedback GET/POST (mirroring the prod visualize server), spawns headless
// Chrome with CDP, drives the real UI, and asserts the server-persistence loop.
//
// Usage:  node test-atlas-shell.mjs [path/to/atlas-shell.html]
import http from 'node:http';
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync, mkdirSync, rmSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { tmpdir, homedir } from 'node:os';

const HERE = path.dirname(fileURLToPath(import.meta.url));
const SHELL = process.argv[2] || path.join(HERE, 'atlas-shell.html');
const CHROME = process.env.CHROME_BIN || 'google-chrome';
const shellHtml = readFileSync(SHELL, 'utf-8');
const sleep = ms => new Promise(r => setTimeout(r, ms));

// --- http server: shell + /_feedback GET/POST ---
const FEEDBACK_DIR = path.join(homedir(), '.local/share/claude-visualize/feedback');
mkdirSync(FEEDBACK_DIR, { recursive: true });
const server = http.createServer((req, res) => {
  if (req.url.startsWith('/_feedback/')) {
    const slug = req.url.slice('/_feedback/'.length);
    if (!/^[A-Za-z0-9_-]+$/.test(slug)) { res.writeHead(400); res.end('bad slug'); return; }
    const fp = path.join(FEEDBACK_DIR, slug + '.json');
    if (req.method === 'GET') {
      try {
        const d = readFileSync(fp, 'utf-8');
        res.writeHead(200, { 'content-type': 'application/json' }); res.end(d);
      } catch { res.writeHead(404, { 'content-type': 'application/json' }); res.end('null'); }
      return;
    }
    if (req.method === 'POST') {
      let body = ''; req.on('data', c => body += c);
      req.on('end', () => {
        try { JSON.parse(body); } catch { res.writeHead(400); res.end('bad json'); return; }
        writeFileSync(fp, body);
        res.writeHead(200, { 'content-type': 'application/json' }); res.end('{"ok":true}');
      });
      return;
    }
  }
  if (req.url === '/atlas-test.html' || req.url === '/') {
    res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
    res.end(shellHtml);
  } else { res.writeHead(404); res.end('nf'); }
});
await new Promise(r => server.listen(0, '127.0.0.1', r));
const TEST_URL = `http://127.0.0.1:${server.address().port}/atlas-test.html`;

// --- spawn chrome (free port + fresh profile) ---
const scout = http.createServer();
await new Promise(r => scout.listen(0, '127.0.0.1', r));
const CDP_PORT = scout.address().port; scout.close();
const profileDir = mkdtempSync(path.join(tmpdir(), 'chrome-cdp-'));
const chrome = spawn(CHROME, [
  '--headless=new', `--remote-debugging-port=${CDP_PORT}`, '--no-sandbox', '--disable-gpu',
  `--user-data-dir=${profileDir}`, '--window-size=1440,900', 'about:blank',
], { stdio: 'ignore' });
const cleanup = () => { try { chrome.kill('SIGTERM'); } catch {} try { server.close(); } catch {} };
process.on('exit', cleanup); process.on('SIGINT', () => { cleanup(); process.exit(130); });

// --- CDP client ---
const get = p => new Promise((res, rej) => {
  http.get(`http://127.0.0.1:${CDP_PORT}${p}`, r => {
    let d = ''; r.on('data', c => d += c); r.on('end', () => res(JSON.parse(d)));
  }).on('error', rej);
});
let up = false;
for (let i = 0; i < 60; i++) { try { await get('/json/version'); up = true; break; } catch { await sleep(250); } }
if (!up) { console.error('FAIL: chrome CDP did not come up'); cleanup(); process.exit(2); }
const list = await get('/json/list');
const target = list.find(t => t.type === 'page') || list[0];
const ws = new WebSocket(target.webSocketDebuggerUrl);
let id = 1; const pending = new Map();
ws.addEventListener('message', e => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { const cb = pending.get(m.id); pending.delete(m.id); cb(m); }
});
await new Promise(r => ws.addEventListener('open', r));
const cdp = (method, params = {}) => new Promise((res, rej) => {
  const i = id++; pending.set(i, m => m.error ? rej(new Error(JSON.stringify(m.error))) : res(m.result));
  ws.send(JSON.stringify({ id: i, method, params }));
});
const evalJS = async (expr, awaitPromise = false) => {
  const r = await cdp('Runtime.evaluate', { expression: expr, awaitPromise, returnByValue: true });
  if (r.exceptionDetails) throw new Error('JS error: ' + JSON.stringify(r.exceptionDetails));
  return r.result.value;
};
const waitLoaded = async () => {
  for (let i = 0; i < 80; i++) { if (await evalJS('document.readyState') === 'complete') return; await sleep(100); }
};
await cdp('Page.enable'); await cdp('Runtime.enable');
const navigate = async url => { await cdp('Page.navigate', { url }); await waitLoaded(); };
const reload = async () => { await cdp('Page.reload'); await waitLoaded(); };

const snap = async label => {
  const s = JSON.parse(await evalJS(`JSON.stringify({
    slug: (location.pathname.replace(/^\\//, '').replace(/\\.html$/, '') || 'page'),
    comments: document.querySelectorAll('[data-section-comments] .comment').length,
    loaded: typeof loadState === 'function' ? 'async-fn' : 'not-loadable'
  })`));
  s.label = label; return s;
};

// 1. clean start: delete any prior feedback file for this slug, reload
try { rmSync(path.join(FEEDBACK_DIR, 'atlas-test.json')); } catch {}
await navigate(TEST_URL); await sleep(500);
const s0 = await snap('clean');
console.log('SNAP0', JSON.stringify(s0));

// 2. post a section comment through the real UI
const marker = 'SERVER-PERSIST-MARKER-' + Date.now();
await evalJS(`(function(){
  const ta = document.querySelector('[data-comment-input="0"]');
  if (!ta) throw new Error('no textarea');
  ta.value = ${JSON.stringify(marker)};
  ta.dispatchEvent(new Event('input', { bubbles: true }));
  ta.dispatchEvent(new KeyboardEvent('keydown', { key: 'Enter', bubbles: true, cancelable: true }));
})()`);
await sleep(600); // debounce is 400ms; wait for POST to land
const s1 = await snap('after-post');
s1.markerInDOM = await evalJS(`document.querySelector('[data-section-comments="0"]').innerText.includes(${JSON.stringify(marker)})`);
console.log('SNAP1', JSON.stringify(s1));

// PATCH-PERSIST: verify server has the state via GET
let fbFile = null;
for (let i = 0; i < 15; i++) {
  try { fbFile = readFileSync(path.join(FEEDBACK_DIR, 'atlas-test.json'), 'utf-8'); break; } catch { await sleep(100); }
}
const persistOk = !!fbFile && fbFile.includes(marker);
console.log('  server has state:', persistOk, fbFile ? `(${fbFile.length}b)` : '(null)');

// screenshot after post
let shot = await cdp('Page.captureScreenshot', { format: 'png' });
writeFileSync('/tmp/live-after-post.png', Buffer.from(shot.data, 'base64'));

// 3. reload — should reload from server GET
await reload(); await sleep(600);
const s2 = await snap('after-reload');
s2.markerInDOM = await evalJS(`document.querySelector('[data-section-comments="0"]').innerText.includes(${JSON.stringify(marker)})`);
console.log('SNAP2', JSON.stringify(s2));
shot = await cdp('Page.captureScreenshot', { format: 'png' });
writeFileSync('/tmp/live-after-reload.png', Buffer.from(shot.data, 'base64'));

// 4. verdict
const clean = s0.comments === 0;
const survive = s1.comments === s0.comments + 1 && s2.comments === s1.comments && s2.markerInDOM === true;

console.log('\n=== VERDICT ===');
console.log('CLEAN-START  fresh clone = 0 comments     :', clean ? 'PASS' : 'FAIL',
            `(baseline=${s0.comments})`);
console.log('PERSIST      state saved to /_feedback/   :', persistOk ? 'PASS' : 'FAIL',
            `(${fbFile ? fbFile.length + 'b' : 'no file'}, marker=${fbFile ? fbFile.includes(marker) : false})`);
console.log('RELOAD       comment survives reload      :', survive ? 'PASS' : 'FAIL',
            `(counts ${s0.comments} -> ${s1.comments} -> ${s2.comments}, marker=${s2.markerInDOM})`);

ws.close(); cleanup();
process.exit(clean && survive && persistOk ? 0 : 1);
