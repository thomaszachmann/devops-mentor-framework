#!/usr/bin/env bash
# Validates the two plugin manifests. Requires jq.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
check() { # check <description> <actual> <expected>
  if [ "$2" = "$3" ]; then printf 'ok   %s\n' "$1"
  else printf 'FAIL %s: got %s, want %s\n' "$1" "$2" "$3"; fail=1; fi
}

jq empty "$root/.claude-plugin/plugin.json" 2>/dev/null \
  && printf 'ok   plugin.json is valid JSON\n' \
  || { printf 'FAIL plugin.json is not valid JSON\n'; fail=1; }
jq empty "$root/.claude-plugin/marketplace.json" 2>/dev/null \
  && printf 'ok   marketplace.json is valid JSON\n' \
  || { printf 'FAIL marketplace.json is not valid JSON\n'; fail=1; }

check "plugin name" \
  "$(jq -r '.name' "$root/.claude-plugin/plugin.json" 2>/dev/null)" "devops-mentor"
check "plugin license" \
  "$(jq -r '.license' "$root/.claude-plugin/plugin.json" 2>/dev/null)" "MIT"
check "marketplace name" \
  "$(jq -r '.name' "$root/.claude-plugin/marketplace.json" 2>/dev/null)" "devops-mentor-framework"
check "marketplace lists the plugin" \
  "$(jq -r '.plugins[0].name' "$root/.claude-plugin/marketplace.json" 2>/dev/null)" "devops-mentor"
check "marketplace owner is set" \
  "$(jq -r '.owner.name != null' "$root/.claude-plugin/marketplace.json" 2>/dev/null)" "true"

exit "$fail"
