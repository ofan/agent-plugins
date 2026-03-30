const test = require('node:test');
const assert = require('node:assert/strict');

const statusline = require('../statusline.js');

function stripAnsi(text) {
  return text.replace(/\x1b\[[0-9;]*m/g, '');
}

test('ascii usage bar uses plain fill characters without embedded labels', () => {
  const out = stripAnsi(statusline.usageBar(54, 8));
  assert.equal(out, '[####----]');
});

test('codex limits use used wording and explicit reset labels', () => {
  const out = stripAnsi(statusline.codexRateUsage({
    primary: { used_percent: 54, resets_at: Math.floor(Date.now() / 1000) + 90 * 60 },
    secondary: { used_percent: 79, resets_at: Math.floor(Date.now() / 1000) + 2 * 24 * 60 * 60 },
  }));

  assert.match(out, /5h \[####----\] 54% used reset /);
  assert.match(out, /7d \[######--\] 79% used reset /);
});

test('codex statusline orders project+git before model, ctx, and limits', () => {
  const out = stripAnsi(statusline.codexStatusLine({
    type: 'turn_context',
    payload: {
      cwd: '/home/ubuntu/projects/openclaw-dashboard',
      model: 'gpt-5.4',
    },
  }, {
    git: '⎇ main △ 2',
    tokenPayload: {
      info: {
        total_token_usage: { total_tokens: 430000 },
        model_context_window: 1000000,
      },
      rate_limits: {
        primary: { used_percent: 13, resets_at: Math.floor(Date.now() / 1000) + 4 * 60 * 60 },
        secondary: { used_percent: 79, resets_at: Math.floor(Date.now() / 1000) + 2 * 24 * 60 * 60 },
      },
    },
  }));

  assert.match(out, /^~\/projects\/openclaw-dashboard @ ⎇ main △ 2 · gpt-5\.4\(1\.0m\) · ctx 430k\/1\.0m · 5h \[#-------\] 13% used reset /);
  assert.match(out, / · 7d \[######--\] 79% used reset /);
});
