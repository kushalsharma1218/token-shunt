#!/usr/bin/env bash
# PreToolUse hook (Bash): transparently route noisy build/test commands through the
# cheap-worker summarizer. Rewrites the command via updatedInput -- no extra round trip.
# Conservative: only a fixed allowlist of build/test tools, and only when output is unbounded.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/shunt-config.sh"

RUNNER="$DIR/shunt-run.sh"
[ -x "$RUNNER" ] || exit 0

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.tool_input.command // empty')"
[ -z "$cmd" ] && exit 0

# Never re-wrap something already going through the shunt (infinite loop guard).
case "$cmd" in *shunt-run*|*shunt-bulk-read*) exit 0;; esac

# Output already bounded by a limiter -> it cannot flood the context; leave it alone.
if printf '%s' "$cmd" | grep -qE '\|[[:space:]]*(head|tail|wc)([[:space:]]|$)'; then exit 0; fi

# Allowlist: build/test tools whose full-run output is reliably large.
# Anchored at start of the string or after a shell separator.
ALLOW='(^|[;&|][[:space:]]*|&&[[:space:]]*|\|\|[[:space:]]*)[[:space:]]*'
ALLOW+='((\./)?mvnw?|(\./)?gradlew?|pytest|cargo[[:space:]]+(build|test)|go[[:space:]]+test'
ALLOW+='|(npm|yarn|pnpm)[[:space:]]+([a-z-]+[[:space:]]+)*(test|build|install|ci))([[:space:]]|$)'
printf '%s' "$cmd" | grep -qE "$ALLOW" || exit 0

wrapped="$(RUNNER="$RUNNER" jq -rn --arg c "$cmd" '(env.RUNNER|@sh) + " -c " + ($c|@sh)')"

jq -n --arg w "$wrapped" --arg n "$SHUNT_MIN_LINES" '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    updatedInput: { command: $w }
  },
  systemMessage: ("[token-shunt] noisy build/test command wrapped in shunt-run.sh; output over " + $n + " lines is summarized by the worker, raw output path is printed on stderr.")
}'
exit 0
