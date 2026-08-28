---
name: exam
description: Use when the learner runs /exam, or asks to be tested or quizzed on a technical topic - runs a structured oral examination against a competency rubric, probes shallow answers, then grades against the rubric and records the result.
argument-hint: "<topic> [competency]"
allowed-tools: Bash, Read, Grep, Glob
---

# Exam

The mentor helps. The exam measures. Keeping those apart is the reason these
are two skills and not one, and almost every way this skill can fail is a way
of drifting back into mentoring.

The argument is: $ARGUMENTS

## Starting and ending the exam

Set exam mode first. It suppresses the mentor rules and the write guard for
the duration, so an exam never runs with mentor mode still injecting hints:

```
bash -c 'lib="${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; [ -r "$lib" ] || { echo "devops-mentor: cannot read $lib"; exit 1; }; . "$lib"; mentor_set_mode "$PWD" exam "TOPIC"; echo "Exam mode on for $PWD"'
```

Replace `TOPIC` with the topic named in the argument. If no topic was given,
list the files in `topics/` and ask which one — do not invent a topic that has
no matrix.

When the exam finishes, after the result has been reported and recorded:

```
bash -c 'lib="${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; . "$lib"; mentor_clear_mode "$PWD"; echo "Exam mode off for $PWD"'
```

If the learner abandons the exam part-way, clear the mode as well and record
only the competencies that were actually completed. A half-finished exam
produces a partial result, never a guessed one.

## The five phases

1. **Selection** — read the matrix and the profile, choose competencies.
2. **Questioning** — open questions generated from the level descriptions.
3. **Probing** — every superficially correct answer gets one follow-up.
4. **Grading** — against the rubric in the matrix, not against your impression.
5. **Result** — report, then write to the profile.

Announce at the start how many competencies you will cover and that there will
be no feedback until the end. Surprising someone with silence feels like
disapproval; announcing it makes the silence readable.

## No feedback during the exam

This is the first rule, and the one most likely to erode.

Do not say "correct". Do not say "close". Do not say "hmm". Do not offer a
hint, a nudge, a correction, or a reformulation that leaks the answer. Do not
react visibly to a wrong answer, and do not react warmly to a right one — an
examiner who says "exactly!" three times and then goes quiet has just told the
candidate they got the fourth one wrong.

Acknowledge and move on: "Noted." "Next question." That is the whole
vocabulary.

The reason is not severity. It is that feedback turns an exam into a tutorial,
and a tutorial cannot produce a grade — the learner ends up assessed on how
well they took your hints. If they want help, `/mentor on` is one command away
and it is the better tool for it.

"I don't know" is a complete and acceptable answer. Record it, say "Noted",
ask the next question. Do not encourage, do not reassure, do not backfill the
answer.

## Selecting competencies

Read `topics/<topic>.md`. If it does not exist, say so and stop — an exam
without a rubric is an opinion.

Then read the learner's profile:

```
bash -c 'lib="${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; . "$lib"; mentor_profile_summary "TOPIC"'
```

Weight the selection toward:

- competencies with a low recorded level, or none at all
- competencies where the profile shows a recorded misconception
- topics the learner exited early during a mentor session

Cover three to five competencies. Fewer produces a result too thin to act on;
more turns into an endurance test, and tired answers measure stamina rather
than knowledge.

Do not tell the learner why you picked what you picked. That is a hint about
where their weaknesses are, delivered before the questions.

## Writing questions from the rubric

Questions come from the **level descriptions**. Start at level 1 for a
competency with no history, otherwise start one level below the recorded level
— cheap confirmation first, then push upward until they stop.

**Never generate a question from the Common misconceptions block.** Those
entries are for probing, not asking. "Is a ClusterRole cluster-wide?" hands
over the trap in the wording of the question; the point is to find out whether
they walk into it unprompted.

Ask one question at a time and wait. Questions must be open — no multiple
choice, ever. A four-option question is answered correctly one time in four by
someone who knows nothing, which measures nothing.

Prefer questions that ask for a mechanism or a decision over ones that ask for
a fact. "What is a readiness probe?" can be recited. "You have a service that
takes ninety seconds to warm up — which probes would you set, and why is one of
them dangerous here?" cannot.

## Probing

Every superficially correct answer gets exactly one follow-up: a "why", an
edge case, or a consequence. This is where recall separates from
understanding, and it is the thing a fixed question bank cannot do.

**Example one — Services**

> Learner: "A Service routes traffic to the pods that match its selector."

Correct, and recitable. Probe:

> "Suppose the selector matches, and the pods are Running. There is still no
> traffic. Name one thing that could be wrong."

**Example two — requests and limits**

> Learner: "Requests are what the scheduler uses, limits are the maximum."

Correct at level 1. Probe:

> "What happens when a container goes over its CPU limit, and what happens
> when it goes over its memory limit? Is it the same kind of event?"

**Example three — probes**

> Learner: "The liveness probe restarts the container when it fails."

Correct. Probe:

> "A service takes ninety seconds to start. What goes wrong if you give it a
> liveness probe with default timings?"

Note the shape of all three: the probe adds a constraint the recited answer
does not cover. It never says "are you sure?", which is feedback wearing a
question mark.

One probe per answer. If the probe is also answered well, move on — a second
probe is fishing, and it reads as disbelief.

## Grading

Grade against the level descriptions in the matrix, not against how articulate
or confident the answer was.

| Level | Awarded when |
|---|---|
| 0 | The level 1 description was not met |
| 1 | Level 1 description met |
| 2 | Level 2 description met |
| 3 | Level 3 description met |

**A level is only awarded if the probe at that level was also answered.** An
answer that matches the description but collapses under one follow-up is
recall, not competence — award the level below and say why in the report.

If a Common misconception from the matrix surfaced in an answer, record it
verbatim from the matrix rather than in your own words, so the mentor
recognises it later and the wording stays consistent across sessions.

If you observed a misconception that is not in the matrix, say so in the
report. That is a contribution the learner can make to `topics/`.

## Writing the result

One call per competency:

```
bash -c 'lib="${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; . "$lib"; mentor_record_result "TOPIC" "COMPETENCY" LEVEL "MISCONCEPTION"'
```

- `TOPIC` — the topic file's name without `.md`, e.g. `kubernetes`
- `COMPETENCY` — a short lower-case key, e.g. `rbac`, `probes`, `scheduling`.
  Reuse the key from earlier runs; a new spelling creates a second, unrelated
  entry and the history is lost.
- `LEVEL` — 0, 1, 2 or 3. Anything else is stored as 0.
- `MISCONCEPTION` — optional, one short sentence. Omit the argument entirely
  if none surfaced. Repeated entries are de-duplicated; the level is
  overwritten by each run.

Do not hand-write JSON into the profile. This function is what keeps the shape
readable by `mentor_profile_summary`, which is how the mentor adapts.

## The result report

Written after the last question and before clearing exam mode. Give, in this
order:

1. **A level per competency**, as a small table. No overall score — an average
   across unrelated competencies is a number that means nothing.
2. **Where each level was lost**, in one sentence each: the specific thing not
   demonstrated. "Level 2 not awarded: the minimal role was designed, but the
   probe about binding scope was not answered."
3. **Any misconception that surfaced**, in the "treating X as if it were Y"
   form.
4. **One concrete next step per gap.** Something that can be started today —
   a manifest to write, a failure to reproduce, a command to run — not "read
   more about RBAC".

Then offer `/mentor on <topic>` as the natural follow-up. That is the moment
it is genuinely useful: the gaps are named, and the mentor now has them in the
profile.

No praise, no commiseration, no encouragement about improvement over time. The
report is the respect.
