# Headless compatibility report

Tested by running commands with `pi -p "<command>"` and `pi --mode json -p "<command>"`.

## Summary

| Extension | Headless | Notes |
|---|---|---|
| `answer.ts` | ❌ No | Requires TUI (`ctx.ui.custom`). Headless: silently does nothing. |
| `diff.ts` | ✅ Yes | Prints changed files to stdout in headless mode; falls back to live git status. |
| `firecrawl-search.ts` | ✅ Yes | Tools (`search`, `scrape`) have no TUI dependency. |
| `git-status-widget.ts` | ⚠️ Partial | Registers handlers but uses `ctx.ui.setWidget`, which is a no-op headless. Does not break. |
| `goal.ts` | ✅ Yes | `/goal` and tools (`create_goal`, `update_goal`, `get_goal`) emit custom messages that work in JSON/print mode. |
| `herdr-agent-state.ts` | ✅ Yes | No UI; reports state over a socket. No-op when herdr is absent. |
| `lg.ts` | ❌ No | `/lg` sends a user message, which triggers an agent turn. The `tps-tracker.ts` extension throws a stale-ctx error during that turn and hangs. |
| `pi-cloak/index.ts` | ✅ Yes | Intercepts `tool_result` events with no UI dependency. |
| `tps-tracker.ts` | ⚠️ Partial | Uses `ctx.ui.setStatus`/`notify`; no-op headless. However, it throws a stale-ctx error during agent turns in print/JSON mode, which breaks other commands that trigger agent turns (e.g., `/lg`, `/yeet`). |
| `yeet.ts` | ❌ No | `/yeet` sends a user message, which triggers an agent turn. The `tps-tracker.ts` extension throws a stale-ctx error during that turn and hangs. |

## Detailed findings

### `answer.ts`
- Command: `/answer`
- Headless behavior: returns immediately with no output.
- Reason: handler starts with `if (!ctx.hasUI) { ctx.ui.notify(...); return; }`. `ctx.ui.notify` is a no-op in print/JSON mode, so the command exits silently.

### `diff.ts`
- Command: `/diff`, `/diff list`, `/diff clear`
- Headless behavior: works.
- Output example:
  ```
  [diff] Changed files:
  - extensions/diff.ts
  ```
- Notes: was patched to print to stdout and fall back to live git status when the in-memory tracker is empty.

### `firecrawl-search.ts`
- Tools: `search`, `scrape`
- Headless behavior: works when the LLM invokes the tools.
- Notes: no UI usage; returns text content and details.

### `git-status-widget.ts`
- Headless behavior: registers event handlers but produces no visible output.
- Notes: only calls `ctx.ui.setWidget`, which is TUI-only. Does not throw or hang on its own.

### `goal.ts`
- Command: `/goal`
- Tools: `create_goal`, `update_goal`, `get_goal`
- Headless behavior: works.
- JSON output: emits a `goal-ui` custom message with usage text.
- Notes: tools have no UI dependency.

### `herdr-agent-state.ts`
- Headless behavior: works.
- Notes: no UI usage; state reporting over Unix socket. Returns early if herdr env vars are not set.

### `lg.ts`
- Command: `/lg`
- Headless behavior: hangs/times out.
- Reason: `/lg` calls `pi.sendUserMessage(LG_PROMPT)`, which triggers an agent turn. During that turn, `tps-tracker.ts` throws:
  ```
  Extension error (/home/zin/.pi/agent/extensions/tps-tracker.ts): This extension ctx is stale after session replacement or reload.
  ```
  The error repeats and the process never completes.

### `pi-cloak/index.ts`
- Headless behavior: works.
- Notes: intercepts `tool_result` events and masks text content. No UI dependency.

### `tps-tracker.ts`
- Headless behavior: partial/no meaningful output.
- Notes:
  - In TUI mode: shows live tokens-per-second in the status bar.
  - In headless mode: `ctx.ui.setStatus`/`notify` are no-ops, so no output.
  - **Critical**: throws a stale-ctx error during agent turns in print/JSON mode, breaking `/lg`, `/yeet`, and any other command/tool that triggers an LLM turn.

### `yeet.ts`
- Command: `/yeet`
- Headless behavior: hangs/times out.
- Reason: same as `/lg` — sends a user message that triggers an agent turn, and `tps-tracker.ts` throws a stale-ctx error.

## Recommendations for headless use

- Keep `diff.ts`, `firecrawl-search.ts`, `goal.ts`, `herdr-agent-state.ts`, `pi-cloak/index.ts`.
- Avoid `tps-tracker.ts` in headless workflows until the stale-ctx issue is resolved.
- `git-status-widget.ts` is harmless headless but provides no value.
- `answer.ts`, `lg.ts`, `yeet.ts` are not useful headless as currently implemented.
