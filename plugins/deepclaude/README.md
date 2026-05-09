# deepclaude

Packaged Claude Code launcher and local model proxy for DeepSeek, OpenRouter,
Fireworks, and Anthropic, with slash commands for live backend switching.

This plugin packages and extends the original
[aattaran/deepclaude](https://github.com/aattaran/deepclaude) project for the
Claude plugin marketplace. The local changes add plugin installation, slash
commands, shared proxy sessions, per-session backend switching, and single-proxy
lifecycle handling.

## Commands

| Command | Description |
|---------|-------------|
| `/deepseek` | Switch proxy mode to DeepSeek |
| `/anthropic` | Switch proxy mode to Anthropic |
| `/openrouter` | Switch proxy mode to OpenRouter |
| `/deepclaude-status` | Show proxy status |
| `/deepclaude-cost` | Show tracked token cost summary |

## Requirements

Install the packaged launcher once:

```sh
./install.sh
```

Then start Claude Code through `deepclaude`. The launcher starts or reuses the
local shared proxy, assigns the Claude instance a `DEEPCLAUDE_SESSION_ID`, and
points `ANTHROPIC_BASE_URL` at the proxy. The proxy defaults to
`http://127.0.0.1:3200`.

```sh
deepclaude
deepclaude -r
deepclaude --remote
```

Short `-r` is passed to Claude Code as resume. Use long `--remote` for the
upstream DeepClaude remote-control mode.

The launcher should provide provider keys through environment variables or a secret manager:

```sh
DEEPSEEK_API_KEY=...
OPENROUTER_API_KEY=...
FIREWORKS_API_KEY=...
```

The packaged proxy preserves DeepSeek thinking blocks end-to-end. For OpenRouter
and Fireworks, thinking blocks are stripped or converted because those backends
do not reliably support Anthropic thinking replay.

## Shared proxy model

Multiple `deepclaude` instances can share one proxy. Backend mode is tracked per
`DEEPCLAUDE_SESSION_ID`, so `/deepseek` in one Claude session does not switch
another session that is using `/openrouter`.

The launcher sends the session token to the proxy as the local
`ANTHROPIC_AUTH_TOKEN`. The proxy consumes that token for routing and replaces it
with the provider key before forwarding model requests.

By default, a launcher that starts the proxy leaves it running for other sessions.
Set `DEEPCLAUDE_STOP_PROXY_ON_EXIT=1` if you want the starter session to stop its
own proxy on exit.

Only one proxy is used per `DEEPCLAUDE_PROXY_PORT`. Launchers reuse the existing
proxy and register their session with a heartbeat. A quiet Claude Code session
can sit for a long time without model requests; the proxy will stay alive while
that launcher is still running.

After the last live launcher session exits, the shared proxy exits after 30
minutes. Override that with `DEEPCLAUDE_PROXY_IDLE_TTL`, using `30s`, `10m`,
`2h`, or `0`/`off` to disable proxy shutdown. Heartbeats run every 30 seconds by
default; override with `DEEPCLAUDE_PROXY_HEARTBEAT_INTERVAL`.

### Limits

- Resuming a transcript that was already corrupted by missing thinking blocks can
  still fail; start a fresh session or compact past the bad turns.
- DeepSeek preserves thinking replay. OpenRouter and Fireworks do not.
- `/anthropic` inside a shared-proxy session is best-effort passthrough. For a
  clean Anthropic session, launch normal Claude Code or `deepclaude --backend anthropic`.

## Install

```sh
claude plugin install deepclaude@ofan-plugins
```

After plugin install, run the plugin installer from the installed plugin
directory or from this repository checkout.

## Upstream

Original project: [aattaran/deepclaude](https://github.com/aattaran/deepclaude).

This repository is a packaged variant maintained for `ofan/agent-plugins`; send
plugin packaging issues here, and upstream DeepClaude behavior questions to the
original repository when they reproduce there.
