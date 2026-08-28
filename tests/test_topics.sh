#!/usr/bin/env bash
# Every competency in every topic file must carry all four blocks.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
shopt -s nullglob
files=("$root"/topics/*.md)
[ "${#files[@]}" -gt 0 ] || { echo "FAIL no topic files found"; exit 1; }

for f in "${files[@]}"; do
  name="$(basename "$f")"
  comps="$(grep -c '^## Competency: ' "$f" || true)"
  if [ "$comps" -lt 1 ]; then
    printf 'FAIL %s has no competencies\n' "$name"; fail=1; continue
  fi
  for block in "### Why this matters" "### Level 1" "### Level 2" \
               "### Level 3" "### Common misconceptions"; do
    n="$(grep -c "^$block" "$f" || true)"
    if [ "$n" = "$comps" ]; then
      printf 'ok   %s: %s present for all %s competencies\n' "$name" "$block" "$comps"
    else
      printf 'FAIL %s: found %s of "%s", expected %s\n' "$name" "$n" "$block" "$comps"
      fail=1
    fi
  done
done
exit "$fail"
