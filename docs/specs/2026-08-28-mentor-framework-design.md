# Design: DevOps Mentor Framework — Mentor & Exam Skills

Date: 2026-08-28
Status: Approved design, not yet implemented

## Mission

Build better engineers, not better prompts.

Coding agents remove work. Removed work is removed practice, and removed
practice is skill decay. This framework deliberately puts the agent in the
role of mentor and examiner instead of author.

## Scope

Version 1 delivers two skills, `mentor` and `exam`, packaged as an
installable Claude Code plugin, plus one competency matrix (Kubernetes) to
prove the content format works.

Explicitly out of scope for v1: Debugging Coach, Architecture Review,
Kubernetes Trainer and Incident Response Training. They are expected to
follow, and the structure below is designed so that each is a new directory
under `topics/` or `skills/`, not a restructuring.

Also deliberately excluded from v1: subagents, MCP servers, and a
configuration file for hint levels. All three can be added later without
changing the structure.

## Decisions

| Question | Decision | Why |
|---|---|---|
| Distribution | Claude Code plugin; repo is its own marketplace | Two-line install, updates via git |
| Mode persistence | Mode file + `UserPromptSubmit` hook | A once-loaded skill drifts over long sessions and is lost after context compaction |
| Learner memory | `~/.devops-mentor/profile.json`, outside the repo | Makes "Adapt to the learner" a mechanism; keeps private data out of a public repo |
| Exam content | Competency matrix + rubric in repo, questions generated | Fresh questions, reproducible grading, contributable content |
| Writes in mentor mode | `PreToolUse` hook returns `ask` | Nothing is written silently; the user stays in mentor mode after approving |
| License | MIT | Fewest questions for a prompt/documentation framework |

## Repository layout

```
devops-mentor-framework/
├── .claude-plugin/
│   ├── plugin.json          # name, version, description
│   └── marketplace.json     # repo is its own marketplace
├── skills/
│   ├── mentor/SKILL.md
│   └── exam/SKILL.md
├── commands/
│   ├── mentor.md            # /mentor on | off | status
│   └── exam.md              # /exam <topic> [level]
├── hooks/
│   ├── hooks.json
│   ├── inject-mode.sh       # UserPromptSubmit
│   └── guard-writes.sh      # PreToolUse
├── topics/
│   ├── _template.md
│   └── kubernetes.md
├── docs/
│   ├── vision.md
│   ├── principles.md
│   ├── authoring-topics.md
│   └── specs/
├── .gitignore
├── LICENSE                  # MIT
├── CONTRIBUTING.md
└── README.md
```

## State

State lives in `~/.devops-mentor/`, never in the repo. `.gitignore` is a
second net.

`state.json` — which mode is active in which working directory:

```json
{
  "version": 1,
  "projects": {
    "/home/x/work/cluster": { "mode": "mentor", "topic": "kubernetes",
                              "started": "2026-08-28T10:00:00Z" }
  }
}
```

Keyed by working directory, not globally and not by session. Global is wrong
because a second terminal would silently inherit the mode. Per-session is
technically cleaner but unworkable: the slash command does not know its
session id while the hook does, so the two could not agree on a key. Both
know the working directory. The semantics also fit: "in this project I am
learning, in that one I am working."

`profile.json` — the learner across all projects:

```json
{
  "version": 1,
  "topics": {
    "kubernetes": {
      "rbac": { "level": 1, "last_assessed": "2026-08-28",
                "misconceptions": ["reads ClusterRole as cluster-wide grant"] }
    }
  },
  "mentor_sessions": [
    { "date": "2026-08-28", "topic": "kubernetes/rbac", "exited_at_rung": 2 }
  ]
}
```

## Data flow per turn (mentor mode active)

```
user prompt
  └─> UserPromptSubmit hook
        └─> inject-mode.sh reads state.json, key = cwd
              ├─ no entry -> exit 0, nothing happens, plain Claude Code
              └─ mentor   -> emits rules + 2 lines of profile as context
                    └─> the rules sit next to this prompt, not 40 turns above it
```

