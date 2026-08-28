# DevOps Mentor Framework Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the DevOps Mentor Framework as an installable Claude Code plugin providing two skills — `mentor` (guides via an escalating hint ladder) and `exam` (quizzes and grades against a competency rubric).

**Architecture:** A Claude Code plugin whose two hooks carry the enforcement. A `UserPromptSubmit` hook re-injects the mentor rules on every turn so the mode cannot drift; a `PreToolUse` hook intercepts file writes so no code is written silently. All shell logic lives in one sourced library (`lib/state.sh`) so the hooks stay thin and the library is the only thing that needs unit tests. Learner state lives outside the repo in `~/.devops-mentor/`.

**Tech Stack:** Bash (POSIX-ish, bash 3.2 compatible for stock macOS), `jq` for JSON, plain-bash test runner (no test framework dependency), Markdown content.

**Spec:** `docs/specs/2026-08-28-mentor-framework-design.md`

## Global Constraints

- **A hook must never break a session.** Every hook exits 0 on any unexpected condition — missing state file, corrupt JSON, missing `jq`, unreadable library. Exit 2 is never used by this project.
- **`MENTOR_HOME` overrides `~/.devops-mentor`.** Every script reads its state root from `${MENTOR_HOME:-$HOME/.devops-mentor}`. This is what makes the scripts testable without touching the developer's real profile. No script may hardcode `$HOME/.devops-mentor`.
- **No learner data in the repo, ever.** State and profile live under `MENTOR_HOME` only.
- **Injected context stays under 400 tokens.** Measured in Task 5, not assumed.
- **bash 3.2 compatible.** No `declare -A`, no `${var^^}`, no `mapfile`. Stock macOS ships bash 3.2. Development machines typically run a newer bash from Homebrew, so `tests/run.sh` re-runs the whole suite under `/bin/bash` to make this constraint verified rather than asserted.
- **Plugin name:** `devops-mentor`. **Marketplace name:** `devops-mentor-framework`. Install is therefore `/plugin install devops-mentor@devops-mentor-framework`.
- **License:** MIT, `Copyright (c) 2026 Thomas Zachmann`.
- **Docs language:** English (matches existing `docs/vision.md`, `docs/principles.md`).

## Verified reference facts

Confirmed against the official docs on 2026-08-28. Do not re-derive these from memory.

- Plugin manifest: `.claude-plugin/plugin.json`. Hook config: `hooks/hooks.json`, top-level key `hooks`, then event name → array of `{matcher, hooks:[{type:"command", command:"..."}]}`.
- `${CLAUDE_PLUGIN_ROOT}` resolves to the plugin directory; wrap it in escaped quotes inside JSON: `"\"${CLAUDE_PLUGIN_ROOT}\"/hooks/inject-mode.sh"`.
- Marketplace manifest: `.claude-plugin/marketplace.json` at repo root, required fields `name`, `owner.name`, `plugins[]` with `name` + `source`.
- Install commands: `/plugin marketplace add owner/repo` then `/plugin install name@marketplace-name`.
- Hook stdin (both events): `session_id`, `transcript_path`, `cwd`, `permission_mode`, `hook_event_name`. `PreToolUse` adds `tool_name`, `tool_input`, `tool_use_id`.
- `UserPromptSubmit` output: `hookSpecificOutput.hookEventName` = `"UserPromptSubmit"` plus `additionalContext`.
- `PreToolUse` output: `hookSpecificOutput.hookEventName` = `"PreToolUse"` plus `permissionDecision` and `permissionDecisionReason`.
- Matcher: a value containing only letters, digits, `_`, `-`, spaces, `,` and `|` is treated as exact strings separated by `|` or `,`. So `"Edit|Write|NotebookEdit"` is an exact-match list, not a regex.

**UNRESOLVED — this is what Task 1 settles:** whether `permissionDecision` accepts `"ask"`. Sources disagree (`allow|deny|ask` vs. `allow|deny|block` vs. `allow|deny` only).

---

### Task 1: Settle the `ask` question empirically

The design's write guard depends on `permissionDecision: "ask"` producing a user confirmation rather than an outright block. The documentation is inconsistent. This task is a throwaway probe run in a scratch directory — nothing here is committed.

