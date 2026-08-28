#!/usr/bin/env bash
# Unit tests for lib/state.sh. Uses a temporary MENTOR_HOME so the
# developer's real profile is never touched.
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
check() {
  if [ "$2" = "$3" ]; then printf 'ok   %s\n' "$1"
  else printf 'FAIL %s: got [%s], want [%s]\n' "$1" "$2" "$3"; fail=1; fi
}

MENTOR_HOME="$(mktemp -d)"; export MENTOR_HOME
trap 'rm -rf "$MENTOR_HOME"' EXIT
. "$root/lib/state.sh"

# 1. No state file at all -> empty mode, no crash.
check "no state file yields empty mode" "$(mentor_mode_for /a/project)" ""

# 2. Set then read.
mentor_set_mode /a/project mentor kubernetes
check "mode round-trips"  "$(mentor_mode_for  /a/project)" "mentor"
check "topic round-trips" "$(mentor_topic_for /a/project)" "kubernetes"

# 3. A second project is unaffected.
check "other project unaffected" "$(mentor_mode_for /b/project)" ""

# 4. Clearing removes only the one entry.
mentor_set_mode /b/project mentor terraform
mentor_clear_mode /a/project
check "cleared project is empty" "$(mentor_mode_for /a/project)" ""
check "sibling survives clear"   "$(mentor_mode_for /b/project)" "mentor"

# 5. Corrupt state file must not crash and must read as "no mode".
printf 'this is not json' > "$MENTOR_STATE_FILE"
check "corrupt state yields empty mode" "$(mentor_mode_for /a/project)" ""

# 6. Corrupt state file must be recoverable by writing.
mentor_set_mode /a/project mentor kubernetes
check "write recovers from corruption" "$(mentor_mode_for /a/project)" "mentor"

# 7. Paths with spaces.
mentor_set_mode "/a/my project" mentor rbac
check "path with spaces" "$(mentor_mode_for "/a/my project")" "mentor"

# 8. Missing profile -> summary is empty, not an error.
check "missing profile yields empty summary" "$(mentor_profile_summary kubernetes)" ""

# 9. Profile summary reports levels and misconceptions.
cat > "$MENTOR_PROFILE_FILE" <<'JSON'
{"version":1,"topics":{"kubernetes":{"rbac":{"level":1,
 "misconceptions":["reads ClusterRole as cluster-wide grant"]}}}}
JSON
summary="$(mentor_profile_summary kubernetes)"
case "$summary" in
  *rbac*level\ 1*) printf 'ok   summary names competency and level\n' ;;
  *) printf 'FAIL summary missing competency/level: [%s]\n' "$summary"; fail=1 ;;
esac
case "$summary" in
  *ClusterRole*) printf 'ok   summary carries the misconception\n' ;;
  *) printf 'FAIL summary missing misconception: [%s]\n' "$summary"; fail=1 ;;
esac

# 10. Summary is capped so the per-turn injection stays small.
lines="$(printf '%s\n' "$summary" | wc -l | tr -d ' ')"
if [ "$lines" -le 3 ]; then printf 'ok   summary is at most 3 lines\n'
else printf 'FAIL summary too long: %s lines\n' "$lines"; fail=1; fi

exit "$fail"
