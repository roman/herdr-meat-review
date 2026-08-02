---
name: herdr-review
description: Hand a change to the operator for review inside Herdr. Opens a tuicr TUI in a "review" tab of the current Herdr workspace, reports it to Herdr as a blocked agent so it surfaces in every Herdr client, and reads the operator's comments back when they are done. Use when you have finished a change and want a human to look at it, when the user asks for a review pane, or when you are told to wait for review. Requires HERDR_ENV=1.
---

# Herdr review

A review is a tuicr session running in its own Herdr tab, in the workspace
whose code is under review. Herdr does not know what tuicr is: the review
reports itself over the socket API as an agent of kind `tuicr`, so Herdr
rolls its state up to the tab and the workspace exactly as it does for a
coding agent. The operator sees a blocked review in whatever Herdr client
they use, and jumps to it from there.

This skill covers getting a review in front of the operator and reading
their verdict back. For everything else about tuicr — adding agent-authored
findings, PR sessions, choosing between review workflows — use the `tuicr`
skill.

## Before anything

Check you are inside a Herdr pane:

```bash
test "${HERDR_ENV:-}" = 1
```

If that fails, say you are not running inside Herdr and stop. Do not open a
review in a session that is not yours.

The entry point is the `herdr-review` script. Confirm it is reachable:

```bash
command -v herdr-review
```

If it is not on `PATH`, it ships in the `bin` directory of the herdr-tuicr
checkout; call it by its full path.

## Open a review

```bash
herdr-review open
```

That is the whole command. With no arguments it reviews the working tree of
the workspace you are running in, because Herdr injects
`HERDR_WORKSPACE_ID` into every pane it starts. It prints one JSON object:

```json
{"pane_id":"w1:p4","tab_id":"w1:t4","cwd":"/home/you/project","reused":false}
```

What it does, in order: creates a tab labelled `review` in the workspace,
reports that pane to Herdr as a blocked `tuicr` agent, and starts tuicr in
it with a one-line summary of what is waiting. The blocked state is
published before the TUI exists, so the review is visible and the
workspace's one review slot is taken from the moment the tab appears.

To review something other than the uncommitted working tree, pass tuicr's
own arguments after `--`:

```bash
herdr-review open -- --revisions HEAD~3..HEAD
herdr-review open -- --all-files
```

To review a different workspace than the one you are in, name it:

```bash
herdr-review open --workspace w2
```

**One review per workspace.** Opening a second review of a workspace that
already has one focuses the first and returns `"reused": true`. Do not work
around this by creating tabs yourself — the limit is deliberate, because
two open reviews of one checkout is more than an operator can hold at once.

Do not pass `--focus` unless the user asked to be taken to the review.
Stealing the operator's screen is what the blocked state exists to avoid.

## Wait for the operator

The review is `blocked` from the moment it opens until the operator quits
the tuicr TUI. Poll for that, rather than for the comments themselves:

```bash
herdr-review status
```

An empty object `{}` means no review is open — either it never opened or
the operator finished and the tab closed itself. A review that is still
open reports its `agent_status`, `pane_id`, and its summary token.

`{}` is the signal to move on. Do not wait for the review to turn `idle`:
it reports `blocked` and then releases its agent authority outright, so the
record disappears rather than transitioning, and `herdr agent wait --until
idle` would sit there until it times out.

Never send input to the review pane. It belongs to the operator, and typing
into a TUI they are reading is worse than useless.

## Read the comments back

Once the review is gone, find the session tuicr persisted and read it. This
is the point where the `tuicr` skill takes over; the short version:

```bash
tuicr review list --repo "$PWD"
tuicr review comments --session "<slug from the listing>"
```

The listing carries `comment_count`, so a count of zero means the operator
looked and had nothing to say — treat that as approval, not as a failure to
find the comments.

Address each comment in the code. Do not reply by adding comments of your
own to the session unless the user asked you to review rather than to be
reviewed; that distinction is the `tuicr` skill's core rule.

## End a review

The review ends itself: quitting the tuicr TUI releases the agent and
closes the tab, which frees the workspace to hold the next one. You end one
only when the operator abandoned it and asked you to clean up:

```bash
herdr-review close
```

Never close a review the operator is still in.

## What not to do

- Do not open a review for a change the user has not asked to have looked
  at. A blocked agent is a demand for attention.
- Do not open one per file or per commit. One review covers the change.
- Do not treat `herdr-review` as a way to get a terminal. Use `herdr pane
  split` or `herdr tab create` for that.
- Do not report `tuicr` agent state yourself with `herdr pane
  report-agent`. The script owns that pane's lifecycle, and a second
  reporter makes the panel lie.
