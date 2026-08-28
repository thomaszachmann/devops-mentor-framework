# DevOps Mentor Framework

Two Claude Code skills that make the agent teach instead of solve: a **mentor**
that guides you to the answer through questions and escalating hints, and an
**exam** that tests you against a competency rubric and grades what it finds.

> **Build better engineers, not better prompts.**

## Why

The goal is not to lose the skills you built over the past years. AI is great,
but skills decay when you are no longer challenged to solve problems yourself.
The goal is not to write less code — it is to write better code.

## Install

Requires [`jq`](https://jqlang.github.io/jq/) on your `PATH`.

```
/plugin marketplace add thomaszachmann/devops-mentor-framework
/plugin install devops-mentor@devops-mentor-framework
```

Restart your session afterwards — hooks and skills load at session start.

## The two modes

<!-- TRANSCRIPT PENDING: both dialogues below must be replaced with real
     sessions before this repository is published or tagged. Do not write
     them from imagination; a framework about honest practice cannot ship an
     invented demo. -->

### Mentor

```
/mentor on kubernetes     # topic is optional
/mentor status
/mentor off
```

Mentor mode is tied to the **directory**, not the session. Closing the terminal
does not end it; `/mentor off` does. In another project you keep working
normally.

While it is on, Claude climbs a ladder instead of answering:

| Rung | What you get |
|---|---|
| 1 | A guiding question |
| 2 | A concrete hint |
| 3 | Pseudocode |
| 4 | A small code example, in chat |
| 5 | The full solution |

A rung is only climbed after **a genuine attempt**. "I don't know" does not
advance it — the question gets smaller instead. A wrong attempt does advance
it, and earns a diagnosis of the misconception behind the mistake rather than
a correction of the symptom.

Claude also stops writing to your files while mentor mode is on. Every write
becomes a confirmation you have to give deliberately.

_A real transcript goes here._

### Exam

```
/exam kubernetes
```

An oral examination against the competency matrix in `topics/`. Open questions
only, one follow-up probe on every answer that sounds recited, and **no
feedback at all until the end** — otherwise it turns into a tutorial and the
grade means nothing.

The result is a level per competency, where each level was lost, and one
concrete next step per gap. No overall score: an average across unrelated
competencies is a number without meaning.

_A real transcript goes here._

## What is stored, and where

Nothing about you goes into this repository. Two files live in
`~/.devops-mentor/`:

- `state.json` — which mode is active in which directory
- `profile.json` — your level per competency, misconceptions that surfaced,
  and the rung your mentor sessions reached

Nothing leaves your machine. The profile is what makes the mentor adapt: it is
injected next to your prompt, so the mentor knows to watch for the trap you
walked into last time, and the exam knows where to probe.

## Contributing a competency matrix

Topics live in `topics/`. You contribute **competencies, level descriptions
and misconceptions — never questions**, because a fixed question bank gets
memorised and goes stale. The exam generates fresh questions from your rubric
and grades against it.

Start from `topics/_template.md` and read
[docs/authoring-topics.md](docs/authoring-topics.md). See
[CONTRIBUTING.md](CONTRIBUTING.md) for the process.

## Documentation

- [Vision](docs/vision.md) — the mission
- [Principles](docs/principles.md) — the five rules everything follows from
- [Design spec](docs/specs/2026-08-28-mentor-framework-design.md) — how it
  works and which trade-offs were made

## License

MIT. See [LICENSE](LICENSE).
