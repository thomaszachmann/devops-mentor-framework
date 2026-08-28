# Authoring a competency matrix

A topic file is the standard an exam grades against and the map a mentor uses
to diagnose. It is the only part of this framework that scales with the number
of people contributing, so it is worth writing carefully.

Copy `topics/_template.md` to `topics/<your-topic>.md` and work from there.

## You are not writing questions

This is the rule everything else follows from.

A fixed question bank has three problems: it gets memorised, it goes stale as
the technology moves, and maintaining it is endless. So the exam generates
questions freshly each time, from your level descriptions, and grades the
answers against those same descriptions.

What you write is the **standard** and the **traps**. What the exam writes is
the questions.

## The five blocks

### Why this matters

One sentence: what this competency is needed for in operations.

If you cannot write that sentence, the thing you picked is probably not a
competency. "YAML syntax" fails this test. "Knowing which of three mappings to
check first when traffic does not arrive" passes it, because you can say what
it saves.

Write about consequences, not importance. "Getting permissions wrong either
blocks a deployment at the worst moment or grants far more access than anyone
intended" is a reason. "RBAC is a fundamental Kubernetes concept" is filler.

### Level 1 to 3

Three levels, each describing **observable behaviour**.

The test: could two different examiners agree on whether someone met this
description? "Understands RBAC" fails — understanding is not observable.
"Can derive why a ClusterRoleBinding against a Role does not work" passes,
because either the derivation happens or it does not.

Useful shape for the three levels:

| Level | Verb | Example |
|---|---|---|
| 1 — basics | can name, can distinguish | "Can distinguish requests from limits and say which one the scheduler uses" |
| 2 — can apply | can design, can determine, can choose | "Given a Pending pod, can determine from `describe` whether the cause is capacity, a taint, or a node selector" |
| 3 — can explain | can derive, can explain why | "Can explain how requests and limits together determine the QoS class, and what that means under memory pressure" |

Level 3 is not "level 2 but harder". It is the level at which someone can
derive the behaviour instead of recalling it — the level at which they could
teach it.

Avoid tool trivia. "Knows the `-o jsonpath` syntax" measures whether someone
has looked it up recently, which is not a competency.

### Common misconceptions

The most valuable block, and the reason these files are worth maintaining
together.

It feeds two things at once. The exam uses it to decide where to probe — never
to write a question, because naming the trap in the question gives it away.
The mentor uses it to diagnose a wrong attempt: instead of correcting the
symptom, it names the misconception the learner is reasoning from.

**Take these from reality.** Real sources, in rough order of quality:

1. Incidents and postmortems — the misconception that caused an outage
2. Support tickets and the questions colleagues actually ask twice
3. Code review comments you find yourself writing repeatedly
4. Your own past mistakes, which you remember better than you think

An invented misconception describes how you imagine a beginner thinks. A
collected one describes how people actually get this wrong, and the difference
is immediately visible in how useful the diagnosis is.

**Write the mistaken belief, not the correction.** The entry is what the
learner thinks, phrased from inside their head:

- Good: "Reads ClusterRole as 'applies cluster-wide' instead of 'is not
  namespace-scoped'"
- Bad: "You need to understand that ClusterRole is not namespace-scoped"

The second is advice. The first is recognisable when it walks past.

**Be specific enough to spot.** "Confuses Services and Ingresses" is too broad
to act on. "Pictures a Service as a proxy process in front of the pods, rather
than as forwarding rules on every node" tells the mentor exactly which question
to ask next.

Two to four entries per competency is plenty. This is a list of the traps that
actually catch people, not an inventory of everything that could go wrong.

## Before you open a pull request

```bash
./tests/run.sh
```

`tests/test_topics.sh` checks that every competency in every topic file carries
all five blocks. It does not — and cannot — check whether your level
descriptions are observable or your misconceptions are real. That part is what
review is for, so in your pull request say **where the misconceptions came
from**. "Seen three times in review on our platform team" is the strongest
argument a matrix entry can have.
