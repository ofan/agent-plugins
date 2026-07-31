# llman: thin launcher + agent shims, shared local proxy

**Status:** Draft, awaiting user review
**Date:** 2026-06-15
**Author:** brainstorm session

## Context

The user runs multiple AI coding agents (Claude Code, Pi, Codex, OpenCode) on machines ranging from laptops to Raspberry Pis. They have a local proxy (`llm-proxy` at `127.0.0.1:8890`) that already does OpenAI + Anthropic-compatible routing, sticky session assignment, and health probing across a dozen backends.

The pain points are:

1. **Model sync is annoying.** Every time a new model is added to `llm-proxy`, the existing `deepclaude` launcher needs a hand-edit to know about it.
2. **Mid-session model switches are clunky.** When a session hits a rate limit, broken model, or API error, the user has to kill the agent and relaunch it on a different model.
3. **Multi-agent setup is repetitive.** Pointing Claude, Pi, Codex, OpenCode all at the local proxy is env-var-juggling that's slightly different for each.
4. **Lightweight constraint.** The user runs this on small machines. A separate daemon, a heavy CLI, or multiple proxy processes are not acceptable.
5. **The existing `deepclaude` is bash + a Node proxy file with hardcoded backends and hardcoded models.** It's been growing features (pricing, switching, status) and the codebase shows it.

The user wants:

- A unified CLI (`llman`) that is the primary interface for launch, switch, status, config.
- Agent shims that are invisible: typing `claude` invokes the shim, the shim sets env vars and execs the real binary, the user never knows the shim is there.
- A single local proxy (the existing `llm-proxy`) doing the routing. No new engine.
- Server/proxy stays dumb: routing, model lookup, sticky session, health. No auto-switch logic.
- Client/launcher decides recovery: if a 429 comes back, the agent (or its wrapper) decides whether to switch models. The proxy just passes the error through with hint headers.

## Design

### Components

**1. `llman` CLI (single binary — language TBD, see Open Questions)**

Lives in `~/.local/bin/llman`. Subcommands:

| Command | Purpose |
|---|---|
| `llman launch <agent> [--model M] [--tier T] [-- <args>]` | Start an agent via the shim path |
| `llman use <client>=<model>` | Set or override a per-client model (writes to config, proxy hot-reloads) |
| `llman use --all <model>` | Same, applied to every client |
| `llman use session:<id>=<model>` | Per-session override |
| `llman status` | Show proxy state, backends, sessions, cost |
| `llman config {show,edit,path,set,get}` | Config CRUD |
| `llman restart` | Restart the local proxy |
| `llman install` | Install the agent shims (creates PATH-shadowing shim binaries) |
| `llman uninstall` | Remove the shims |
| `llman doctor` | Verify shim installation, PATH order, proxy reachability |
| `llman _run <agent> <args...>` | **Internal.** Called by the shims. Not a user-facing command. |

**2. Agent shims (4 small bash scripts)**

`~/.local/share/llman/shims/{claude,pi,codex,opencode}`. Each is identical:

```bash
#!/usr/bin/env bash
exec llman _run "$0" "$@"
```

The shim binary is named after the agent. `llman _run` detects which agent it is by reading `$0`.

**3. Local proxy = `llm-proxy` (no rename, no rewrite)**

The existing TypeScript proxy at `127.0.0.1:8890`. It already exposes:

- `GET /v1/models` (OpenAI-compatible model list)
- `POST /v1/messages` (Anthropic-compatible)
- `POST /v1/chat/completions` (OpenAI-compatible)
- `GET /_/config` / `PUT /_/config` (admin config CRUD with optimistic concurrency)
- `GET /_/config/backends` (open read of backends list)
- `fs.watch`-based hot-reload of the config file

What it needs to add:

- A `clientDefaults` config field: `{ claude: "opus", codex: "gpt-5.4", pi: "haiku", opencode: "sonnet" }`. When an incoming request doesn't specify a model (or specifies a tier name), the proxy substitutes the default.
- Error response enrichment: on upstream 429/5xx/401/403, the proxy returns the upstream's body unchanged and adds hint headers:
  - `X-Proxy-Request-Id: <id>` for tracing
  - `X-Fallback-Candidates: <comma-separated list>` from the user's `fallbackChains` config
  - `X-Fallback-Tier: <current tier name>` so the client can correlate

