#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
MENTOR_HOME="$(mktemp -d)"; export MENTOR_HOME
trap 'rm -rf "$MENTOR_HOME"' EXIT
. "$root/lib/state.sh"
hook="$root/hooks/inject-mode.sh"

run() { printf '%s' "$1" | "$hook"; }
input_for() { printf '{"session_id":"s1","cwd":"%s","hook_event_name":"UserPromptSubmit","prompt":"how do I do X"}' "$1"; }

# 1. No mode set: no output, exit 0.
out="$(run "$(input_for /a/project)")"; rc=$?
[ "$rc" = 0 ] && printf 'ok   exits 0 with no mode\n' \
  || { printf 'FAIL exit code %s with no mode\n' "$rc"; fail=1; }
[ -z "$out" ] && printf 'ok   silent with no mode\n' \
  || { printf 'FAIL expected no output, got [%s]\n' "$out"; fail=1; }

# 2. Malformed stdin must not crash.
out="$(printf 'not json at all' | "$hook")"; rc=$?
[ "$rc" = 0 ] && printf 'ok   exits 0 on malformed stdin\n' \
  || { printf 'FAIL exit code %s on malformed stdin\n' "$rc"; fail=1; }

# 3. Empty stdin must not crash.
out="$(printf '' | "$hook")"; rc=$?
[ "$rc" = 0 ] && printf 'ok   exits 0 on empty stdin\n' \
  || { printf 'FAIL exit code %s on empty stdin\n' "$rc"; fail=1; }

# 4. Mentor mode active: valid JSON with the right event name.
mentor_set_mode /a/project mentor kubernetes
out="$(run "$(input_for /a/project)")"
printf '%s' "$out" | jq empty 2>/dev/null && printf 'ok   emits valid JSON\n' \
  || { printf 'FAIL not valid JSON: [%s]\n' "$out"; fail=1; }
ev="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName' 2>/dev/null)"
[ "$ev" = "UserPromptSubmit" ] && printf 'ok   correct hookEventName\n' \
  || { printf 'FAIL hookEventName was [%s]\n' "$ev"; fail=1; }

ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"

# 5. The four invariants that make mentor mode mean anything.
for needle in "MENTOR MODE IS ACTIVE" "Rung" "genuine attempt" "Do not write to files"; do
  case "$ctx" in
    *"$needle"*) printf 'ok   context contains %s\n' "$needle" ;;
    *) printf 'FAIL context missing %s\n' "$needle"; fail=1 ;;
  esac
done

# 6. Exam mode must not inject the mentor ladder.
mentor_set_mode /c/project exam kubernetes
out="$(run "$(input_for /c/project)")"
case "$out" in
  *"MENTOR MODE IS ACTIVE"*) printf 'FAIL mentor rules leaked into exam mode\n'; fail=1 ;;
  *) printf 'ok   exam mode does not inject mentor rules\n' ;;
esac

# 7. Budget: the injected context must stay small.
# ~4 characters per token, 400 tokens -> 1600 characters.
chars="$(printf '%s' "$ctx" | wc -c | tr -d ' ')"
if [ "$chars" -le 1600 ]; then printf 'ok   context within budget (%s chars)\n' "$chars"
else printf 'FAIL context too large: %s chars, budget 1600\n' "$chars"; fail=1; fi

exit "$fail"
