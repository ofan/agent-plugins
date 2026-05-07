# deepclaude

Packaged Claude Code launcher and local model proxy for DeepSeek, OpenRouter,
Fireworks, and Anthropic, with slash commands for live backend switching.

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

Then start Claude Code through `deepclaude`. The launcher starts the local
proxy, points `ANTHROPIC_BASE_URL` at it, and stops the proxy when Claude exits.
The proxy defaults to `http://127.0.0.1:3200`.

```sh
deepclaude
```

The launcher should provide provider keys through environment variables or a secret manager:

```sh
DEEPSEEK_API_KEY=...
OPENROUTER_API_KEY=...
FIREWORKS_API_KEY=...
```

The packaged proxy preserves DeepSeek thinking blocks end-to-end. For OpenRouter
and Fireworks, thinking blocks are stripped or converted because those backends
do not reliably support Anthropic thinking replay.

## Install

```sh
claude plugin install deepclaude@ofan-plugins
```

After plugin install, run the plugin installer from the installed plugin
directory or from this repository checkout.