**4. Config file** (`~/.config/llman/config.json` by default)

```jsonc
{
  "proxy": {
    "url": "http://127.0.0.1:8890",
    "autoStart": true
  },
  "agents": {
    "claude":   { "env": { "ANTHROPIC_BASE_URL": "http://127.0.0.1:8890" }, "defaultTier": "opus" },
    "codex":    { "env": { "OPENAI_BASE_URL": "http://127.0.0.1:8890/v1" }, "defaultTier": "gpt-5.4" },
    "pi":       { "env": { "OPENAI_BASE_URL": "http://127.0.0.1:8890/v1" }, "defaultTier": "haiku" },
    "opencode": { "env": { "OPENAI_BASE_URL": "http://127.0.0.1:8890/v1" }, "defaultTier": "sonnet" }
  },
  "fallbackChains": {
    "opus":   ["sonnet", "haiku"],
    "sonnet": ["haiku"],
    "haiku":  []
  }
}
```

### How it feels in practice

```sh
# Install once
$ llman install
  shims installed: claude, pi, codex, opencode
  config at ~/.config/llman/config.json

# Launch an agent (shim is invisible)
$ claude
  # proxy auto-starts if not running
  # Claude uses opus (default tier from config)

# Launch with a different model
$ claude --model glm-5.2
  # shim injects: ANTHROPIC_BASE_URL=http://127.0.0.1:8890
  # shim sets per-session default to glm-5.2 for this invocation
  # execs the real /usr/bin/claude

# Mid-session switch (one terminal, all sessions)
$ llman use --all sonnet
  [config] wrote: clientDefaults.* → sonnet
  [proxy]   hot-reloaded, next request uses sonnet

# Per-client switch
$ llman use claude=opus
$ llman use pi=haiku

# Status
$ llman status
  proxy:    running, :8890, healthy
  sessions: 3 (1× claude/opus, 1× pi/haiku, 1× codex/gpt-5.4)
  cost:     $1.23 today

# Config
$ llman config edit
$ llman config set agents.claude.defaultTier sonnet

# Restart proxy
$ llman restart
```

### Boundary: what stays in the agents

- **Mid-session agent-side recovery.** Claude retrying on 429, Pi switching its own model — each agent does what it does. `llman` doesn't orchestrate this; it gives the agent the tools (env vars, hint headers on error) and lets the agent decide.
- **Agent-specific flags.** `claude -p`, `pi -m`, etc. The shim just passes them through.
- **Agent session identity.** Whatever each agent uses as a session ID is opaque to `llman`.

### Out of scope (deliberate)

- **A daemon.** No background process. The proxy is on-demand (auto-started by `llman launch` if not running).
- **A control channel for mid-session switching from inside the agent.** The agent can switch its own model by sending a new request with a different `model` field. The proxy honors whatever the agent asks for, subject to fallback chains. No WebSocket / SSE between proxy and agent.
- **Tiers as a first-class concept in the proxy.** The proxy treats model strings as opaque. `opus`/`sonnet`/`haiku` are CLI-level shortcuts the shim resolves before launching the agent. This keeps the proxy dumb.
- **Per-model pricing in v1.** `llm-proxy` already tracks per-session cost; surfacing it in `llman status` is a v1.5 addition, not v1.
- **A unified config schema for agent-specific options.** Each agent has its own flags. The shim passes them through.

## Open Questions

**1. Language for `llman` binary.** Options: Go (single static binary, no runtime), Node (matches `llm-proxy` ecosystem, fast to iterate), Rust (matches `llm-proxy` philosophy of zero runtime deps). Recommendation: Go for distribution simplicity (one binary, no `node_modules` to ship with the install). Node is faster to prototype. Decision deferred to implementation plan.