**Files:**
- Create (throwaway): `/tmp/mentor-probe/.claude/settings.json`
- Create (throwaway): `/tmp/mentor-probe/probe.sh`

- [ ] **Step 1: Build the probe**

```bash
mkdir -p /tmp/mentor-probe/.claude
cat > /tmp/mentor-probe/probe.sh <<'EOF'
#!/usr/bin/env bash
cat > /tmp/mentor-probe/last-input.json
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"PROBE: does ask prompt or block?"}}
JSON
exit 0
EOF
chmod +x /tmp/mentor-probe/probe.sh
cat > /tmp/mentor-probe/.claude/settings.json <<'EOF'
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Write",
        "hooks": [ { "type": "command", "command": "/tmp/mentor-probe/probe.sh" } ] }
    ]
  }
}
EOF
```

- [ ] **Step 2: Run the probe**

Start Claude Code in `/tmp/mentor-probe` and ask it to write a file `hello.txt`.

- [ ] **Step 3: Record the outcome**

Three possible results, each with a defined consequence:

| Observed | Meaning | Consequence for Task 6 |
|---|---|---|
| A confirmation prompt appears, approving it writes the file | `"ask"` works as designed | Build the guard as specified. No design change. |
| The write is refused outright, no prompt | `"ask"` behaves like deny | Fall back: emit `"deny"` with a reason that tells Claude to offer the next rung. Tell the user the soft variant is unavailable and that the guard is now a hard block. |
| Nothing happens, the write proceeds | The value is ignored | Fall back to `"deny"` and note that the soft variant does not exist. |

Also confirm from `/tmp/mentor-probe/last-input.json` that `cwd` is present and holds the project directory. Task 4 depends on that field.

- [ ] **Step 4: Write the finding into the spec**

Append the observed behaviour to the "Open risks and assumptions" section of `docs/specs/2026-08-28-mentor-framework-design.md`, replacing risk 1 with what was actually observed.

- [ ] **Step 5: Clean up and commit the spec update**

```bash
rm -rf /tmp/mentor-probe
git add docs/specs/2026-08-28-mentor-framework-design.md
git commit -m "docs: record verified PreToolUse permissionDecision behaviour"
```

---

### Task 2: Repository housekeeping

Independent of everything else; do it first so later commits are not mixed with renames.

**Files:**
- Create: `LICENSE`, `.gitignore`
- Rename: `Contributing.md` → `CONTRIBUTING.md`
- Delete: `skills-mentor.md`
- Modify: `docs/principles.md`, `README.md`

- [ ] **Step 1: Add the MIT license**

```bash
cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2026 Thomas Zachmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF
```

- [ ] **Step 2: Add .gitignore as the second net against leaking learner data**

```bash
cat > .gitignore <<'EOF'
# Learner state must never enter the repository.
.devops-mentor/
*profile.json
*state.json

# Local editor / OS noise
.DS_Store
EOF
```

- [ ] **Step 3: Rename the contributing file so GitHub links it**

```bash
git mv Contributing.md CONTRIBUTING.md
```

- [ ] **Step 4: Remove the empty stub replaced by `skills/mentor/SKILL.md`**

```bash
git rm skills-mentor.md
```

- [ ] **Step 5: Fix the typos**

```bash
sed -i '' 's/Incurage the independant thinking/Encourage independent thinking/' docs/principles.md
sed -i '' 's/Mentor Framwork/Mentor Framework/' README.md
grep -n 'Encourage independent thinking' docs/principles.md
grep -n 'Mentor Framework' README.md
```

Expected: both greps print a matching line. (`sed -i ''` is the BSD/macOS form. On GNU/Linux use `sed -i` without the empty argument.)

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "chore: add MIT license, gitignore, fix filenames and typos"
```

---

### Task 3: Plugin and marketplace manifests

**Files:**
- Create: `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`
- Create: `tests/test_manifests.sh`

**Interfaces:**
- Produces: plugin name `devops-mentor`, marketplace name `devops-mentor-framework`. Every later task's hook paths are relative to the plugin root, which is this directory.

- [ ] **Step 1: Write the failing test**

```bash
mkdir -p tests
cat > tests/test_manifests.sh <<'EOF'
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
  "$(jq -r '.name' "$root/.claude-plugin/plugin.json")" "devops-mentor"
