#!/usr/bin/env bash
# Show cumulative token-shunt savings from the metrics log.
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/shunt-config.sh"

if [ ! -s "$SHUNT_METRICS" ]; then
  echo "No metrics yet at $SHUNT_METRICS — run some delegations first."
  exit 0
fi

jq -rs '
  (map(.in_chars)  | add) as $in |
  (map(.out_chars) | add) as $out |
  (map(.est_saved_tokens) | add) as $savedtok |
  ($in / 4 | floor) as $intok |
  ($out / 4 | floor) as $outtok |
  {
    delegations: length,
    bulk_reads:  ([.[]|select(.mode=="bulk-read")]|length),
    code_writes: ([.[]|select(.mode=="code-write")]|length),
    cache_hits:  ([.[]|select(.cached==true)]|length),
    intok: $intok, outtok: $outtok, savedtok: $savedtok,
    pct: (if $in>0 then (100 - ($out*100/$in)) | floor else 0 end)
  } |
  "Token-Shunt savings\n" +
  "===================\n" +
  "Delegations : \(.delegations)  (bulk-read \(.bulk_reads), code-write \(.code_writes), cache hits \(.cache_hits))\n" +
  "Sent to worker (would have hit main model) : ~\(.intok) tok\n" +
  "Returned to main model                     : ~\(.outtok) tok\n" +
  "Estimated tokens saved                     : ~\(.savedtok) tok\n" +
  "Mean context reduction                     : \(.pct)%"
' "$SHUNT_METRICS"
