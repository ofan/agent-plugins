#!/usr/bin/env node
// Claude Code statusline
const os = require('os');
const fs = require('fs');
const { execFileSync } = require('child_process');

const R = '\x1b[0m', DIM = '\x1b[2m';
const G = '\x1b[2;32m', Y = '\x1b[2;33m', RE = '\x1b[2;31m';
const FG = '\x1b[2;36m', HI = '\x1b[2;37m', M = '\x1b[2;35m';

const pc = p => p < 50 ? G : p < 80 ? Y : RE;

function dur(ms) {
  if (!ms) return '0m';
  const m = Math.floor(ms / 60000);
  if (m < 60) return m + 'm';
  const h = Math.floor(m / 60), rm = m % 60;
  return h + 'h' + (rm ? rm + 'm' : '');
}

function shortCwd(cwd) {
  const home = os.homedir().replace(/\\/g, '/');
  let p = cwd.replace(/\\/g, '/').replace(home, '~');
  const parts = p.split('/');
  if (parts.length > 3) return parts[0] + '/.../' + parts[parts.length - 1];
  return p;
}

function totalTokens(cw) {
  const t = (cw.total_input_tokens || 0) + (cw.total_output_tokens || 0);
  if (t >= 1e6) return (t / 1e6).toFixed(1) + 'mil';
  if (t >= 1e3) return Math.round(t / 1e3) + 'k';
  return t + '';
}

function ctxSize(cw) {
  const sz = cw.context_window_size || 200000;
  if (sz >= 1e6) return Math.round(sz / 1e6) + 'm';
  return Math.round(sz / 1e3) + 'k';
}

function resetTime(epoch, short) {
  const diff = epoch - Date.now() / 1000;
  if (diff <= 0) return 'now';
  if (short) {
    const m = Math.floor(diff / 60);
    if (m < 60) return m + 'm';
    const h = Math.floor(m / 60), rm = m % 60;
    return h + 'h' + (rm ? String(rm).padStart(2, '0') : '');
  }
  // Show day + time in local TZ
  const d = new Date(epoch * 1000);
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  return `${days[d.getDay()]} ${hh}:${mm}`;
}

function planUsage() {
  try {
    const f = os.homedir() + '/.claude/headline/usage.json';
    const pollScript = os.homedir() + '/.claude/plugins/local/tmux-headline/scripts/usage-poll.sh';
    let data;
    try { data = JSON.parse(fs.readFileSync(f, 'utf8')); } catch { data = null; }
    // Auto-poll if missing or stale (> 120s)
    if (!data || Date.now() / 1000 - data.ts > 120) {
      try { execFileSync('bash', [pollScript], { timeout: 10000, stdio: 'ignore' }); } catch {}
      try { data = JSON.parse(fs.readFileSync(f, 'utf8')); } catch { return ''; }
    }
    if (Date.now() / 1000 - data.ts > 3600) return '';
    const h5 = Math.round(data['5h'] * 100);
    const d7 = Math.round(data['7d'] * 100);
    const h5r = resetTime(data['5h_reset'], true);
    const d7r = resetTime(data['7d_reset'], false);
    // Colors: filled bar + label = usage-colored (green/yellow/red)
    //         empty bar = dim grey, reset time = dim
    const BSTYLE = process.env.HEADLINE_BAR_STYLE || 'solid';
    const bar = (pct, w) => {
      const label = `${pct}%`;
      const filled = Math.round(pct / 100 * w);
      const pad = Math.max(0, Math.floor((w - label.length) / 2));
      const [fc, ec] = BSTYLE === 'ascii' ? ['=', '-'] : ['█', '░'];
      let inner = fc.repeat(filled) + ec.repeat(w - filled);
      inner = inner.slice(0, pad) + label + inner.slice(pad + label.length);
      let out = '';
      for (let i = 0; i < inner.length; i++) {
        const ch = inner[i];
        const inFilled = i < filled;
        if (ch === fc || ch === ec) {
          out += `${inFilled ? pc(pct) : DIM}${ch}${R}`;
        } else {
          out += `${pc(pct)}${ch}${R}`;
        }
      }
      return out;
    };
    return `${bar(h5, 10)} ${DIM}${h5r}${R} ${DIM}· ${R}${bar(d7, 10)} ${DIM}${d7r}${R}`;
  } catch { return ''; }
}