check "plugin license" \
  "$(jq -r '.license' "$root/.claude-plugin/plugin.json")" "MIT"
check "marketplace name" \
  "$(jq -r '.name' "$root/.claude-plugin/marketplace.json")" "devops-mentor-framework"
check "marketplace lists the plugin" \
  "$(jq -r '.plugins[0].name' "$root/.claude-plugin/marketplace.json")" "devops-mentor"
check "marketplace owner is set" \
  "$(jq -r '.owner.name != null' "$root/.claude-plugin/marketplace.json")" "true"

exit "$fail"
EOF
chmod +x tests/test_manifests.sh
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/test_manifests.sh`
Expected: FAIL — the manifest files do not exist yet, `jq empty` reports errors.

- [ ] **Step 3: Write the manifests**

```bash
mkdir -p .claude-plugin
cat > .claude-plugin/plugin.json <<'EOF'
{
  "name": "devops-mentor",
  "displayName": "DevOps Mentor Framework",
  "version": "0.1.0",
  "description": "Turns Claude Code into a mentor and examiner instead of an author. Build better engineers, not better prompts.",
  "author": { "name": "Thomas Zachmann" },
  "repository": "https://github.com/thomaszachmann/devops-mentor-framework",
  "license": "MIT",
  "keywords": ["mentoring", "learning", "devops", "training", "assessment"]
}
EOF
cat > .claude-plugin/marketplace.json <<'EOF'
{
  "name": "devops-mentor-framework",
  "owner": { "name": "Thomas Zachmann",
             "url": "https://github.com/thomaszachmann" },
  "description": "Skills that make Claude Code teach instead of solve.",
  "plugins": [
    {
      "name": "devops-mentor",
      "source": "./",
      "description": "Mentor and Exam skills for deliberate technical practice."
    }
  ]
}
EOF
```

Note: `plugin.json` deliberately omits `skills`, `commands` and `hooks` path fields. All three live at their default locations (`skills/`, `commands/`, `hooks/hooks.json`) and are discovered automatically. Adding redundant paths is a second place to get wrong.

- [ ] **Step 4: Run the test to verify it passes**

Run: `./tests/test_manifests.sh`
Expected: all lines start with `ok`, exit code 0.

- [ ] **Step 5: Verify the plugin installs locally**

```
/plugin marketplace add ./
/plugin install devops-mentor@devops-mentor-framework
```

Expected: install succeeds. It will report zero skills and zero hooks — correct at this stage, they arrive in later tasks.

- [ ] **Step 6: Commit**

```bash
git add .claude-plugin tests/test_manifests.sh
git commit -m "feat: add plugin and marketplace manifests"
```

---

### Task 4: State library

The single place that touches disk. Both hooks and both commands source it.

**Files:**
- Create: `lib/state.sh`
- Create: `tests/test_state.sh`

**Interfaces:**
- Produces, all sourced from `lib/state.sh`:
  - `mentor_have_jq` → exit 0 if `jq` is on PATH, else 1
  - `mentor_mode_for <cwd>` → prints `mentor`, `exam` or nothing
  - `mentor_topic_for <cwd>` → prints the topic string or nothing
  - `mentor_set_mode <cwd> <mode> [topic]` → writes state, prints nothing
  - `mentor_clear_mode <cwd>` → removes the entry for `<cwd>`
  - `mentor_profile_summary <topic>` → prints at most 3 lines of learner context
  - `MENTOR_HOME`, `MENTOR_STATE_FILE`, `MENTOR_PROFILE_FILE` variables

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/test_state.sh <<'EOF'
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
EOF
chmod +x tests/test_state.sh
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/test_state.sh`
Expected: FAIL — `lib/state.sh` does not exist, sourcing it errors.

- [ ] **Step 3: Write the library**