That adjacency is the point of the whole mechanism.

## Mentor skill

### The ladder

| Rung | What is given |
|---|---|
| 1 | Guiding question |
| 2 | Concrete hint |
| 3 | Pseudocode |
| 4 | Small code example (5–10 lines, in chat) |
| 5 | Full solution — only on explicit request |

Rungs 1 to 4 never require a file write; they happen in chat. Rung 5 is the
only rung that does, which is why it coincides with the write guard's
confirmation prompt: reaching rung 5 is a decision the learner makes
visibly. Approving that prompt does not end mentor mode — the session
continues at rung 1 for the next question.

### Rules

**Only a genuine attempt advances a rung.** Not time, not repeated asking,
not frustration. "I don't know" does not advance; it triggers the same rung
in a smaller portion — the question is decomposed, not answered. Without
this rule the framework collapses into a slower way of asking for the
answer.

**A wrong attempt advances the rung and earns a diagnosis, not a
correction.** Name the underlying misconception, not the symptom. "You
swapped port and targetPort" is worthless. "You are reasoning from service
to pod — reverse the direction" lands.

**The current rung is stated in every mentor reply** (`Rung 2/5`). It costs
nothing, makes escalation auditable, and is self-correcting: a jump from 1
to 4 is visible. The rung is deliberately not persisted — it would mean a
file write per turn for a value already present in the conversation.

**Writes ask, they do not fail.** The `PreToolUse` hook returns `ask` for
`Edit`, `Write` and `NotebookEdit` while the mode is active. Read, search
and command execution stay unrestricted — the mentor must be able to read
the code and run the tests. A hard block was considered and rejected: its
only escape, `/mentor off`, ends the mode entirely, which is a bad
translation of "I want this one file written." A guardrail that irritates
gets uninstalled, and an uninstalled guardrail protects nobody.

**Exit is honest, not shameful.** `/mentor off` works immediately, without
challenge or sermon. It records "topic X, exited at rung 2" — not a ledger
of failure but the signal principle 5 needs: that topic returns, and the
exam knows where to probe.

**Session end** is triggered by `/mentor off`. It produces a short "what you
just learned" summary and writes the covered topics to the profile. Closing
the terminal without `/mentor off` leaves the mode active for that working
directory; `/mentor status` reports it, which is intended — the mode is a
state you leave on purpose.

### Split between hook and skill

The hook injects the minimum per turn: mode active, the five rungs, the
advancement rule, two lines of profile. Target under 400 tokens. All the
craft — how to ask a good guiding question, how to decompose one that is
too large, how to diagnose a misconception — lives in `SKILL.md`, loaded
once.

## Exam skill

`/exam kubernetes` runs five phases:

1. **Selection** — reads `topics/kubernetes.md` and the profile, weighted
   toward competencies that were weak last time or where the learner exited
   mentor mode.
2. **Questioning** — open questions generated from the matrix. No multiple
   choice: guessing at 25% measures nothing.
3. **Probing** — every superficially correct answer gets a "why" or an edge
   case. This is where memorised knowledge separates from understanding,
   and precisely what a static question bank cannot do.
4. **Grading** — against the matrix rubric, not against intuition.
5. **Result** — level per competency, named gaps, concrete study
   recommendation, written to the profile.

**No feedback during the exam.** No "correct", no "close", no hints.
Otherwise the exam degrades into a tutoring session and the grade is
meaningless. "I don't know" is a valid answer, is recorded, and moves on.

The mentor helps, the exam measures. That separation is the entire reason
these are two skills rather than one.

## Competency matrix format

Four blocks per competency:

