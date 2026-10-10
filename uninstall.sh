#!/usr/bin/env bash
# Remove token-shunt scripts, skill, and hooks from Claude Code settings.
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SCRIPTS_DST="$CLAUDE_HOME/scripts"
SKILLS_DST="$CLAUDE_HOME/skills/token-shunt"
SETTINGS="$CLAUDE_HOME/settings.json"

# ---- remove scripts ----
if ls "$SCRIPTS_DST/shunt-"*.sh &>/dev/null 2>&1; then
  rm -f "$SCRIPTS_DST/shunt-"*.sh
  echo "  removed scripts from $SCRIPTS_DST"
fi

# ---- remove skill ----
if [ -d "$SKILLS_DST" ]; then
  rm -rf "$SKILLS_DST"
  echo "  removed skill from $SKILLS_DST"
fi

# ---- remove hooks from settings.json ----
if [ -f "$SETTINGS" ] && command -v jq &>/dev/null; then
  tmp="$(mktemp)"
  jq '
    if .hooks.PreToolUse then
      .hooks.PreToolUse |= map(select(.matcher != "Read" and .matcher != "Bash"))
    else . end
  ' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
  echo "  removed hooks from $SETTINGS"
fi

echo ""
echo "token-shunt uninstalled. Restart Claude Code to deactivate hooks."
