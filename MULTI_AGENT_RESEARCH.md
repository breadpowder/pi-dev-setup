# Multi-Agent Orchestration & Parallel Worktree Research

Research notes for the `pi-dev-setup` repo. Goal: identify popular, high-quality open-source solutions for multi-agent orchestration and parallel git worktree development workflows that work with Pi (or similar agents), and document how the most popular Pi-native project extends Pi.

## 1. Top Pi-Native Multi-Agent Extensions (>500 GitHub stars)

| Project | Stars | What it adds |
|---------|-------|--------------|
| [can1357/oh-my-pi](https://github.com/can1357/oh-my-pi) | ~13K | Fork of Pi with native subagents, LSP, debugger, eval kernels, and memory. |
| [nicobailon/pi-messenger](https://github.com/nicobailon/pi-messenger) | ~611 | Multi-agent crew orchestration and agent-to-agent messaging. |
| [HazAT/pi-interactive-subagents](https://github.com/HazAT/pi-interactive-subagents) | ~504 | Async subagents spawned in separate terminal panes. |

For a deep-dive extension study, `oh-my-pi` is the clear target because it is a **fork of Pi itself** and therefore shows the canonical way to add subagent, LSP, debug, eval, and memory capabilities when you are not limited to the extension API.

## 2. Parallel Git Worktree Development Workflows

| Solution | Approach | Pi-native? |
|----------|----------|------------|
| EnsoAI | AI-native IDE built around parallel worktrees and review agents | No — standalone product |
| oh-my-pi `task/worktree.ts` | Spawns subagents in isolated git worktrees, merges patches back | Yes — built-in |
| git worktree + tmux/terminal panes | Manual parallel branches with separate agents | Partial — no automation |

Conclusion: for Pi users, the only automated parallel-worktree solution is the one inside `oh-my-pi`.

## 3. How oh-my-pi Extends Pi (Top-Down)

`oh-my-pi` is a fork, so it can change core files (`AgentSession`, `AgentLoop`, tool registration). The monorepo structure is:

```
packages/
├── agent/           # core agent loop
├── ai/              # LLM abstraction
├── coding-agent/    # CLI, tools, session, extensibility
├── natives/         # Rust bindings (search, grep, shell, AST)
├── tui/             # terminal UI
├── swarm-extension/ # DAG-based multi-agent orchestration
└── mnemopi/         # local SQLite memory backend
```

All features converge in `packages/coding-agent/src/tools/index.ts` inside `createTools(session)`, which builds ~32 tools gated by `session.settings`. They are then injected into the system prompt at session creation time (`src/sdk.ts`).

---

### 3.1 Subagents + Worktree Isolation

**Files:**
- `src/task/index.ts` — `TaskTool`
- `src/task/executor.ts` — subagent execution
- `src/task/worktree.ts` — git isolation and patch merge
- `src/task/discovery.ts` — agent definition discovery
- `src/irc/bus.ts` — agent-to-agent messaging bus

**Control flow:**

```
agent calls task() tool
  → TaskTool
    → discovers agent definitions (bundled, ~/.omp/agent/agents/*.md, .omp/agents/*.md)
    → resolves model per agent role
    → ensuresIsolation()
      → captures git baseline (HEAD, staged, unstaged, untracked patches)
      → forks isolated branch using git worktree
      → uses APFS/Btrfs/ZFS reflinks when available for near-zero-copy
    → runSubprocess()
      → creates child AgentSession with custom system prompt
      → assigns tools/skills per agent definition
      → streams AgentEvents via EventBus channels
    → mergeTaskBranches()
      → applies patches back to parent
      → commits to branch
    → returns schema-validated JSON result
```

**Technique:** Child `AgentSession`s are created **in-process**, not as separate CLI processes. This avoids IPC overhead and lets the parent read child state directly.

**IRC bus (`src/irc/bus.ts`):** A singleton mailbox system. Agents resolve recipients via `AgentRegistry`. Messages can:
- revive parked agents (`AgentLifecycleManager`)
- wake idle agents with a real turn
- queue as a non-interrupting aside for busy agents

---

### 3.2 LSP Integration

**Files:**
- `src/lsp/index.ts` — `LspTool`
- `src/lsp/client.ts` — persistent LSP client management
- `src/lsp/lspmux.ts` — LSP server multiplexing
- `src/lsp/edits.ts` — workspace edit application
- `src/lsp/diagnostics-ledger.ts` — cross-turn diagnostics

**Control flow:**

```
session starts
  → LSP warmup in background
    → getOrCreateClient() per language server
    → lspmux detection for server sharing
    → idle timeout management

agent calls lsp(operation, params)
  → LspTool
    → sendRequest / sendNotification via JSON-RPC over stdin/stdout
    → 14 LSP operations (diagnostics, hover, definitions, references,
       rename, code actions, symbols, formatting, raw requests, etc.)
    → applyWorkspaceEdit()
      → applies text edits bottom-to-top to preserve indices
      → handles CreateFile / DeleteFile / RenameFile
    → notifySaved() triggers diagnostics re-check

after every write/edit:
  → syncContent() sends document changes to LSP
  → published diagnostics queued as DeferredDiagnosticsEntry
  → injected into agent context at next yield boundary
```

**Technique:** LSP servers are **persistent subprocesses**. `lspmux` shares server instances across editor windows. A **diagnostics ledger** persists feedback across agent turns so the model sees errors from its own edits. `workspace/willRenameFiles` keeps barrel files and re-exports consistent.

---

### 3.3 Debugger Integration (DAP)

**Files:**
- `src/tools/debug.ts` — `DebugTool`
- `src/dap/session.ts` — high-level session management
- `src/dap/client.ts` — DAP protocol client
- `src/dap/types.ts` — protocol types

**Control flow:**

```
agent calls debug(operation, params)
  → DebugTool
    → DapSession
      → DapClient
        → spawns DAP adapter subprocess
        → parses Content-Length-framed JSON-RPC messages
        → correlates pending requests/responses
      → 28 DAP operations:
        initialize, launch, attach
        breakpoints (source/function/instruction/data)
        threads, stackTrace, scopes, variables
        continue, next, stepIn, stepOut
        evaluate, disassemble, readMemory, writeMemory
        loadedSources, modules
```

**Technique:** Full DAP protocol implementation with **adapter auto-discovery** (`lldb-dap`, `dlv-dap`, `debugpy`, etc.). Breakpoint mutations are serialized through a queue. Supports multi-session debugging.

Typical agent workflow:
1. `debug("attach", { program: "./app", adapter: "lldb-dap" })`
2. `debug("setBreakpoints", { path: "main.c", breakpoints: [{ line: 42 }] })`
3. `debug("continue")`
4. stop at breakpoint → read stackTrace + variables
5. `debug("evaluate", { expression: "ptr->next" })`
6. repeat until root cause found

---

### 3.4 Persistent Eval Kernels with Tool Bridge

**Files:**
- `src/tools/eval.ts` — `EvalTool`
- `src/eval/index.ts` — backend dispatch
- `src/eval/py/kernel.ts` — Python subprocess kernel
- `src/eval/py/tool-bridge.ts` — Python → host tool HTTP bridge
- `src/eval/js/tool-bridge.ts` — JS tool proxy
- `src/eval/agent-bridge.ts` — `agent()` helper inside eval cells

**Control flow:**

```
agent calls eval(code, language)
  → EvalTool
    → resolves backend (Python or JavaScript)
    → Python:
      → spawns persistent subprocess running runner.py
      → NDJSON IPC over stdin/stdout
      → prelude provides `tool` proxy and `agent()` helper
      → cancellation via SIGINT → SIGTERM → SIGKILL escalation
    → JavaScript:
      → Bun worker thread with indirect-eval sandbox
      → local module loader for npm packages

tool loopback:
  Python: HTTP POST to 127.0.0.1 loopback
  JavaScript: Proxy object
    → resolves name against ToolSession
    → calls callSessionTool()

agent() helper:
  → EvalAgentBridge
    → validates args
    → checks recursion depth (max 3)
    → spawns subagent via taskExecutor
    → returns structured result
```

**Technique:** Kernels keep **persistent state** across eval calls. The bridge lets kernel code call the parent agent's tools (`read`, `search`, `task`, `agent()`) without leaving the eval cell. Depth limiting prevents runaway recursion.

---

### 3.5 Hindsight Memory

**Files:**
- `src/memory-backend/types.ts` — backend abstraction
- `src/memory-backend/resolve.ts` — backend selector
- `src/hindsight/backend.ts` — Hindsight memory backend
- `src/hindsight/state.ts` — per-session state
- `src/hindsight/client.ts` — API client
- `src/hindsight/content.ts` — query/transcript formatting
- `src/hindsight/mental-models.ts` — mental-model seeding & refresh
- `src/tools/memory-recall.ts`, `memory-retain.ts`, `memory-reflect.ts`

**Control flow:**

```
session starts
  → resolveMemoryBackend(settings)
    → picks one of: off | local | hindsight | mnemopi
  → memoryBackend.start()
    → HindsightBackend.start()
      → creates HindsightClient (HTTP to Hindsight server)
      → creates HindsightSessionState
        → resolves bank scope (per-project or shared)
        → seeds mental models from seeds.json if missing

first turn:
  → auto-recall from Hindsight bank
  → formats <memories> and <mental_models> blocks
  → injects into developer instructions

tool calls:
  retain() → debounced batch queue → POSTs tagged memories
  recall() → searches bank → returns formatted memories
  reflect() → server synthesizes answer over many memories

every Nth agent_end:
  → auto-retain posts transcript snippet (async)

session end:
  → flush retain queue
  → refresh mental models if configured
```

**Technique:** The `MemoryBackend` interface is a clean abstraction supporting three implementations. Hindsight uses a **remote vector database server**. **Mental models** are pre-computed summaries that bypass per-turn HTTP recall by being spliced directly into developer instructions. A **debounced retain queue** batches tool-initiated retains.

---

## 4. Key Takeaways for Pi Extension Authors

1. **If you can fork Pi**, the canonical pattern is:
   - Add a new tool class in `src/tools/`
   - Register it in `src/tools/index.ts` inside `createTools()`
   - Gate it behind `session.settings`
   - Inject its description into the system prompt
   - Wire lifecycle hooks into `AgentSession` and `createAgentSession()`

2. **If you must stay inside the extension API**, you cannot do what `oh-my-pi` does. You are limited to:
   - slash commands
   - tool wrappers
   - prompt templates
   - custom tools
   - event handlers

3. **Subagents from an extension** are currently best-effort:
   - Pi has an official `subagent` example (`examples/extensions/subagent/`) that defines agents in Markdown and dispatches via a tool.
   - True git worktree isolation, parent/child state sharing, and in-process child sessions require core changes.

4. **LSP/debug/eval/memory from an extension** are not realistically achievable without forking or official Pi support, because they need to:
   - persist subprocesses across turns
   - modify the system prompt dynamically
   - hook into session lifecycle
   - bridge kernel/tool execution

5. **Practical recommendation for this repo:**
   - Keep the current extension-based setup (symlinked user extensions).
   - Document that advanced multi-agent/worktree features require either `oh-my-pi` or upstream Pi support.
   - Use `task` or `subagent` examples if Pi exposes them in future releases.

---

## 5. References

- oh-my-pi source: `/home/zin/workspace/oh-my-pi`
- Pi extension examples: `/home/zin/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/examples/extensions/`
- Pi docs: `/home/zin/.npm-global/lib/node_modules/@earendil-works/pi-coding-agent/docs/`
