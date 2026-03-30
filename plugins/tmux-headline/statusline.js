#!/usr/bin/env node
// Claude Code statusline
const os = require('os');
const fs = require('fs');
const { execFileSync } = require('child_process');

const R = '\x1b[0m', DIM = '\x1b[2m';
const G = '\x1b[2;32m', Y = '\x1b[2;33m', RE = '\x1b[2;31m';
const FG = '\x1b[2;36m', M = '\x1b[2;35m';

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

function fmtTokens(n) {
  if (!n && n !== 0) return '?';
  if (n >= 1e6) return (n / 1e6).toFixed(1) + 'm';
  if (n >= 1e3) return Math.round(n / 1e3) + 'k';
  return String(n);
}

function resetTime(epoch, short) {
  const diff = epoch - Date.now() / 1000;
  if (diff <= 0) return 'now';
  if (short) {
    return dur(diff * 1000);
  }
  // Show day + time in local TZ
  const d = new Date(epoch * 1000);
  const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const hh = String(d.getHours()).padStart(2, '0');
  const mm = String(d.getMinutes()).padStart(2, '0');
  return `${days[d.getDay()]} ${hh}:${mm}`;
}

function usageBar(pct, w = 8) {
  const pctClamped = Math.max(0, Math.min(100, Math.round(pct || 0)));
  const filled = Math.round(pctClamped / 100 * w);
  return `[${pc(pctClamped)}${'#'.repeat(filled)}${R}${DIM}${'-'.repeat(w - filled)}${R}]`;
}

function limitSegment(label, pct, epoch, shortReset) {
  if (pct == null) return '';
  const rounded = Math.max(0, Math.min(100, Math.round(pct)));
  return `${DIM}${label}${R} ${usageBar(rounded)} ${pc(rounded)}${rounded}% used${R} ${DIM}reset ${resetTime(epoch, shortReset)}${R}`;
}

function contextSegment(total, ctxWindow) {
  if (!(total && ctxWindow)) return '';
  return `${DIM}ctx ${R}${fmtTokens(total)}/${fmtTokens(ctxWindow)}${R}`;
}

function projectGitSegment(cwdRaw, git) {
  const cwd = shortCwd(cwdRaw);
  return git ? `${FG}${cwd}${R} ${DIM}@${R} ${git}` : `${FG}${cwd}${R}`;
}

function planUsage() {
  try {
    const f = os.homedir() + '/.claude/headline/usage.json';
    // Search for poll script in known plugin install locations
    const pluginDirs = [
      '/.claude/scripts/usage-poll.sh',                                                        // user-copied stable location
      '/.claude/plugins/local/tmux-headline/scripts/usage-poll.sh',                            // local dev
      '/.claude/plugins/marketplaces/ofan-plugins/plugins/tmux-headline/scripts/usage-poll.sh', // marketplace
    ];
    const pollScript = pluginDirs.map(d => os.homedir() + d).find(p => fs.existsSync(p));
    if (!pollScript) return '';
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
    return [
      limitSegment('5h', h5, data['5h_reset'], true),
      limitSegment('7d', d7, data['7d_reset'], false),
    ].filter(Boolean).join(`${DIM} · ${R}`);
  } catch { return ''; }
}

function codexRateUsage(rateLimits) {
  if (!rateLimits) return '';
  const primary = rateLimits.primary;
  const secondary = rateLimits.secondary;
  const bits = [];

  if (primary?.used_percent != null) {
    bits.push(limitSegment('5h', primary.used_percent, primary.resets_at, true));
  }
  if (secondary?.used_percent != null) {
    bits.push(limitSegment('7d', secondary.used_percent, secondary.resets_at, false));
  }
  return bits.join(` ${DIM}·${R} `);
}

function codexPayload(input) {
  if (input?.payload?.type === 'token_count') return input.payload;
  if (input?.type === 'token_count') return input;
  return null;
}

function codexContext(input) {
  if (input?.type === 'turn_context') return input.payload || input;
  if (input?.payload?.cwd || input?.payload?.model) return input.payload;
  return input;
}

function codexStatusLine(input, opts = {}) {
  const payload = opts.tokenPayload || codexPayload(input);
  const ctx = codexContext(input);
  if (!payload && !ctx?.model && !ctx?.cwd) return '';

  const cwdRaw = ctx?.cwd || process.cwd();
  const git = opts.git != null ? opts.git : gitStatus(cwdRaw);
  const model = String(ctx?.model || '?').replace(/\s+/g, '').toLowerCase();

  const total = payload?.info?.total_token_usage?.total_tokens;
  const ctxWindow = payload?.info?.model_context_window;
  const ctxPart = contextSegment(total, ctxWindow);
  const limits = codexRateUsage(payload?.rate_limits);

  const parts = [
    projectGitSegment(cwdRaw, git),
    `${DIM}${model}${ctxWindow ? `(${fmtTokens(ctxWindow)})` : ''}${R}`,
    ctxPart,
    limits,
  ].filter(Boolean);

  return parts.join(`${DIM} · ${R}`);
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

  if (j?.type === 'event_msg' || j?.type === 'turn_context' || j?.payload?.type === 'token_count') {
    process.stdout.write(codexStatusLine(j) || '…');
    return;
  }

  const u = os.userInfo().username;
  const h = os.hostname().split('.')[0];

  const model = (j.model?.display_name || j.model?.id || '?')
    .replace(/^Claude\s*/i, '').replace(/\s*\(.*?\)/g, '').replace(/\s+/g, '').toLowerCase();

  const cw = j.context_window || {};
  const remaining = cw.remaining_percentage ?? (100 - (cw.used_percentage || 0));
  const csz = ctxSize(cw);
  const usedPct = 100 - remaining;
  const ctxUsed = Math.round((cw.context_window_size || 200000) * usedPct / 100);
  const curTok = totalTokens({ total_input_tokens: ctxUsed, total_output_tokens: 0 });
  const git = gitStatus(j.cwd || process.cwd());

  const plan = planUsage();

  const parts = [
    projectGitSegment(j.cwd || process.cwd(), git),
    `${DIM}${model}(${csz})${R}`,
    `${DIM}ctx ${R}${curTok}/${csz}${R}`,
    plan,
    `${DIM}${u}@${h}${R}`,
  ].filter(Boolean);

  process.stdout.write(parts.join(`${DIM} · ${R}`));
}

if (require.main === module) {
  try { main(); } catch { process.stdout.write('…'); }
}

module.exports = {
  codexRateUsage,
  codexStatusLine,
  contextSegment,
  limitSegment,
  projectGitSegment,
  resetTime,
  usageBar,
};
