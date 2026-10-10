#!/usr/bin/env bash
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/shunt-config.sh"
spent=$(shunt_today_spent)
saved=$( [ -s "$SHUNT_METRICS" ] && jq -rs --arg d "$(date +%Y-%m-%d)" '[.[]|select(.day==$d)|.est_saved_tokens]|add // 0' "$SHUNT_METRICS" || echo 0 )
echo "Token-Shunt — today ($(date +%Y-%m-%d))"
echo "==================================="
echo "Worker tokens spent : ~${spent}"
echo "Tokens saved        : ~${saved}"
if [ "$SHUNT_DAILY_BUDGET" -gt 0 ]; then
  echo "Daily worker budget : ${SHUNT_DAILY_BUDGET}  (left: $(( SHUNT_DAILY_BUDGET - spent )))"
else
  echo "Daily worker budget : unlimited  (set SHUNT_DAILY_BUDGET to cap)"
fi
echo
echo "Note: this tracks the shunt WORKER. For your plan-wide daily usage use /status or /cost."
