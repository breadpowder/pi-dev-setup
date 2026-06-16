# pi-dev-setup

User-level pi extensions for git workflow, web search, and agent state.

## Install on a new host

```bash
git clone https://github.com/davis7dotsh/pi-dev-setup.git
cd pi-dev-setup
./install.sh
```

This symlinks `~/.pi/agent/extensions` to the repo's `extensions/` directory and installs npm dependencies there.

Because it's a symlink, any edit you make in this repo is immediately active — no re-run needed.

## Update

Pull the repo. The symlink already points to the latest files. Run `./install.sh` only if dependencies changed.

## What's included

### Git workflow helpers

- `/yeet` — Add, commit, and push current repo changes.

### Web search & scraping

- `search` tool — Web/news/image search via Firecrawl.
- `scrape` tool — Fetch a page as markdown via Firecrawl.

### Status & tracking

- **tps-tracker** — Live tokens-per-second display during generation.

### Agent workflow

- **goal** — `/goal` plus `create_goal`/`update_goal`/`get_goal` tools for long-running objectives with token budgets and elapsed-time tracking.
- **pi-cloak** — Redacts sensitive patterns from `read` tool output using regex rules in `~/.pi/agent/cloak.json`.
- **herdr-agent-state** — Reports agent working/blocked/idle state to the `herdr` pane manager (no-op when herdr is not running).

## Environment variables

Add to `~/.pi/agent/.env`:

```bash
FIRECRAWL_API_KEY=fc-...
```

## Providers

Pi supports both subscription (OAuth) and API-key providers.

### Subscription login

In interactive mode, run:

```text
/login
```

Built-in subscription providers:

- **ChatGPT Plus/Pro** — OpenAI Codex
- **Claude Pro/Max** — uses extra usage, billed per token
- **GitHub Copilot**

Credentials are stored in `~/.pi/agent/auth.json` and auto-refresh.

### API keys

Set before launching pi:

```bash
export ANTHROPIC_API_KEY=sk-ant-...
pi
```

Or run `/login` and select a provider to store the key in `auth.json`.

Common providers: Anthropic, OpenAI, DeepSeek, Google Gemini, Mistral, Groq, Cerebras, OpenRouter, Vercel, Fireworks, Together, Kimi, and more.

### Custom providers

For OpenAI-compatible servers (Ollama, vLLM, LM Studio, proxies), add entries to `~/.pi/agent/models.json`.

For custom APIs or OAuth flows, create an extension using `pi.registerProvider()`.

See the [Pi providers documentation](https://pi.dev/docs/providers) for the full list.

## pi-cloak configuration

Create `~/.pi/agent/cloak.json` to redact secrets from files the agent reads:

```json
{
  "enabled": true,
  "cloakCharacter": "*",
  "patterns": [
    {
      "filePattern": "**/.env*",
      "cloakPattern": "(API_KEY|TOKEN|SECRET)=.*",
      "replace": "$1=***"
    }
  ]
}
```

## Local development

```bash
cd pi-dev-setup
./install.sh
pi
```
