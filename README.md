# agent-plugins

Agent plugin marketplace by [ofan](https://github.com/ofan), covering Claude-oriented plugins and shared agent tooling.

## Plugins

| Plugin | Description |
|--------|-------------|
| [deepclaude](plugins/deepclaude/) | Claude Code launcher and proxy for DeepSeek/OpenRouter/Fireworks with live backend switching |
| [tmux-headline](plugins/tmux-headline/) | tmux headlines, spinner/title integration, and usage bars for Claude and Codex workflows |

## Install

```sh
# Add the marketplace
claude plugin marketplace add ofan/agent-plugins

# Install a plugin
claude plugin install tmux-headline@ofan-plugins
claude plugin install deepclaude@ofan-plugins
```

## License

MIT