function gitStatus(cwd) {
  try {
    const branch = execFileSync('git', ['rev-parse', '--abbrev-ref', 'HEAD'], { cwd, timeout: 2000, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    const status = execFileSync('git', ['status', '--porcelain'], { cwd, timeout: 2000, stdio: ['ignore', 'pipe', 'ignore'] }).toString();
    let ahead = '0', behind = '0';
    try {
      ahead = execFileSync('git', ['rev-list', '--count', '@{u}..HEAD'], { cwd, timeout: 2000, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
      behind = execFileSync('git', ['rev-list', '--count', 'HEAD..@{u}'], { cwd, timeout: 2000, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    } catch {} // no upstream tracking — just skip

    const lines = status.split('\n').filter(Boolean);
    const staged = lines.filter(l => /^[MADRC]/.test(l)).length;
    const modified = lines.filter(l => /^.[MD]/.test(l)).length;
    const untracked = lines.filter(l => /^\?\?/.test(l)).length;

    // Detect worktree
    const gitDir = execFileSync('git', ['rev-parse', '--git-dir'], { cwd, timeout: 2000, stdio: ['ignore', 'pipe', 'ignore'] }).toString().trim();
    const isWorktree = gitDir.includes('/worktrees/');

    let parts = [`${M}⎇ ${branch}${R}`];
    if (isWorktree) parts.push(`${M}⌥ wt${R}`);
    if (+ahead > 0) parts.push(`${G}↑${ahead}${R}`);
    if (+behind > 0) parts.push(`${RE}↓${behind}${R}`);
    if (staged) parts.push(`${G}● ${staged}${R}`);
    if (modified) parts.push(`${Y}△ ${modified}${R}`);
    if (untracked) parts.push(`${DIM}… ${untracked}${R}`);
    if (!staged && !modified && !untracked) parts.push(`${G}✓${R}`);

    return parts.join(' ');
  } catch { return ''; }
}

function main() {
  let j;
  try { j = JSON.parse(fs.readFileSync(0, 'utf8')); } catch { process.stdout.write('…'); return; }

  const u = os.userInfo().username;
  const h = os.hostname().split('.')[0];
  const pl = os.platform();
  const env = pl === 'win32' ? (process.env.WSL_DISTRO_NAME ? 'wsl' : 'win')
            : pl === 'darwin' ? 'mac' : 'linux';

  const model = (j.model?.display_name || j.model?.id || '?')
    .replace(/^Claude\s*/i, '').replace(/\s*\(.*?\)/g, '').replace(/\s+/g, '').toLowerCase();

  const cw = j.context_window || {};
  const remaining = cw.remaining_percentage ?? (100 - (cw.used_percentage || 0));
  const cwd = shortCwd(j.cwd || process.cwd());
  const d = dur(j.cost?.total_duration_ms);
  const tok = totalTokens(cw);
  const csz = ctxSize(cw);
  const usedPct = 100 - remaining;
  const ctxUsed = Math.round((cw.context_window_size || 200000) * usedPct / 100);
  const curTok = totalTokens({ total_input_tokens: ctxUsed, total_output_tokens: 0 });
  const git = gitStatus(j.cwd || process.cwd());

  const plan = planUsage();

  const parts = [
    `${FG}${cwd}${R} ${git}`,
    `${DIM}${model}(${csz})${R}`,
    `${DIM}ctx ${R}${pc(100 - remaining)}${curTok}/${csz}${R}`,
    plan,
    `${DIM}${u}@${h}${R}`,
  ].filter(Boolean);

  process.stdout.write(parts.join(`${DIM} · ${R}`));
}

try { main(); } catch { process.stdout.write('…'); }
