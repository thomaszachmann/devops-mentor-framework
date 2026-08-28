---
topic: template
maintainer: unassigned
---

# Topic template

Copy this file to `topics/<your-topic>.md` and replace the example.

**You are not writing questions.** The exam generates those, freshly, every
time — a fixed question bank gets memorised and goes stale. What you are
writing is the standard the answers are measured against, and the traps worth
probing for.

Each competency needs five blocks, and `tests/test_topics.sh` enforces that
all five are present:

- **Why this matters** — one sentence on what it is needed for in operations.
  If you cannot write this sentence, the competency probably is not one.
- **Level 1 to 3** — observable behaviour, not feelings. "Can derive why X
  fails" is checkable; "understands X" is not.
- **Common misconceptions** — the most valuable block. Take these from real
  incidents, support tickets and code review comments rather than inventing
  them. The exam uses them to decide where to probe, and the mentor uses them
  to diagnose a wrong attempt, so a good entry improves both at once.

See `docs/authoring-topics.md` for the longer version.

## Competency: RBAC

### Why this matters
Getting permissions wrong either blocks a deployment at the worst moment or
grants far more access than anyone intended.

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
- Assumes the binding inherits the namespace of the role rather than the other
  way round
