#!/usr/bin/env bash
# Shared state for the DevOps Mentor Framework.
#
# Every function here is written so that a missing, unreadable or corrupt
# state file reads as "no mode active". A hook must never break a session,
# so nothing in this file may exit non-zero on bad data.
#
# MENTOR_HOME is overridable so tests never touch the real profile.

MENTOR_HOME="${MENTOR_HOME:-$HOME/.devops-mentor}"
MENTOR_STATE_FILE="$MENTOR_HOME/state.json"
MENTOR_PROFILE_FILE="$MENTOR_HOME/profile.json"

mentor_have_jq() { command -v jq >/dev/null 2>&1; }

mentor_mode_for() { # <cwd>
  mentor_have_jq || return 0
  [ -r "$MENTOR_STATE_FILE" ] || return 0
  jq -r --arg k "$1" '.projects[$k].mode // empty' \
     "$MENTOR_STATE_FILE" 2>/dev/null || return 0
}

mentor_topic_for() { # <cwd>
  mentor_have_jq || return 0
  [ -r "$MENTOR_STATE_FILE" ] || return 0
  jq -r --arg k "$1" '.projects[$k].topic // empty' \
     "$MENTOR_STATE_FILE" 2>/dev/null || return 0
}

mentor_set_mode() { # <cwd> <mode> [topic]
  local tmp
  mentor_have_jq || return 0
  mkdir -p "$MENTOR_HOME" 2>/dev/null || return 0
  # A corrupt or absent file is replaced by an empty document rather than
  # failing: the user's mode command must always work.
  if ! jq empty "$MENTOR_STATE_FILE" >/dev/null 2>&1; then
    printf '{"version":1,"projects":{}}' > "$MENTOR_STATE_FILE" 2>/dev/null || return 0
  fi
  tmp="$MENTOR_STATE_FILE.tmp.$$"
  jq --arg k "$1" --arg m "$2" --arg t "${3:-}" \
     --arg s "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
     '.version = 1
      | .projects[$k] = {mode:$m, topic:$t, started:$s}' \
     "$MENTOR_STATE_FILE" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$MENTOR_STATE_FILE" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  return 0
}

mentor_clear_mode() { # <cwd>
  local tmp
  mentor_have_jq || return 0
  [ -r "$MENTOR_STATE_FILE" ] || return 0
  tmp="$MENTOR_STATE_FILE.tmp.$$"
  jq --arg k "$1" 'del(.projects[$k])' \
     "$MENTOR_STATE_FILE" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$MENTOR_STATE_FILE" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  return 0
}

# At most three lines, because this is injected on every single turn.
mentor_profile_summary() { # <topic>
  mentor_have_jq || return 0
  [ -r "$MENTOR_PROFILE_FILE" ] || return 0
  jq -r --arg t "$1" '
    (.topics[$t] // {}) | to_entries | .[:3] | map(
      "- " + .key + ": level " + (.value.level // 0 | tostring)
      + (if (.value.misconceptions // []) | length > 0
         then " (watch: " + (.value.misconceptions[0]) + ")" else "" end)
    ) | .[]' "$MENTOR_PROFILE_FILE" 2>/dev/null || return 0
}

# --- profile writers -------------------------------------------------------
# The exam writes results here and the mentor records early exits. Both go
# through this file so the shape stays in one place: mentor_profile_summary
# has to be able to read back whatever these write.

mentor__ensure_profile() {
  mkdir -p "$MENTOR_HOME" 2>/dev/null || return 1
  if ! jq empty "$MENTOR_PROFILE_FILE" >/dev/null 2>&1; then
    printf '{"version":1,"topics":{},"mentor_sessions":[]}' \
      > "$MENTOR_PROFILE_FILE" 2>/dev/null || return 1
  fi
  return 0
}

mentor_record_result() { # <topic> <competency> <level 0-3> [misconception]
  local tmp level
  mentor_have_jq || return 0
  # Validate explicitly rather than trusting the caller: an unparseable level
  # would make jq --argjson fail and silently drop the whole result.
  level="${3:-0}"
  case "$level" in 0|1|2|3) ;; *) level=0 ;; esac
  mentor__ensure_profile || return 0
  tmp="$MENTOR_PROFILE_FILE.tmp.$$"
  jq --arg t "$1" --arg c "$2" --argjson l "$level" --arg m "${4:-}" \
     --arg d "$(date -u +%Y-%m-%d)" '
     .version = 1
     | .topics[$t][$c].level = $l
     | .topics[$t][$c].last_assessed = $d
     | .topics[$t][$c].misconceptions =
         (((.topics[$t][$c].misconceptions // [])
           + (if $m == "" then [] else [$m] end)) | unique)
     ' "$MENTOR_PROFILE_FILE" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$MENTOR_PROFILE_FILE" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  return 0
}

mentor_record_exit() { # <topic> <rung 1-5>
  local tmp rung
  mentor_have_jq || return 0
  rung="${2:-0}"
  case "$rung" in 1|2|3|4|5) ;; *) rung=0 ;; esac
  mentor__ensure_profile || return 0
  tmp="$MENTOR_PROFILE_FILE.tmp.$$"
  # Keep only the last 20 so the file cannot grow without bound.
  jq --arg t "$1" --argjson r "$rung" --arg d "$(date -u +%Y-%m-%d)" '
     .version = 1
     | .mentor_sessions =
         (((.mentor_sessions // [])
           + [{date:$d, topic:$t, exited_at_rung:$r}]) | .[-20:])
     ' "$MENTOR_PROFILE_FILE" > "$tmp" 2>/dev/null \
    && mv "$tmp" "$MENTOR_PROFILE_FILE" 2>/dev/null
  rm -f "$tmp" 2>/dev/null
  return 0
}
