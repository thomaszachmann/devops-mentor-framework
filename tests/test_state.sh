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

# 11. Round trip: what the exam writes, the mentor must be able to read.
# This is the contract between the two skills - if it breaks, the mentor
# silently stops adapting and nobody notices.
rm -f "$MENTOR_PROFILE_FILE"
mentor_record_result kubernetes rbac 2 "confuses ClusterRole scope with binding scope"
summary="$(mentor_profile_summary kubernetes)"
case "$summary" in
  *"rbac: level 2"*) printf 'ok   recorded result is readable by the summary\n' ;;
  *) printf 'FAIL round trip broken: [%s]\n' "$summary"; fail=1 ;;
esac
case "$summary" in
  *"ClusterRole scope"*) printf 'ok   recorded misconception survives the round trip\n' ;;
  *) printf 'FAIL misconception lost: [%s]\n' "$summary"; fail=1 ;;
esac

# 12. An out-of-range level must not corrupt the file; it falls back to 0.
mentor_record_result kubernetes probes "not-a-number"
check "invalid level falls back to 0" \
  "$(jq -r '.topics.kubernetes.probes.level' "$MENTOR_PROFILE_FILE")" "0"
jq empty "$MENTOR_PROFILE_FILE" 2>/dev/null \
  && printf 'ok   profile still valid JSON after bad input\n' \
  || { printf 'FAIL profile corrupted by bad input\n'; fail=1; }

# 13. Misconceptions accumulate and de-duplicate.
mentor_record_result kubernetes rbac 2 "second distinct misconception"
mentor_record_result kubernetes rbac 3 "second distinct misconception"
check "misconceptions de-duplicate" \
  "$(jq -r '.topics.kubernetes.rbac.misconceptions | length' "$MENTOR_PROFILE_FILE")" "2"
check "level is overwritten, not appended" \
  "$(jq -r '.topics.kubernetes.rbac.level' "$MENTOR_PROFILE_FILE")" "3"

# 14. Early exits are recorded and capped.
i=1
while [ "$i" -le 25 ]; do mentor_record_exit kubernetes 2; i=$((i + 1)); done
check "mentor_sessions capped at 20" \
  "$(jq -r '.mentor_sessions | length' "$MENTOR_PROFILE_FILE")" "20"
check "exit rung is recorded" \
  "$(jq -r '.mentor_sessions[-1].exited_at_rung' "$MENTOR_PROFILE_FILE")" "2"

# 15. A corrupt profile is recovered by a write rather than propagated.
printf 'garbage' > "$MENTOR_PROFILE_FILE"
mentor_record_result terraform state 1 "treats state as a cache"
check "write recovers a corrupt profile" \
  "$(jq -r '.topics.terraform.state.level' "$MENTOR_PROFILE_FILE")" "1"

exit "$fail"