**2. Shim naming collision.** The shim is named `claude` and shadows the real `claude` binary on PATH. If a user has their own `claude` somewhere earlier in PATH, the shim doesn't fire. If a user upgrades Claude Code and the install path changes, the shim still points at the old path. `llman install` needs to:
- Place the shim in a directory guaranteed to win the PATH race
- Verify the shim actually shadows the real binary
- Provide `llman doctor` to detect shadowing and PATH issues

The fix is probably: install the shim to `~/.local/bin/` (or a directory the user explicitly adds to PATH first), and have `llman doctor` validate the install. This is a real concern, not a theoretical one — it will break silently if the user has multiple `claude` binaries on PATH.

**3. Proxy auto-start mechanism.** The shim runs the proxy if it's not already up. Options:
- Spawn `llm-proxy` as a child of the shim (proxy dies when the agent exits — bad for multi-agent)
- Spawn `llm-proxy` detached (proxy survives the agent — good, but needs cleanup somewhere)
- Trust the user to start the proxy manually (simpler, less magical)

Recommendation: spawn detached, with a `llman stop` for cleanup. Tradeoff: stale proxies if the user forgets.

**4. `llman` repo location.** Options: same repo as `llm-proxy` (monorepo), separate repo in `agent-plugins`, or sibling to `deepclaude`. Recommendation: separate repo (`llman`) for clean versioning. Could pull in `llm-proxy` as a git submodule or as a separate install dep.

**5. Backwards compat with `deepclaude`.** Existing `deepclaude` users have muscle memory: `deepclaude -b ds`, `deepclaude --switch or`. Decision needed: keep `deepclaude` as a deprecated wrapper that calls `llman` internally, or clean break. Recommendation: clean break, with a one-time migration note in the README.

## Verification

1. **Install flow:** Run `llman install` in a clean shell. Verify shims land in `~/.local/bin/` and shadow the real binaries via `which claude`, `which pi`, etc.
2. **Launch flow:** Type `claude`. Verify (a) the proxy auto-starts if not running, (b) the shim sets the right env vars (`env | grep ANTHROPIC_BASE_URL`), (c) the real Claude binary is `exec`'d.
3. **Switch flow:** While Claude is running, type `llman use claude=sonnet` in another terminal. Verify the proxy's next request from Claude uses sonnet (check `/_/log` or `/_/cost` on the proxy).
4. **Auto-recovery flow:** Force a 429 from a backend (kill the backend or block its port). Verify the proxy returns the 429 to Claude with `X-Fallback-Candidates` header. Verify Claude retries on the next model (or shows the user an error, depending on Claude's behavior).
5. **Multi-agent flow:** Run `claude` in one terminal, `pi` in another, `codex` in a third. Verify all three are pointed at the same proxy, all three appear in `llman status`, and `llman use --all haiku` flips all three at once.
6. **Doctor flow:** Run `llman doctor` after a clean install. Verify it reports "all shims shadowing correctly, proxy reachable, config valid." Run it after manually breaking PATH. Verify it reports the breakage with a fix suggestion.
7. **Resource footprint:** Measure RSS of `llman` and `llm-proxy` on idle. Verify total footprint is under 100MB. (Raspberry Pi is the constraint.)

## Risks

- **Shim shadowing fragility.** The shim approach depends on PATH order. If the user has a custom PATH, the shim might not fire. Mitigation: `llman doctor` checks and warns.
- **Proxy auto-start on shared machines.** If the user has two sessions on the same machine, both will try to start the proxy. Mitigation: `llman launch` checks if the proxy is already up and reuses it.
- **`llm-proxy` config schema change.** `llm-proxy` already has its own config schema and versioning. Adding `clientDefaults` is additive but bumps the schema. Coordination needed with `llm-proxy` maintainers (which is also the user).
- **Session identity mismatch.** `llm-proxy` keys sticky sessions on the system-prompt tail hash. Pi and Codex might not send system prompts consistently. Per-session override (`llman use session:<id>=...`) might not work for those agents until they get a stable session identity. Mitigation: per-client override always works; per-session is best-effort.
