#!/usr/bin/env bash
# Delegate boilerplate/test/config generation to a cheap worker model.
# The generated code is written straight to disk; it never enters the main agent context.
# Usage: shunt-code-write.sh <output_path> <spec-or-specfile> [reference_file ...]
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/shunt-config.sh"

if [ "$#" -lt 2 ]; then
  echo "usage: shunt-code-write.sh <output_path> <spec-or-specfile> [reference_file ...]" >&2
  exit 2
fi
OUT="$1"; SPEC_ARG="$2"; shift 2
if [ -f "$SPEC_ARG" ]; then SPEC="$(cat "$SPEC_ARG")"; else SPEC="$SPEC_ARG"; fi

refs=""
for f in "$@"; do
  [ -f "$f" ] || { echo "warning: skipping non-file ref: $f" >&2; continue; }
  refs+=$'\n'"<reference path=\"$f\">"$'\n'"$(cat "$f")"$'\n'"</reference>"$'\n'
done

read -r -d '' SYS <<'EOF' || true
You are a code generator. Output ONLY the contents of the requested file.
No explanations. No markdown code fences. No commentary before or after.
Match the style, imports, naming, and conventions of any reference files provided.
The output must be the exact file contents, ready to write to disk.
EOF

PROMPT="Target file: $OUT"$'\n'"Spec: $SPEC"
[ -n "$refs" ] && PROMPT+=$'\n\n'"Reference files:"$'\n'"$refs"

mkdir -p "$(dirname "$OUT")"
tmp="$(mktemp)"
printf '%s' "$PROMPT" | claude -p --model "$SHUNT_WORKER_MODEL" \
  --system-prompt "$SYS" "${SHUNT_NO_TOOLS[@]}" > "$tmp"

# strip accidental wrapping code fences, if the model added them anyway
if head -1 "$tmp" | grep -qE '^[[:space:]]*```'; then
  sed -i '' '1d' "$tmp"
  if tail -1 "$tmp" | grep -qE '^[[:space:]]*```'; then sed -i '' -e '$d' "$tmp"; fi
fi

mv "$tmp" "$OUT"
gen_chars=$(wc -c < "$OUT" | tr -d ' ')
ref_chars=${#refs}; spec_chars=${#SPEC}
msg="wrote $OUT ($(wc -l < "$OUT" | tr -d ' ') lines) via $SHUNT_WORKER_MODEL"
# without delegation the main model would ingest the references AND emit the generated code;
# with delegation it sees only this confirmation line.
shunt_log_metric "code-write" "$(( ref_chars + spec_chars + gen_chars ))" "${#msg}" "$#" "false"
echo "$msg"
