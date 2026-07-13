# ccgw

Launch Claude Code in **gateway mode** against [llm-proxy](https://github.com/ofan/llm-proxy).

Sets `ANTHROPIC_BASE_URL` at the proxy + `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1`,
then execs the **real** claude binary — so the proxy's models
(`claude-<backend>/<model>`, incl. `[1m]` extended-context) populate the `/model`
picker via gateway discovery. Lets `/model` own selection (does **not** pin
`ANTHROPIC_MODEL`).

## Use

`ccgw` is on PATH when the plugin is enabled. Run it **interactively** (discovery is
an async startup call; `-p` exits before it completes), then `/model` shows the
`claude-*` gateway entries.

Make bare `claude` default to gateway mode:

```sh
./install.sh          # symlinks ~/bin/claude -> ccgw
```

Revert: `ln -sfn ~/.local/share/deepclaude/deepclaude ~/bin/claude`

## Env overrides

| var | default | meaning |
|---|---|---|
| `LLM_PROXY_URL` | `https://proxy.lab.tf` | proxy base URL |
| `LLM_PROXY_TOKEN` | `proxy` | bearer token (proxy is open) |
| `LLM_PROXY_FALLBACK` | *(empty)* | Anthropic-native base URL if the proxy is unreachable at launch |
| `CCGW_CLAUDE_BIN` | *(auto)* | explicit path to the real claude binary |
| `CCGW_PROBE_TIMEOUT` | `4` | proxy reachability probe timeout (s) |
| `CCGW_DEBUG` | — | `1` prints resolved config before exec |

## Gotchas

- Execs the real claude binary by resolving PATH (skips the `~/bin` wrapper dirs) —
  survives node version bumps; override with `CCGW_CLAUDE_BIN`.
- If `~/.claude/settings.json` `env` sets `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`,
  it silently kills discovery — ccgw warns; remove it.
- `deepclaude` stays available as its own command.
