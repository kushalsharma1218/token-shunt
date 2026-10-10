---
name: token-shunt
description: Delegate token-heavy grunt work (reading large files, generating boilerplate/tests/config) to a cheap worker model so it never enters the main context. Use when reading files over ~350 lines to answer a question, or generating routine code from a spec + reference.
---

# Token Shunt

Route grunt work to a cheap worker model (`claude-haiku-4-5`) so large inputs and
generated outputs never consume the main agent's context. Reasoning, editing, and
subtle-bug work stay with the main model.

## When to delegate a READ

Before reading a file **whole** to answer a question, if it is large (~350+ lines):

```
~/.claude/scripts/shunt-bulk-read.sh "your question" path/to/file [more files...]
```

Returns concise, line-cited bullets. The file contents enter only the worker's
context. Follow-up questions about the same files are cheap — just call it again.

**Do NOT delegate** when you need exact lines to edit — read that range directly
with an offset/limit. The worker answers questions; it does not edit.

## When to delegate a WRITE

For boilerplate, tests, config, or DTOs generated from a spec (optionally matching
reference files):

```
~/.claude/scripts/shunt-code-write.sh path/to/output "spec text or spec-file" [reference files...]
```

Writes the result straight to disk and reports only the path + line count — the
generated code never enters your context. Afterward, review/adjust the file
normally if needed.

**Do NOT delegate** code that requires real reasoning (concurrency, security,
tricky algorithms) — worker models miss subtle bugs. Write those yourself.

## Caching & stats

- bulk-read answers are cached by (model + question + file contents). Asking the
  same question about unchanged files returns instantly at 0 tokens; editing a
  file auto-invalidates its cache.
- `~/.claude/scripts/shunt-stats.sh` prints cumulative tokens saved and mean
  context reduction (metrics logged to `~/.claude/shunt-metrics.jsonl`).

## Config

Env vars: `SHUNT_WORKER_MODEL` (default `claude-haiku-4-5-20251001`),
`SHUNT_MIN_LINES` (default `350`), `SHUNT_CACHE` (`1`/`0`).

## Notes

- Delegation adds ~10–30s latency per call; worth it for large I/O, not tiny files.
- PreToolUse hooks also nudge you here automatically when you try to read/dump a
  large file whole.

## v2 additions

- **Large command output**: run noisy commands (test suites, recursive greps, log
  dumps) via `~/.claude/scripts/shunt-run.sh <command>` — output over the line
  threshold is summarized by the worker; raw output is saved to a temp file.
- **Escalation ladder**: bulk-read tries `SHUNT_MODEL_TIERS` cheapest-first; if a
  tier replies `ESCALATE: ...` it retries the next tier up (default Haiku→Sonnet).
- **Predict / budget**: `shunt-estimate.sh <files>` predicts token cost before
  reading; `shunt-budget.sh` shows today's worker spend vs `SHUNT_DAILY_BUDGET`.
- **Slash commands**: `/shunt-stats`, `/shunt-budget`, `/shunt-off`, `/shunt-on`.
- **Statusline** shows `📁 dir · 🤖 model · 🪙 N saved today`.
