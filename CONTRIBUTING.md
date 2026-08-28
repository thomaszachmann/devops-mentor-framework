# Contributing

Thank you for supporting this project.

Why it exists, in the author's words:

> The goal is not to lose the skills you learned in the past years. AI is
> great, but I also learned that my skills decrease when I am not challenged
> to solve problems. The goal is to create a framework for working with coding
> agents. I tried to write most of it myself, and only used AI to give me
> hints and structure. The goal is not to write less code, but to write better
> code.

That applies to contributions too. A pull request written entirely by an agent
is not what this project is for.

## The most useful contribution: a competency matrix

Topics in `topics/` are the part that scales. Everything else is machinery.

**You write competencies, level descriptions and misconceptions — never
questions.** A fixed question bank gets memorised and goes stale; the exam
generates fresh questions from your rubric and grades against it.

Each competency needs five blocks, and `tests/test_topics.sh` will fail if any
is missing:

- `### Why this matters`
- `### Level 1 — basics`
- `### Level 2 — can apply`
- `### Level 3 — can explain`
- `### Common misconceptions`

Start from `topics/_template.md` and read
[docs/authoring-topics.md](docs/authoring-topics.md).

## Working on the code

```bash
./tests/run.sh
```

Everything must pass, including the re-run under bash 3.2. There is no test
framework — the suite is plain bash, and a new test is a new
`tests/test_*.sh`.

To try your changes locally, add the repository as a marketplace from its
**parent** directory. A bare `.` is rejected; the path has to start with `./`:

```bash
cd ..
claude plugin marketplace add ./devops-mentor-framework
claude plugin install devops-mentor@devops-mentor-framework
```

Restart your session to load hooks and skills.

## Two rules the machinery must keep

**A hook may never break a session.** Every hook exits 0 on anything
unexpected — missing state file, corrupt JSON, no `jq`. Failing to mentor is
an inconvenience; failing someone's session is not.

**Nothing learner-specific enters the repository.** State and profile live in
`~/.devops-mentor/`. If you add something that writes, write it there.

## Changing the skills

`skills/mentor/SKILL.md` and `skills/exam/SKILL.md` are the didactics, and
they are the substance of this project. Changes there are welcome, but argue
for them: say which situation the current wording handles badly and what
should happen instead. "Made it clearer" is not reviewable.

Note that the mentor's per-turn rules live in `hooks/inject-mode.sh`, not in
the skill. They are injected on every prompt and are budgeted at 400 tokens,
currently using about 190. Keep additions there short, and put anything
explanatory in the skill, which is loaded only once.
