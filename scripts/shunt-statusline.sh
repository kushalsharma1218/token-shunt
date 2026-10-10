#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/shunt-config.sh"
in=$(cat)
dir=$(printf '%s' "$in" | jq -r '.workspace.current_dir // .cwd // ""' 2>/dev/null); dir=$(basename "${dir:-$PWD}")
model=$(printf '%s' "$in" | jq -r '.model.display_name // .model.id // "?"' 2>/dev/null)
saved=$( [ -s "$SHUNT_METRICS" ] && jq -rs --arg d "$(date +%Y-%m-%d)" '[.[]|select(.day==$d)|.est_saved_tokens]|add // 0' "$SHUNT_METRICS" || echo 0 )
human=$saved; [ "$saved" -ge 1000 ] && human="$(( saved/1000 )).$(( (saved%1000)/100 ))k"
off=""; [ -f "$SHUNT_DISABLED_FLAG" ] && off=" ⏸off"
printf '📁 %s · 🤖 %s · 🪙 %s saved today%s' "$dir" "$model" "$human" "$off"
