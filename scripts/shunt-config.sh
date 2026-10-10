# Token-shunt shared config + helpers (sourced by scripts + hooks)
SHUNT_HOME="${SHUNT_HOME:-$HOME/.claude}"
SHUNT_WORKER_MODEL="${SHUNT_WORKER_MODEL:-claude-haiku-4-5-20251001}"
# escalation ladder (cheap -> capable). Haiku answers first; escalates only if it can't.
SHUNT_MODEL_TIERS="${SHUNT_MODEL_TIERS:-claude-haiku-4-5-20251001 claude-sonnet-4-6}"
SHUNT_MIN_LINES="${SHUNT_MIN_LINES:-350}"
# hard ceiling on what one worker prompt may carry (~4 chars/token; keeps us under a 200k window)
SHUNT_MAX_CHARS="${SHUNT_MAX_CHARS:-400000}"
SHUNT_CACHE="${SHUNT_CACHE:-1}"
SHUNT_CACHE_DIR="${SHUNT_CACHE_DIR:-$SHUNT_HOME/shunt-cache}"
SHUNT_METRICS="${SHUNT_METRICS:-$SHUNT_HOME/shunt-metrics.jsonl}"
SHUNT_DISABLED_FLAG="${SHUNT_DISABLED_FLAG:-$SHUNT_HOME/shunt-disabled}"
SHUNT_DAILY_BUDGET="${SHUNT_DAILY_BUDGET:-0}"   # tokens/day the worker may spend; 0 = unlimited
SHUNT_NO_TOOLS=(--disallowedTools Read Write Edit Bash Grep Glob WebFetch WebSearch NotebookEdit Task)

shunt_tok(){ echo $(( ${1:-0} / 4 )); }              # ~4 chars/token

# append one metric row. args: mode in_chars out_chars files cached(true|false) [tier] [raw_chars]
# raw_chars = context actually avoided (defaults to in_chars); the two differ when a payload was
# reduced to fit the worker's window -- savings then track raw, worker spend tracks in_chars.
shunt_log_metric(){
  local mode="$1" ic="${2:-0}" oc="${3:-0}" nf="${4:-0}" cached="${5:-false}" tier="${6:-}" rc="${7:-}"
  [ -z "$rc" ] && rc="$ic"
  local saved=$(( rc - oc )); [ "$saved" -lt 0 ] && saved=0
  printf '{"ts":%s,"day":"%s","mode":"%s","in_chars":%s,"out_chars":%s,"files":%s,"cached":%s,"tier":"%s","saved_chars":%s,"est_saved_tokens":%s,"worker_in_tok":%s,"worker_out_tok":%s}\n' \
    "$(date +%s)" "$(date +%Y-%m-%d)" "$mode" "$ic" "$oc" "$nf" "$cached" "$tier" "$saved" "$(( saved/4 ))" "$(( ic/4 ))" "$(( oc/4 ))" \
    >> "$SHUNT_METRICS" 2>/dev/null || true
}

# tokens the worker actually spent TODAY (input+output of non-cached calls)
shunt_today_spent(){
  [ -s "$SHUNT_METRICS" ] || { echo 0; return; }
  jq -rs --arg d "$(date +%Y-%m-%d)" '
    [ .[] | select(.day==$d and .cached==false) | (.worker_in_tok + .worker_out_tok) ] | add // 0
  ' "$SHUNT_METRICS" 2>/dev/null || echo 0
}