```bash
mkdir -p lib
cat > lib/state.sh <<'EOF'
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

mentor_mode_for() {
  mentor_have_jq || return 0
  [ -r "$MENTOR_STATE_FILE" ] || return 0
  jq -r --arg k "$1" '.projects[$k].mode // empty' \
     "$MENTOR_STATE_FILE" 2>/dev/null || return 0
}

mentor_topic_for() {
  mentor_have_jq || return 0
  [ -r "$MENTOR_STATE_FILE" ] || return 0
  jq -r --arg k "$1" '.projects[$k].topic // empty' \
     "$MENTOR_STATE_FILE" 2>/dev/null || return 0
}

mentor_set_mode() { # <cwd> <mode> [topic]
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
EOF
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./tests/test_state.sh`
Expected: every line starts with `ok`, exit code 0. If test 5 or 6 fails, the corrupt-file handling is wrong — that is the one behaviour that protects real sessions, so fix it rather than relaxing the test.

- [ ] **Step 5: Commit**

```bash
git add lib/state.sh tests/test_state.sh
git commit -m "feat: add state library with corruption-safe reads"
```

---

### Task 5: The UserPromptSubmit hook

**Files:**
- Create: `hooks/inject-mode.sh`
- Create: `tests/test_inject.sh`

**Interfaces:**
- Consumes: `lib/state.sh` (`mentor_mode_for`, `mentor_topic_for`, `mentor_profile_summary`, `mentor_have_jq`)
- Produces: a script that reads hook JSON on stdin and prints either nothing or one JSON object with `hookSpecificOutput.additionalContext`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/test_inject.sh <<'EOF'
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
ev="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.hookEventName')"
[ "$ev" = "UserPromptSubmit" ] && printf 'ok   correct hookEventName\n' \
  || { printf 'FAIL hookEventName was [%s]\n' "$ev"; fail=1; }

ctx="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext')"

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
EOF
chmod +x tests/test_inject.sh
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/test_inject.sh`
Expected: FAIL — `hooks/inject-mode.sh` does not exist.

- [ ] **Step 3: Write the hook**

```bash
mkdir -p hooks
cat > hooks/inject-mode.sh <<'EOF'
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
EOF
chmod +x hooks/inject-mode.sh
```

Building the output with `jq -n --arg` rather than a printf template is deliberate: the context contains quotes, backticks and newlines, and hand-quoted JSON would break on the first apostrophe in "don't".

- [ ] **Step 4: Run the test to verify it passes**

Run: `./tests/test_inject.sh`
Expected: all `ok`, exit 0. The final line reports the character count — record it; it is the measured answer to the spec's token-budget risk.

- [ ] **Step 5: Commit**

```bash
git add hooks/inject-mode.sh tests/test_inject.sh
git commit -m "feat: inject mentor rules on every prompt"
```

---

### Task 6: The PreToolUse write guard

**Files:**
- Create: `hooks/guard-writes.sh`
- Create: `tests/test_guard.sh`

**Interfaces:**
- Consumes: `lib/state.sh`, and the decision value confirmed in Task 1
- Produces: a script emitting `hookSpecificOutput.permissionDecision`

**Before starting:** use the value Task 1 verified. If Task 1 found `"ask"` works, use `ask` everywhere below. If it found `ask` is unsupported, replace every `ask` with `deny` in both the test and the script, and say so in the commit message.

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/test_guard.sh <<'EOF'
#!/usr/bin/env bash
set -uo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
MENTOR_HOME="$(mktemp -d)"; export MENTOR_HOME
trap 'rm -rf "$MENTOR_HOME"' EXIT
. "$root/lib/state.sh"
hook="$root/hooks/guard-writes.sh"
# Change to "deny" here if Task 1 showed "ask" is unsupported.
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
reason="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.permissionDecisionReason')"
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
EOF
chmod +x tests/test_guard.sh
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/test_guard.sh`
Expected: FAIL — the hook does not exist.

- [ ] **Step 3: Write the hook**

