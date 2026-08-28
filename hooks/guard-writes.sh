#!/usr/bin/env bash
# PreToolUse hook: in mentor mode, a file write becomes a visible decision.
#
# This is the one part of the framework that is a mechanism rather than an
# instruction. Everything else relies on the model choosing to comply.
#
# Read, search and command execution stay unrestricted: the mentor has to
# be able to read the learner's code and run their tests.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -r "$here/../lib/state.sh" ] || exit 0
# shellcheck source=../lib/state.sh
. "$here/../lib/state.sh"

mentor_have_jq || exit 0

input="$(cat 2>/dev/null)" || exit 0
[ -n "$input" ] || exit 0

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)" || exit 0
tool="$(printf '%s' "$input" | jq -r '.tool_name // empty' 2>/dev/null)" || exit 0
[ -n "$cwd" ] || exit 0

[ "$(mentor_mode_for "$cwd")" = "mentor" ] || exit 0

case "$tool" in
  Write|Edit|NotebookEdit) ;;
  *) exit 0 ;;
esac

reason="Mentor mode is active. Writing this file would hand over the answer.
Offer the next rung of the ladder instead, or let the learner approve this
write deliberately. The learner can end mentor mode with /mentor off."

jq -n --arg r "$reason" \
  '{hookSpecificOutput:{hookEventName:"PreToolUse",
                        permissionDecision:"ask",
                        permissionDecisionReason:$r}}'
exit 0
