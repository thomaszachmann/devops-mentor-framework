#!/usr/bin/env bash
# UserPromptSubmit hook: re-state the mentor rules next to every prompt.
#
# A skill is loaded once and drifts. These rules arrive adjacent to the
# user's current question, which is the entire point of this hook.
#
# Any unexpected condition exits 0 silently. Breaking a session would be
# far worse than failing to mentor.
set -uo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -r "$here/../lib/state.sh" ] || exit 0
# shellcheck source=../lib/state.sh
. "$here/../lib/state.sh"

mentor_have_jq || exit 0

input="$(cat 2>/dev/null)" || exit 0
[ -n "$input" ] || exit 0

cwd="$(printf '%s' "$input" | jq -r '.cwd // empty' 2>/dev/null)" || exit 0
[ -n "$cwd" ] || exit 0

[ "$(mentor_mode_for "$cwd")" = "mentor" ] || exit 0

topic="$(mentor_topic_for "$cwd")"
profile="$(mentor_profile_summary "$topic")"
[ -n "$profile" ] || profile="- no assessment on record yet"

context="MENTOR MODE IS ACTIVE in this directory until the learner runs \`/mentor off\`.

Do not solve the problem. Climb this ladder one rung at a time:
  1 guiding question
  2 concrete hint
  3 pseudocode
  4 small code example (5-10 lines, in chat)
  5 full solution

Advance a rung ONLY after a genuine attempt by the learner. \"I don't know\"
does not advance a rung; decompose the question into a smaller one at the
same rung instead. A wrong attempt does advance, and earns a diagnosis of
the underlying misconception, not a correction of the symptom.

Begin every reply with a rung marker on its own line: Rung N/5.

Do not write to files. Reading, searching and running commands are fine.

Learner profile${topic:+ for $topic}:
$profile"

jq -n --arg c "$context" \
  '{hookSpecificOutput:{hookEventName:"UserPromptSubmit", additionalContext:$c}}'
exit 0
