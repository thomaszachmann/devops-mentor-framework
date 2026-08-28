#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
MENTOR_HOME="$(mktemp -d)"; export MENTOR_HOME
trap 'rm -rf "$MENTOR_HOME"' EXIT
. "$root/lib/state.sh"
hook="$root/hooks/guard-writes.sh"
# Change to "deny" here and in hooks/guard-writes.sh if a live session shows
# that "ask" blocks outright instead of prompting.
want_decision="ask"

input_for() { # <cwd> <tool>
  printf '{"session_id":"s1","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"%s","tool_input":{"file_path":"/a/project/x.yaml"}}' "$1" "$2"
}
decision_of() { printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }

# 1. No mode: silent, exit 0, no opinion on the write.
out="$(printf '%s' "$(input_for /a/project Write)" | "$hook")"; rc=$?
[ "$rc" = 0 ] && [ -z "$out" ] && printf 'ok   silent when no mode is active\n' \
  || { printf 'FAIL expected silence, rc=%s out=[%s]\n' "$rc" "$out"; fail=1; }

mentor_set_mode /a/project mentor kubernetes

# 2. Write tools are intercepted.
for tool in Write Edit NotebookEdit; do
  out="$(printf '%s' "$(input_for /a/project "$tool")" | "$hook")"
  d="$(decision_of "$out")"
  [ "$d" = "$want_decision" ] && printf 'ok   %s is intercepted\n' "$tool" \
    || { printf 'FAIL %s decision was [%s], want [%s]\n' "$tool" "$d" "$want_decision"; fail=1; }
done

# 3. Read-only tools are never intercepted: the mentor must read code and run tests.
for tool in Read Grep Glob Bash; do
  out="$(printf '%s' "$(input_for /a/project "$tool")" | "$hook")"
  [ -z "$out" ] && printf 'ok   %s passes through\n' "$tool" \
    || { printf 'FAIL %s was intercepted: [%s]\n' "$tool" "$out"; fail=1; }
done

# 4. The reason must steer Claude back to the ladder, not just say no.
out="$(printf '%s' "$(input_for /a/project Write)" | "$hook")"
reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason' 2>/dev/null)"
case "$reason" in
  *rung*|*Rung*) printf 'ok   reason points at the ladder\n' ;;
  *) printf 'FAIL reason does not mention the ladder: [%s]\n' "$reason"; fail=1 ;;
esac

# 5. Exam mode does not guard writes.
mentor_set_mode /c/project exam kubernetes
out="$(printf '%s' "$(input_for /c/project Write)" | "$hook")"
[ -z "$out" ] && printf 'ok   exam mode does not guard writes\n' \
  || { printf 'FAIL exam mode intercepted a write\n'; fail=1; }

# 6. Malformed stdin must not crash.
printf 'nonsense' | "$hook" >/dev/null 2>&1; rc=$?
[ "$rc" = 0 ] && printf 'ok   exits 0 on malformed stdin\n' \
  || { printf 'FAIL exit code %s on malformed stdin\n' "$rc"; fail=1; }

exit "$fail"
