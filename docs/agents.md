# Reviews from a coding agent

The point of this project is the loop where an agent writes a change, asks you
to look at it, and reads your comments back. `skills/herdr-review` is what
teaches an agent to do that; this document is the human-readable version of
the same thing.

## Install the skill

Copy or symlink `skills/herdr-review` into wherever your agent reads skills
from — for Claude Code that is `~/.claude/skills/`. The skill checks for
`HERDR_ENV=1` and refuses to touch a session it is not running inside, so
installing it does nothing until an agent is actually in a herdr pane.

## The loop

The agent finishes a change and asks for a review:

```bash
herdr-review open
```

No arguments needed. herdr puts `HERDR_WORKSPACE_ID` into every pane it
starts, so the review lands in the workspace the agent is working in and shows
the working tree.

You see a blocked review appear, read it, comment, and quit. The agent notices
by polling:

```bash
herdr-review status     # {} means the review is gone
```

`{}` is the signal, not the comment count. Do not wait for the review to turn
`idle` — it reports `blocked` and then releases its agent authority outright,
so the record disappears rather than transitioning, and `herdr agent wait
--until idle` sits there until it times out.

Then the agent reads what you wrote, through tuicr rather than through this
tool, and works through it.

## One review per workspace

`open` on a workspace that already has a review focuses that review and
reports `"reused": true` instead of opening a second one. This is deliberate,
and an agent should not work around it by creating tabs itself: the limit is
what keeps your attention on one thing at a time, and what lets a client show
a row per workspace instead of a list.

Two callers racing for the same workspace also end up with one review. The
loser gives its tab back and reports the winner's pane.

## The rules an agent follows

They live in `skills/herdr-review/SKILL.md`, not here. The skill is the
artifact that travels — someone copies that directory into their agent's
skills and takes nothing else — so it owns the operational detail: which
directory a review opens in, how to tell "the review never started" from "the
reviewer is done", how long to wait before handing the turn back, and what
never to do to a review pane.

Read it if you want to know what your agent has been told. Change it there if
you disagree; a second copy in this file would only drift from it.
