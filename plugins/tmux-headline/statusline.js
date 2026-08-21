#!/usr/bin/env node
// Claude Code statusline — row 1 only (cwd+git · model · ctx · user@host).
// Limits/usage/cost live EXCLUSIVELY on row 2, rendered by the wrapper
// (scripts/statusline-effort.sh) from llm-proxy billing (/_/billing) via
// proxy-cost-poll.sh. The legacy per-vendor segments (Anthropic rate-limit
// headers, deepclaude local-proxy cost) were removed — one source of truth.
const os = require('os');
const fs = require('fs');
const { execFileSync } = require('child_process');

const R = '\x1b[0m', DIM = '\x1b[2m';
const G = '\x1b[2;32m', Y = '\x1b[2;33m', RE = '\x1b[2;31m';
const FG = '\x1b[2;36m', M = '\x1b[2;35m';

const pc = p => p < 50 ? G : p < 80 ? Y : RE;

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

  const model = (j.model?.display_name || j.model?.id || '?')
    .replace(/^Claude\s*/i, '').replace(/\s*\(.*?\)/g, '').replace(/\s*\[.*?\]/g, '').replace(/\s+/g, '').toLowerCase();

  const cw = j.context_window || {};
  const remaining = cw.remaining_percentage ?? (100 - (cw.used_percentage || 0));
  const cwd = shortCwd(j.cwd || process.cwd());
  const csz = ctxSize(cw);
  const usedPct = 100 - remaining;
  const ctxUsed = Math.round((cw.context_window_size || 200000) * usedPct / 100);
  const curTok = totalTokens({ total_input_tokens: ctxUsed, total_output_tokens: 0 });
  const git = gitStatus(j.cwd || process.cwd());

  const parts = [
    `${FG}${cwd}${R} ${git}`,
    `${DIM}${model}(${csz})${R}`,
    `${DIM}ctx ${R}${pc(100 - remaining)}${curTok}/${csz}${R}`,
    `${DIM}${u}@${h}${R}`,
  ].filter(Boolean);

  process.stdout.write(parts.join(`${DIM} · ${R}`));
}

try { main(); } catch { process.stdout.write('…'); }
