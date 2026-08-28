---
description: Turn mentor mode on or off for this directory
argument-hint: "on [topic] | off | status"
allowed-tools: Bash
---

Manage mentor mode for the current working directory.

The argument is: $ARGUMENTS

Run exactly one of the following, based on that argument, using the Bash tool.
Do not improvise a different command. Each one resolves the state library
first and reports clearly if it cannot be found, rather than failing with a
raw shell error.

**`on [topic]`** — start mentor mode:

```
bash -c 'lib="${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; [ -r "$lib" ] || { echo "devops-mentor: cannot read $lib"; exit 1; }; . "$lib"; mentor_set_mode "$PWD" mentor "TOPIC"; echo "Mentor mode on for $PWD"'
```

Replace `TOPIC` with the topic the learner named, or leave it empty if they
named none. Then tell the learner, in two sentences: mentor mode is on, you
will guide with questions and escalating hints rather than solutions, and
`/mentor off` ends it at any time. Then ask what they are working on.

**`off`** — end mentor mode:

First write a short "what you learned" summary of this session — the
concepts covered and any misconception that came up — then run:

```
bash -c 'lib="${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; [ -r "$lib" ] || { echo "devops-mentor: cannot read $lib"; exit 1; }; . "$lib"; mentor_clear_mode "$PWD"; echo "Mentor mode off for $PWD"'
```

Do not editorialise about the learner stopping. Ending the mode is a normal
action, not a failure.

**`status`** — report the current mode:

```
bash -c 'lib="${CLAUDE_PLUGIN_ROOT}/lib/state.sh"; [ -r "$lib" ] || { echo "devops-mentor: cannot read $lib"; exit 1; }; . "$lib"; m=$(mentor_mode_for "$PWD"); t=$(mentor_topic_for "$PWD"); echo "mode=${m:-none} topic=${t:-none} dir=$PWD"'
```

If the argument is empty or unrecognised, run `status` and then show the
three available forms.
