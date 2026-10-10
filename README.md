# token-shunt

Route large file reads and noisy command output to a cheap worker model so they
never consume your main Claude Code context window.

**Real-world result: ~2.5 M tokens saved across 6 delegations (99% mean context
reduction) in a single project.**

---

## How it works

| Without shunt | With shunt |
|---|---|
| You read a 1 000-line file → ~25 k tokens enter your context | Worker reads it, returns ~100-token bullet summary → you stay lean |
| Build output floods 500 lines → all dumped into context | Worker summarizes errors/failures → you see 10 concise lines |

Three hooks fire automatically on `Read` and `Bash` tool calls:

- **shunt-hook-read** — blocks whole-file reads above the line threshold; suggests `shunt-bulk-read.sh`
- **shunt-hook-bash** — blocks plain `cat`/`bat` dumps of large files
- **shunt-hook-cmd** — transparently rewraps known noisy build/test commands (`mvn`, `gradle`, `pytest`, `cargo test`, `npm test`, …) through the summarizer

---

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) (`claude` CLI in PATH)
- `jq`
- `shasum` (macOS built-in; Linux: `coreutils`)

---

## Installation

```bash
git clone https://github.com/YOUR_USERNAME/token-shunt.git
cd token-shunt
chmod +x install.sh
./install.sh
```

Then **restart Claude Code** (or start a new session) to activate the hooks.

---

## Usage

### Delegate a large file read

```bash
~/.claude/scripts/shunt-bulk-read.sh "what does this class do?" path/to/BigFile.java
```

Returns concise, line-cited bullets. The file never enters your main context.
Repeated questions about unchanged files are served from cache at 0 tokens.

### Delegate code generation

```bash
~/.claude/scripts/shunt-code-write.sh src/gen/Foo.java "generate a JPA entity for table orders" src/model/Customer.java
```

Writes the file to disk; only the path + line count return to you.

### Run a noisy command with summarization

```bash
~/.claude/scripts/shunt-run.sh mvn test
# or
~/.claude/scripts/shunt-run.sh -c "npm test 2>&1"
```

Output under the line threshold passes through unchanged; larger output is
summarized by the worker and the raw file path is printed for drill-down.

### Slash commands (inside Claude Code)

| Command | Description |
|---|---|
| `/shunt-stats` | Cumulative tokens saved |
| `/shunt-budget` | Today's worker spend vs budget |
| `/shunt-off` | Temporarily disable hooks |
| `/shunt-on` | Re-enable hooks |

---

## Configuration

All config lives in `~/.claude/scripts/shunt-config.sh`. Override with env vars:

| Variable | Default | Description |
|---|---|---|
| `SHUNT_WORKER_MODEL` | `claude-haiku-4-5-20251001` | Model for single-tier writes/runs |
| `SHUNT_MODEL_TIERS` | `claude-haiku-4-5-20251001 claude-sonnet-4-6` | Escalation ladder for bulk-read (cheapest first) |
| `SHUNT_MIN_LINES` | `350` | Line threshold that triggers delegation |
| `SHUNT_MAX_CHARS` | `400000` | Hard cap on worker prompt size (~100k tokens) |
| `SHUNT_CACHE` | `1` | Enable/disable answer cache (`0` to disable) |
| `SHUNT_CACHE_DIR` | `~/.claude/shunt-cache` | Cache directory |
| `SHUNT_DAILY_BUDGET` | `0` (unlimited) | Max worker tokens/day; prints a warning when exceeded |

---

## Uninstall

```bash
./uninstall.sh
```

Removes scripts, skill, and hook entries from `~/.claude/settings.json`.

---

## Notes

- Delegation adds ~10–30 s latency per call — worth it for large I/O, not for small files.
- The worker is blocked from calling tools (Read, Write, Bash, etc.) — it only processes the text you send it.
- **Do not delegate** code that requires real reasoning (security, concurrency, tricky algorithms) — use the main model for those.
- Binary files (images, PDFs) are always passed through to the native Read tool, not delegated.

---

## License

MIT