```bash
cat > hooks/guard-writes.sh <<'EOF'
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
EOF
chmod +x hooks/guard-writes.sh
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `./tests/test_guard.sh`
Expected: all `ok`, exit 0.

- [ ] **Step 5: Commit**

```bash
git add hooks/guard-writes.sh tests/test_guard.sh
git commit -m "feat: guard file writes while mentor mode is active"
```

---

### Task 7: Register the hooks and run everything end to end

**Split during execution (2026-08-28).** The learner asked to try mentor mode
before the probe in Task 1 had been run, so this task was done in two halves:

- **7a, done:** `hooks/hooks.json` with the `UserPromptSubmit` entry only, plus
  `tests/run.sh`. Nothing here depends on the probe.
- **7b, pending:** add the `PreToolUse` entry once Task 6 exists. The end-to-end
  walkthrough in Step 5 below belongs to 7b.


**Files:**
- Create: `hooks/hooks.json`
- Create: `tests/run.sh`

- [ ] **Step 1: Write the hook registration**

```bash
cat > hooks/hooks.json <<'EOF'
{
  "hooks": {
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/inject-mode.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Edit|Write|NotebookEdit",
        "hooks": [
          {
            "type": "command",
            "command": "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/guard-writes.sh"
          }
        ]
      }
    ]
  }
}
EOF
```

The matcher contains only letters and `|`, so Claude Code treats it as an exact-match list rather than a regex — which is what we want, so that a future tool named `WriteFile` is not caught by accident. The guard re-checks the tool name anyway; the matcher is an optimisation, not the guarantee.

- [ ] **Step 2: Write the aggregate test runner**

```bash
cat > tests/run.sh <<'EOF'
#!/usr/bin/env bash
# Runs every test in this directory. No test framework dependency.
set -uo pipefail
cd "$(dirname "$0")"
command -v jq >/dev/null 2>&1 || { echo "jq is required to run the tests"; exit 1; }
fail=0
for t in test_*.sh; do
  printf '\n== %s ==\n' "$t"
  ./"$t" || fail=1
done

# The global constraint says bash 3.2. Development machines usually run a
# much newer bash from Homebrew, so a green suite here proves nothing about
# a stock macOS. /bin/bash on macOS is 3.2 - run everything again under it.
if [ -x /bin/bash ] && /bin/bash --version | head -1 | grep -q 'version 3'; then
  printf '\n== re-running under /bin/bash (3.2) ==\n'
  for t in test_*.sh; do
    /bin/bash ./"$t" >/dev/null 2>&1 \
      && printf 'ok   %s under bash 3.2\n' "$t" \
      || { printf 'FAIL %s under bash 3.2\n' "$t"; fail=1; }
  done
else
  printf '\nnote: no bash 3.2 available, 3.2 compatibility unverified\n'
fi

printf '\n'
[ "$fail" = 0 ] && echo "ALL TESTS PASSED" || echo "SOME TESTS FAILED"
exit "$fail"
EOF
chmod +x tests/run.sh
```

- [ ] **Step 3: Run the whole suite**

Run: `./tests/run.sh`
Expected: `ALL TESTS PASSED`, exit 0.

- [ ] **Step 4: Validate the hook JSON**

Run: `jq empty hooks/hooks.json && echo valid`
Expected: `valid`

- [ ] **Step 5: End-to-end check in a scratch directory**

```bash
mkdir -p /tmp/mentor-e2e && cd /tmp/mentor-e2e && git init -q
```

Reinstall the plugin, then in that directory:
1. Manually seed the mode: `MENTOR_HOME=~/.devops-mentor bash -c '. <repo>/lib/state.sh; mentor_set_mode /tmp/mentor-e2e mentor kubernetes'` (the `/mentor` command arrives in Task 8; this proves the hooks work before it exists).
2. Ask Claude Code anything. Expect a reply beginning with `Rung 1/5` and asking a question rather than answering.
3. Ask it to write a file. Expect the confirmation prompt (or the refusal, per Task 1's finding).
4. Clear the mode and confirm normal behaviour returns.

- [ ] **Step 6: Commit**

```bash
git add hooks/hooks.json tests/run.sh
git commit -m "feat: register both hooks with the plugin"
```

---

### Task 8: The /mentor command

**Files:**
- Create: `commands/mentor.md`

**Interfaces:**
- Consumes: `lib/state.sh` via `${CLAUDE_PLUGIN_ROOT}`
- Produces: `/mentor on [topic]`, `/mentor off`, `/mentor status`

Note: the plugin docs describe `commands/` as deprecated in favour of `skills/`. It remains the documented path for slash commands and works today. If it is removed in a future release, the migration is to move this file to `skills/mentor-mode/SKILL.md`; nothing else changes.

- [ ] **Step 1: Write the command**

```bash
mkdir -p commands
cat > commands/mentor.md <<'EOF'
---
description: Turn mentor mode on or off for this directory
argument-hint: "on [topic] | off | status"
allowed-tools: Bash
---

