#!/usr/bin/env bash
# Predict token cost of reading file(s) whole vs via shunt. Usage: shunt-estimate.sh file1 [file2...]
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/shunt-config.sh"
[ "$#" -ge 1 ] || { echo "usage: shunt-estimate.sh file1 [file2 ...]" >&2; exit 2; }
total=0; nf=0
for f in "$@"; do
  [ -f "$f" ] || { echo "skip (not a file): $f" >&2; continue; }
  c=$(wc -c < "$f" | tr -d ' '); total=$((total+c)); nf=$((nf+1))
  printf '  %-40s %6s lines  ~%s tok\n' "$(basename "$f")" "$(wc -l < "$f" | tr -d ' ')" "$(( c/4 ))"
done
whole=$(( total/4 ))
echo "-------------------------------------------------------------"
echo "Reading all $nf file(s) into the MAIN model : ~${whole} tok"
echo "Via shunt (worker reads; you get a summary) : ~${whole} tok to worker, ~a few hundred back to you"
[ "$SHUNT_DAILY_BUDGET" -gt 0 ] && { s=$(shunt_today_spent); echo "Worker budget today                         : $s / $SHUNT_DAILY_BUDGET used, $(( SHUNT_DAILY_BUDGET - s )) left"; }
