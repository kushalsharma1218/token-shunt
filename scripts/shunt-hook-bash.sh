#!/usr/bin/env bash
# PreToolUse hook (Bash): redirect whole-file dumps (cat/less/more/bat) of large files.
# Conservative: only triggers on a clear single-file dump of an existing large file.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/shunt-config.sh"

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
if [ -z "$cmd" ]; then exit 0; fi

candidate="$(printf '%s\n' "$cmd" | grep -oE '(^|[;&|]) *(cat|bat|less|more) +[^ |;&<>]+' | head -1)"
if [ -z "$candidate" ]; then exit 0; fi

file="$(printf '%s' "$candidate" | sed -E 's/.*(cat|bat|less|more) +//')"
file="${file%\"}"; file="${file#\"}"; file="${file%\'}"; file="${file#\'}"
case "$file" in "~"*) file="${HOME}${file#\~}";; esac
if [ ! -f "$file" ]; then exit 0; fi

lines=$(wc -l < "$file" 2>/dev/null | tr -d ' ')
lines=${lines:-0}
if [ "$lines" -lt "$SHUNT_MIN_LINES" ]; then exit 0; fi

reason="This command dumps the whole file '$file' ($lines lines, >= $SHUNT_MIN_LINES) into your context, wasting tokens. To ANSWER A QUESTION about it, run:
  ~/.claude/scripts/shunt-bulk-read.sh \"<your question>\" \"$file\"
If you need specific lines, use a targeted command (grep -n PATTERN, sed -n 'A,Bp', head/tail) to fetch only what you need."

jq -n --arg r "$reason" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
exit 0
