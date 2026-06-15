# pi-dev-setup

User-level pi extensions for git workflow, web search, and agent state.

## Install on a new host

```bash
git clone https://github.com/davis7dotsh/pi-dev-setup.git
cd pi-dev-setup
./install.sh
```

This copies the extensions into `~/.pi/agent/extensions/` and installs their npm dependencies.

## Update

Pull the repo and re-run `./install.sh`. It overwrites the tracked extensions with the latest versions.

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
