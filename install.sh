#!/usr/bin/env bash
# Install token-shunt: copies scripts + skill and patches Claude Code hooks.
set -euo pipefail

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
SCRIPTS_DST="$CLAUDE_HOME/scripts"
SKILLS_DST="$CLAUDE_HOME/skills/token-shunt"
SETTINGS="$CLAUDE_HOME/settings.json"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---- deps check ----
for dep in jq shasum claude; do
  command -v "$dep" &>/dev/null || { echo "error: '$dep' not found in PATH"; exit 1; }
done

# ---- copy scripts ----
mkdir -p "$SCRIPTS_DST" "$SKILLS_DST"
cp "$REPO_DIR/scripts/"*.sh "$SCRIPTS_DST/"
chmod +x "$SCRIPTS_DST/shunt-"*.sh
echo "  scripts -> $SCRIPTS_DST"

# ---- copy skill ----
cp "$REPO_DIR/skills/token-shunt/SKILL.md" "$SKILLS_DST/"
echo "  skill   -> $SKILLS_DST"

# ---- patch settings.json hooks ----
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Build the three hook entries with the actual install path
READ_HOOK="$SCRIPTS_DST/shunt-hook-read.sh"
BASH_HOOK="$SCRIPTS_DST/shunt-hook-bash.sh"
CMD_HOOK="$SCRIPTS_DST/shunt-hook-cmd.sh"

tmp="$(mktemp)"
jq --arg rh "$READ_HOOK" --arg bh "$BASH_HOOK" --arg ch "$CMD_HOOK" '
  # ensure top-level keys exist
  .hooks //= {}
  | .hooks.PreToolUse //= []

  # remove any existing shunt hook matchers so we do not duplicate on re-install
  | .hooks.PreToolUse |= map(select(.matcher != "Read" and .matcher != "Bash"))

  # add fresh entries
  | .hooks.PreToolUse += [
      {"matcher":"Read",  "hooks":[{"type":"command","command":$rh}]},
      {"matcher":"Bash",  "hooks":[{"type":"command","command":$bh},
                                   {"type":"command","command":$ch}]}
    ]
' "$SETTINGS" > "$tmp" && mv "$tmp" "$SETTINGS"
echo "  hooks   -> $SETTINGS"

echo ""
echo "token-shunt installed successfully."
echo "Restart Claude Code (or start a new session) to activate the hooks."
echo ""
echo "Quick test:  ~/.claude/scripts/shunt-stats.sh"
echo "Config:      edit $SCRIPTS_DST/shunt-config.sh  (or set env vars)"
