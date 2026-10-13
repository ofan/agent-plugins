# agent-plugins

Agent plugin marketplace by [ofan](https://github.com/ofan), covering Claude-oriented plugins and shared agent tooling.

## Plugins

| Plugin | Description |
|--------|-------------|
| [deepclaude](plugins/deepclaude/) | Packaged [DeepClaude](https://github.com/aattaran/deepclaude) launcher and proxy for DeepSeek/OpenRouter/Fireworks with live backend switching |
| [tmux-headline](plugins/tmux-headline/) | tmux headlines, spinner/title integration, and usage bars for Claude and Codex workflows |
| [motion-design](plugins/motion-design/) | Design and render motion graphics and product/UI videos from deterministic code: seek(t) scenes, spring physics, frame-synced audio, critique loop |

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
