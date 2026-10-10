#!/usr/bin/env bash
# PreToolUse hook (Read): redirect oversized whole-file reads to the bulk reader.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/shunt-config.sh"

input="$(cat)"
fp="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty')"
limit="$(printf '%s' "$input" | jq -r '.tool_input.limit // empty')"
offset="$(printf '%s' "$input" | jq -r '.tool_input.offset // empty')"

# Targeted read (limit/offset present) -> allow silently
if [ -n "$limit" ] || [ -n "$offset" ]; then exit 0; fi
# No path or not a regular file -> allow
if [ -z "$fp" ] || [ ! -f "$fp" ]; then exit 0; fi
# Binary files (images, PDFs) are read natively by the Read tool; the text worker cannot help.
if [ "$(file -b --mime-encoding "$fp" 2>/dev/null)" = "binary" ]; then exit 0; fi

lines=$(wc -l < "$fp" 2>/dev/null | tr -d ' ')
lines=${lines:-0}
if [ "$lines" -lt "$SHUNT_MIN_LINES" ]; then exit 0; fi

reason="File '$fp' is $lines lines (>= $SHUNT_MIN_LINES). Reading it whole burns tokens. To ANSWER A QUESTION about it, delegate to the cheap worker instead:
  ~/.claude/scripts/shunt-bulk-read.sh \"<your question>\" \"$fp\"
It returns a concise, line-cited answer without loading the file into your context. If you truly need exact lines to EDIT, re-read with a limit/offset to fetch only the range you need."

jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