Manage mentor mode for the current working directory.

The argument is: $ARGUMENTS

Run exactly one of the following, based on that argument, using the Bash tool.
Do not improvise a different command.

**`on [topic]`** — start mentor mode:

```
bash -c '. "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; mentor_set_mode "$PWD" mentor "TOPIC"; echo "Mentor mode on for $PWD"'
```

Replace `TOPIC` with the topic the learner named, or leave it empty if they
named none. Then tell the learner, in two sentences: mentor mode is on, you
will guide with questions and escalating hints rather than solutions, and
`/mentor off` ends it at any time. Then ask what they are working on.

**`off`** — end mentor mode:

First write a short "what you learned" summary of this session — the
concepts covered and any misconception that came up — then run:

```
bash -c '. "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; mentor_clear_mode "$PWD"; echo "Mentor mode off for $PWD"'
```

Do not editorialise about the learner stopping. Ending the mode is a normal
action, not a failure.

**`status`** — report the current mode:

```
bash -c '. "${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; m=$(mentor_mode_for "$PWD"); t=$(mentor_topic_for "$PWD"); echo "mode=${m:-none} topic=${t:-none} dir=$PWD"'
```

If the argument is empty or unrecognised, run `status` and show the three
available forms.
EOF
```

- [ ] **Step 2: Verify the command is discovered**

Reinstall the plugin and run `/mentor status` in a scratch directory.
Expected: it reports `mode=none`.

- [ ] **Step 3: Verify the round trip**

Run `/mentor on kubernetes`, then `/mentor status`.
Expected: `mode=mentor topic=kubernetes`. Ask a question; the reply should begin with `Rung 1/5`. Then `/mentor off` and `/mentor status`.
Expected: a learning summary, then `mode=none`.

- [ ] **Step 4: Commit**

```bash
git add commands/mentor.md
git commit -m "feat: add /mentor on|off|status command"
```

---

### Task 9: The mentor skill

The hook carries the rules; this file carries the craft. It is loaded once, so it can be long.

**Files:**
- Create: `skills/mentor/SKILL.md`

- [ ] **Step 1: Write the skill frontmatter and body**

Frontmatter, verbatim:

```markdown
---
name: mentor
description: Use when the learner is working through a technical problem and wants to be guided to the answer rather than given it - teaches through guiding questions and escalating hints instead of solutions. Activated by /mentor on.
---
```

The body must contain these sections, in this order:

1. **The ladder** — the five rungs as a table, identical wording to the spec.
2. **What advances a rung** — only a genuine attempt. State explicitly that "I don't know" does not advance and that the response to it is decomposition, with two worked examples of decomposing a too-large question.
3. **How to ask a guiding question** — the difference between a question that hands over the answer ("Have you set `readinessProbe`?") and one that creates the search ("What has to be true before traffic reaches this pod?"). Give at least four contrasting pairs.
4. **How to diagnose a wrong attempt** — name the underlying misconception, not the symptom. Include the spec's port/targetPort example plus two more.
5. **When to consult the competency matrix** — if `topics/<topic>.md` exists, read its "Common misconceptions" block before diagnosing.
6. **Ending a session** — what belongs in the learning summary and what gets written to the profile.
7. **What not to do** — no praise inflation, no writing files, no answering a question the learner has not attempted, no rung skipping to relieve frustration.

- [ ] **Step 2: Check the skill is discovered**

Reinstall the plugin. Run `/plugin` and confirm `devops-mentor` lists a `mentor` skill.

- [ ] **Step 3: Sanity-check the content**

Run: `grep -c '^## ' skills/mentor/SKILL.md`
Expected: at least 7.

- [ ] **Step 4: Commit**

```bash
git add skills/mentor/SKILL.md
git commit -m "feat: add the mentor skill"
```

---

### Task 10: Competency matrix format and the Kubernetes matrix

**Files:**
- Create: `topics/_template.md`, `topics/kubernetes.md`
- Create: `tests/test_topics.sh`

- [ ] **Step 1: Write the failing test**

```bash
cat > tests/test_topics.sh <<'EOF'
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
EOF
chmod +x tests/test_topics.sh
```

- [ ] **Step 2: Run it to verify it fails**

Run: `./tests/test_topics.sh`
Expected: `FAIL no topic files found`.

- [ ] **Step 3: Write the template**

`topics/_template.md` contains exactly one competency using the spec's RBAC example, with a header explaining that contributors write competencies and misconceptions, never questions.

Because the test counts `topics/*.md`, the template must itself be valid — it is both documentation and the fixture that proves the validator works.

- [ ] **Step 4: Write the Kubernetes matrix**

`topics/kubernetes.md` with at least four competencies: `RBAC`, `Networking and Services`, `Scheduling and Resources`, `Probes and Rollouts`. Each carries all five blocks. The RBAC competency uses the spec's wording verbatim so spec and content cannot drift.

- [ ] **Step 5: Run the test to verify it passes**

Run: `./tests/test_topics.sh`
Expected: all `ok`, exit 0.

- [ ] **Step 6: Commit**

```bash
git add topics tests/test_topics.sh
git commit -m "feat: add competency matrix format and Kubernetes matrix"
```

---

### Task 11: The exam skill and /exam command

**Files:**
- Create: `skills/exam/SKILL.md`, `commands/exam.md`

**Interfaces:**
- Consumes: `topics/<topic>.md` from Task 10, `lib/state.sh` from Task 4
- Produces: profile writes under `topics.<topic>.<competency>` matching the schema in Task 4's test fixture — `level` (integer 0-3) and `misconceptions` (array of strings). Any deviation breaks `mentor_profile_summary`.

- [ ] **Step 1: Write the exam skill**

Frontmatter, verbatim:

```markdown
---
name: exam
description: Use when the learner wants to be tested on a technical topic - runs a structured oral examination against a competency rubric, probes shallow answers, then grades. Activated by /exam <topic>.
---
```

Required body sections:

1. **The five phases** — selection, questioning, probing, grading, result. Spec wording.
2. **No feedback during the exam** — stated as the skill's first rule, with the reason: feedback turns the exam into tutoring and makes the grade meaningless. Include the concrete prohibition list: no "correct", no "close", no hints, no visible reaction to a wrong answer.
3. **Selecting competencies** — read `topics/<topic>.md`, read the profile, weight toward competencies with a low recorded level and toward those where `mentor_sessions` shows an early exit.
4. **Writing questions from a rubric** — questions come from the level descriptions, never from the misconceptions block. Misconceptions are for probing, not for asking.
5. **Probing** — every superficially correct answer gets one follow-up: a "why", an edge case, or a consequence. Include three worked examples.
6. **Grading** — level 0 to 3 per competency, mapped directly onto the matrix's level blocks. A competency is only awarded a level if the probe was also answered.
7. **Writing the result** — the exact profile JSON shape, and the command to write it.
8. **The result report** — level per competency, named gaps, and one concrete next step per gap.

- [ ] **Step 2: Write the command**

`commands/exam.md` with `argument-hint: "<topic> [competency]"`, `allowed-tools: Bash, Read`. It sets exam mode via `mentor_set_mode "$PWD" exam "TOPIC"`, runs the exam skill, and clears the mode with `mentor_clear_mode "$PWD"` when the exam finishes. Setting exam mode matters: `tests/test_inject.sh` and `tests/test_guard.sh` both assert that exam mode suppresses the mentor rules and the write guard, so an exam must not run with mentor mode still set.

- [ ] **Step 3: Run a real exam end to end**

Run `/exam kubernetes` in a scratch directory. Answer three questions, one of them deliberately shallow but correct.
Expected: a probe follows the shallow answer; no feedback appears until the end; the final report gives a level per competency.

- [ ] **Step 4: Verify the profile was written in the shape the library expects**

```bash
jq '.topics.kubernetes' ~/.devops-mentor/profile.json
MENTOR_HOME=~/.devops-mentor bash -c '. ./lib/state.sh; mentor_profile_summary kubernetes'
```

Expected: the summary prints one line per competency with a level. If it prints nothing, the exam wrote a shape the library cannot read — fix the exam skill, not the library.

- [ ] **Step 5: Commit**

```bash
git add skills/exam commands/exam.md
git commit -m "feat: add the exam skill and /exam command"
```

---

### Task 12: README, contributing guide and authoring guide

**Files:**
- Modify: `README.md`, `CONTRIBUTING.md`
- Create: `docs/authoring-topics.md`

- [ ] **Step 1: Rewrite the README**

Seven sections in this order:

1. Title, one sentence on what it is, and the mission line "Build better engineers, not better prompts."
2. **Why** — three sentences on skill decay, moved from `CONTRIBUTING.md`, whose current text is the project's rationale rather than a contribution guide.
3. **Install**, verbatim:
   ```
   /plugin marketplace add thomaszachmann/devops-mentor-framework
   /plugin install devops-mentor@devops-mentor-framework
   ```
   Plus a one-line prerequisite: `jq` must be on PATH.
4. **The two modes, each with a real transcript.** Not a description — an actual dialogue, six to ten turns, copied from a genuine session recorded during Tasks 8 and 11. This is the section that makes a stranger understand the project, and it is the reason those two tasks ask you to run real sessions.
5. **What is stored and where** — `~/.devops-mentor/state.json` and `profile.json`, never in the repo, never leaves the machine.
6. **Contributing a competency matrix** — two sentences and a link to `docs/authoring-topics.md`.
7. **License** — MIT.

- [ ] **Step 2: Rewrite CONTRIBUTING.md**

Keep the existing motivation text as a blockquote at the top, attributed as the project's origin. Add: how to propose a competency matrix, the four-block requirement, that `./tests/run.sh` must pass, and that contributors write competencies and misconceptions rather than questions.

- [ ] **Step 3: Write docs/authoring-topics.md**

The full four-block format with the RBAC example, guidance on writing level descriptions that are observable rather than vague ("can derive why X fails" not "understands X"), and how to source a misconception from real support tickets or code review comments rather than inventing one.

- [ ] **Step 4: Verify every documented command actually works**

Walk the README from a clean machine state: run the two install commands, then `/mentor on`, `/mentor status`, `/mentor off`, `/exam kubernetes`. Any command that does not behave as documented is a README bug, not a user error.

- [ ] **Step 5: Run the full suite one last time**

Run: `./tests/run.sh`
Expected: `ALL TESTS PASSED`.

- [ ] **Step 6: Commit and tag**

```bash
git add README.md CONTRIBUTING.md docs/authoring-topics.md
git commit -m "docs: document install, both modes and matrix authoring"
git tag -a v0.1.0 -m "First installable release"
```

---

## Verification summary

| What | How | When |
|---|---|---|
| Manifests are valid and correctly named | `tests/test_manifests.sh` | Task 3 |
| State survives corruption, absence, spaces | `tests/test_state.sh` | Task 4 |
| Injection is correct, scoped and within budget | `tests/test_inject.sh` | Task 5 |
| Write guard catches writes, spares reads | `tests/test_guard.sh` | Task 6 |
| Topic files carry all four blocks | `tests/test_topics.sh` | Task 10 |
| Everything at once | `tests/run.sh` | Task 7 onward |
| Real install, real mentor session, real exam | Manual walkthrough | Tasks 7, 8, 11, 12 |

## Deferred, deliberately

Debugging Coach, Architecture Review, Kubernetes Trainer and Incident Response Training are all additive: a new file under `topics/` or a new directory under `skills/`. None requires touching the hooks or the state library. Grading reproducibility (spec risk 3) is best measured once the Kubernetes matrix has been used a few times; it is not a v0.1.0 blocker.
