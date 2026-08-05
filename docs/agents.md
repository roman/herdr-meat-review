# Reviews from a coding agent

The point of this project is the loop where an agent writes a change, asks you
to look at it, and reads your comments back. `skills/herdr-meat-review` is what
teaches an agent to do that; this document is the human-readable version of
the same thing.

## Install the skill

Copy or symlink `skills/herdr-meat-review` into wherever your agent reads skills
from — for Claude Code that is `~/.claude/skills/`. The skill checks for
`HERDR_ENV=1` and refuses to touch a session it is not running inside, so
installing it does nothing until an agent is actually in a herdr pane.

## The loop

The agent finishes a change and asks for a review:

```bash
herdr-meat-review open
```

No arguments needed. herdr puts `HERDR_WORKSPACE_ID` into every pane it
starts, so the review lands in the workspace the agent is working in and shows
the working tree.

You see a blocked review appear, read it, and comment. The agent hands its
turn back and waits — and the review tells it when something happens, so you
never have to.

## The review carries the message

herdr also puts `HERDR_PANE_ID` into every pane, so `open` knows which agent
asked. The review pane watches its own tuicr session and wakes that agent
twice:

- **When comments arrive.** tuicr writes each comment to its session file the
  moment you press Enter, so the agent can read your review while you are
  still writing it. It reads and plans; it does not edit. You are looking at
  the files it would change, and a diff that moves while you read costs you
  the read.
- **When the review ends.** That is the go-ahead, and it carries the count of
  the whole session, including anything the agent was never woken for.
  Silence is reported too: a review closed with no comments is an approval,
  and the agent is told so rather than left to guess. So is a review that
  never opened, which is what an agent waiting on a tuicr that is not on
  `PATH` would otherwise wait for forever.

The closing message comes from the pane's own exit path rather than from the
watcher, so it goes out however the review ended — you quitting, `close`, or
the tab being taken away.

A burst of comments is one wake, not one per comment — the watcher waits for
you to stop typing. And an agent that is mid-turn is never interrupted; the
comments keep until it is listening.

Nothing polls. If you would rather drive it by hand, `herdr-meat-review status`
still answers, and `{}` still means the review is gone.

## A review nobody asked for wakes nobody

Opening a review from the Emacs panel, or from a plain shell, has no agent
behind it, so no watcher starts. Pass `--no-notify` to opt out from an agent's
pane as well.

`open` says which it did, in `notified`. An agent that reads `false` there
knows nothing will reach it and must ask you instead of waiting. A review
that was reused reports `false` too: the one already running belongs to
whoever opened it.

## One review per workspace

`open` on a workspace that already has a review focuses that review and
reports `"reused": true` instead of opening a second one. This is deliberate,
and an agent should not work around it by creating tabs itself: the limit is
what keeps your attention on one thing at a time, and what lets a client show
a row per workspace instead of a list.

Two callers racing for the same workspace also end up with one review. The
loser gives its tab back and reports the winner's pane.

## The rules an agent follows

They live in `skills/herdr-meat-review/SKILL.md`, not here. The skill is the
artifact that travels — someone copies that directory into their agent's
skills and takes nothing else — so it owns the operational detail: which
directory a review opens in, how to tell "the review never started" from "the
reviewer is done", how long to wait before handing the turn back, and what
never to do to a review pane.

Read it if you want to know what your agent has been told. Change it there if
you disagree; a second copy in this file would only drift from it.