```markdown
## Competency: RBAC

### Why this matters
One sentence — what it is actually needed for in operations.

### Level 1 — basics
Can name and distinguish Role vs ClusterRole, RoleBinding vs
ClusterRoleBinding.

### Level 2 — can apply
Can design a minimal role for a concrete use case and justify why it is
minimal.

### Level 3 — can explain
Can derive why a ClusterRoleBinding against a Role does not work.

### Common misconceptions
- Reads ClusterRole as "applies cluster-wide" instead of "is not
  namespace-scoped"
```

**Common misconceptions** is the most valuable block and the reason the
matrices are worth maintaining together: the exam learns where to probe,
and the mentor learns which diagnosis to give when the learner walks into
that exact trap. Both skills share one file, which keeps teaching and
testing on the same standard.

Contributors never write questions — they write competencies, levels and
misconceptions. Less maintenance, slower decay.

## README structure

1. One sentence on what it is, plus the mission.
2. **Why** — three sentences on skill decay. This text already exists in
   `Contributing.md`; it is the project's rationale and belongs here, not in
   a contribution guide.
3. Install:
   ```
   /plugin marketplace add thomaszachmann/devops-mentor-framework
   /plugin install devops-mentor@devops-mentor-framework
   ```
4. **The two modes, each with a real example dialogue.** The most important
   section. A stranger understands "guides you to the solution through
   questions" in ten seconds of transcript and never from a paragraph.
5. What is stored and where (`~/.devops-mentor/`, never leaves the machine).
6. Contributing a competency matrix → `docs/authoring-topics.md`.
7. License.

## Housekeeping included in this work

- `Contributing.md` → `CONTRIBUTING.md` (GitHub only auto-links the
  uppercase form). Keeps the existing motivation text as a quote, gains an
  actual contribution process.
- `skills-mentor.md` (empty stub in root) → removed, replaced by
  `skills/mentor/SKILL.md`.
- `docs/principles.md`: fix "Incurage" → "Encourage", "independant" →
  "independent".
- `README.md`: fix "Framwork" → "Framework".
- Add `LICENSE` (MIT) — without it, strictly speaking nobody may use the
  framework, which contradicts its stated goal.
- Add `.gitignore`.

## Open risks and assumptions

1. **Plugin mechanics are unverified.** The exact schema of `hooks/hooks.json`
   inside a plugin, the use of `${CLAUDE_PLUGIN_ROOT}`, whether `PreToolUse`
   supports an `ask` decision, and the precise `/plugin marketplace add`
   syntax must all be checked against current documentation before any of it
   is written. None of this is to be written from memory.
2. **Per-turn token cost.** The injected block must stay small; 400 tokens is
   the target, and it should be measured rather than assumed.
3. **Grading consistency is unproven.** Whether the same answer graded twice
   against the same rubric yields the same level is an empirical question.
   Worth testing on the Kubernetes matrix before adding more topics.
4. **The write guard is a speed bump, not a sandbox.** It matches on tool
   names, so `Edit`, `Write` and `NotebookEdit` are covered, but a file
   written through `Bash` (`cat > file`, `tee`, `sed -i`) is not. Blocking
   `Bash` is not an option: the mentor has to be able to run the learner's
   tests. Pattern-matching shell commands for redirection would be fragile
   and would fire constantly on legitimate commands. This is accepted: the
   guard exists to stop the unconscious slide into "just write it for me",
   not to defeat a learner who has decided to route around it. Someone
   determined to get the answer can already type `/mentor off`.

5. **The rung marker depends on compliance.** Unlike the write guard, nothing
   enforces that the stated rung matches the answer given. It is visible to
   the user, which is the mitigation.

## Testing

There is no application to unit-test here; the testable surface is the
shell scripts and the content.

- `inject-mode.sh` and `guard-writes.sh`: fixture-driven shell tests over
  their JSON stdin — no state file, mode off, mode on, malformed state.
  A missing or corrupt state file must exit 0 silently and never break a
  session.
- Plugin manifests: validate JSON.
- Content: a check that every `topics/*.md` carries all four blocks per
  competency.
- End to end, manual: install the plugin in a scratch directory, run a
  mentor session and an exam, confirm the profile is written.
