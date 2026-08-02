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
tool:

```bash
tuicr review list --repo "$PWD"
tuicr review comments --session "<slug from the listing>"
```

A `comment_count` of zero means you looked and had nothing to say. That is
approval, not a failure to find the comments.

## One review per workspace

`open` on a workspace that already has a review focuses that review and
reports `"reused": true` instead of opening a second one. This is deliberate,
and an agent should not work around it by creating tabs itself: the limit is
what keeps the operator's attention on one thing at a time, and what lets a
client show a row per workspace instead of a list.

Two callers racing for the same workspace also end up with one review. The
loser gives its tab back and reports the winner's pane.

## Reviewing something other than the working tree

Everything after `--` goes to tuicr unchanged:

```bash
herdr-review open -- -r HEAD~3..HEAD
herdr-review open -- --all-files
herdr-review open --workspace w2 -- -r main..HEAD
```

## What an agent should not do

- Open a review for a change nobody asked to have looked at. A blocked agent
  is a demand for attention.
- Open one per file or per commit. One review covers the change.
- Send input to the review pane. It belongs to the operator, and typing into a
  TUI they are reading is worse than useless.
- Report `review` agent state itself with `herdr pane report-agent`.
  `herdr-review` owns that pane's lifecycle, and a second reporter makes the
  sidebar lie.
- Close a review the operator is still in.
