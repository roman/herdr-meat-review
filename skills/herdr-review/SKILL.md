---
name: herdr-review
description: Get a human to review your change inside a herdr session and read their comments back, each review showing only what arrived since the last one. Use this whenever you are working in a herdr pane and the user wants a change looked at before it lands — "review this", "take a look before I merge", "put this in front of me", "wait for my review" — and again afterwards when they ask what they said, whether they left comments, or to address the review. This is for a human reviewer; when they want another agent to review instead, the herdr skill's agent start is the one. Inside herdr prefer this over the tuicr skill: do not start tuicr in tmux or zellij when herdr owns the session. Checks HERDR_ENV and stops if you are not in a herdr pane.
---

# herdr review

A review is a tuicr session in its own herdr tab, reported to herdr as a
blocked agent of kind `review`. herdr does not know what tuicr is; it rolls
that blocked state up to the tab and the workspace as it does for any coding
agent, so the review reaches whatever herdr client the user is looking at.

This skill covers the whole loop: opening a review and reading the verdict
back.

## When this is the wrong skill

**A human is going to read the diff.** That is the whole of what this skill
does. If the user wants *another agent* to read it instead — "get codex to
review this", "have a second model look at it" — that is the `herdr` skill's
job, and the command is `herdr agent start reviewer --kind <kind>` followed by
`herdr agent prompt`. Ask which they meant when "review this" could be either;
the difference is who spends the next ten minutes.

**Two other boundaries**, so a rule from a neighbouring skill does not stop
you:

- The `tuicr` skill starts tuicr under tmux or zellij. Inside herdr, do not:
  herdr would never see that review. Load that skill only for what this one
  does not cover — agent-authored findings and PR sessions.
- The `herdr` skill says not to create a tab unless the user asked for that
  topology. Opening a review is the sanctioned exception, and `herdr-review`
  makes and removes that tab itself. Do not create one yourself to put a
  review in.

## Before anything

Check you are inside a herdr pane:

```bash
test "${HERDR_ENV:-}" = 1
```

If that fails, say you are not running inside herdr and stop. Do not open a
review in a session that is not yours.

The entry point is the `herdr-review` script. Confirm it is reachable:

```bash
command -v herdr-review
```

If it is not on `PATH`, it ships in the `bin` directory of the herdr-review
checkout; call it by its full path.

## Open a review

```bash
herdr-review open --cwd "$PWD"
```

**Always pass `--cwd "$PWD"`.** Without it the review opens in the
*workspace's* directory — the working directory of its first pane — which is
not necessarily the directory you are working in. In a git worktree, a
subproject, or anywhere below the workspace root, the operator would read the
wrong diff and neither of you would be told. Passing it is always safe, so
prefer it over checking.

It prints one JSON object. Keep the `cwd` it reports: that is the repository
the review session belongs to, and you need it again to read the comments.

```json
{"pane_id":"w1:p4","tab_id":"w1:t4","cwd":"/home/you/project","reused":false}
```

What it does, in order: creates a tab labelled `review` in the workspace,
reports that pane to herdr as a blocked `review` agent, and starts tuicr in
it with a one-line summary of what is waiting. The blocked state is published
before the TUI exists, so the review is visible and the workspace's one
review slot is taken from the moment the tab appears.

### Each review picks up where the last one left off

With no tuicr arguments, `open` shows what has arrived since the previous
review — not the whole branch again. Every review leaves a marker at the
commit it opened on, under `refs/reviews/<n>`, and the next one starts
there. `herdr-review marks` lists them.

Uncommitted work is shown every time, because nothing can record that it was
seen. **So commit before asking for a review.** Work you leave uncommitted
is read once now and again in the next review, and the reviewer will not
know which parts they have already been through.

That leaves one rule, and it is the whole reason this works:

> **Address review comments in new commits. Never `commit --amend`,
> `rebase`, or `reset` at or below the newest marker.**

Rewriting a commit the marker sits on or below moves it out from under the
marker, and the next review replays everything the reviewer already read.
If the user wants the branch tidied, do that after the last review, not
between two.

To review something other than that, pass tuicr's own arguments after `--`.
They win, and the marker still moves:

```bash
herdr-review open --cwd "$PWD" -- --revisions HEAD~3..HEAD
herdr-review open --cwd "$PWD" -- --all-files
```

To review a different workspace than the one you are in, name it:

```bash
herdr-review open --workspace w2 --cwd /path/to/that/checkout
```

**One review per workspace.** Opening a second review of a workspace that
already has one focuses the first and returns `"reused": true`. Do not work
around this by creating tabs yourself — the limit is deliberate, because two
open reviews of one checkout is more than a person can hold at once. The
reuse reply carries no `cwd`, so keep the one from the reply that opened it.

Do not pass `--focus` unless the user asked to be taken to the review.
Taking over their screen is what the blocked state exists to avoid.

## Wait

The review is `blocked` from the moment it opens until the user quits the
tuicr TUI. Poll for that, rather than for the comments themselves:

```bash
herdr-review status
```

A review that is still open reports `agent_status`, `pane_id`, and its
summary at `.tokens.summary`. An empty object `{}` means no review is open.

**`{}` on your first poll means the review never started** — it does not mean
the user finished. tuicr missing from the pane's `PATH` ends a review that
fast, and the tab closes itself on the way out, while `open` has already
printed success. So poll once immediately after `open`: if that first answer
is already `{}`, stop and tell the user the review pane did not come up. Only
a `{}` that follows a poll showing a live review means they are done.

Do not wait for the review to turn `idle`. It reports `blocked` and then
releases its agent authority outright, so the record disappears rather than
transitioning, and `herdr agent wait --until idle` would sit there until it
times out.

A human review takes minutes, sometimes much longer. Do not sit in a tight
loop burning turns: poll about once a minute, and after a few minutes with no
change, tell the user the review is waiting and hand the turn back. Nothing
is lost — the session persists, and you can pick the comments up whenever you
are next asked.

Never send input to the review pane. It belongs to the user, and typing into
a TUI they are reading is worse than useless.

## Read the comments back

Once the review is gone, find the session tuicr persisted and read it. Use
the `cwd` that `open` reported, not `$PWD`:

```bash
review_repo=<the cwd from the open reply>
tuicr review list --repo "$review_repo"
tuicr review comments --repo "$review_repo" --session "<slug from the listing>"
```

`--repo` is not optional on either command. Without it tuicr resolves a local
slug against `.` and reports the session as missing.

The listing carries `comment_count`. A count of zero means they looked and
had nothing to say — but only trust that when the listing found the session
at all. An empty listing means you are pointed at the wrong repository far
more often than it means the review was silent.

Address each comment in the code. Do not reply by adding comments of your own
to the session unless the user asked you to review rather than to be
reviewed; that distinction is the `tuicr` skill's core rule.

## End a review

The review ends itself: quitting the tuicr TUI releases the agent and closes
the tab, which frees the workspace to hold the next one. You end one only
when the user abandoned it and asked you to clean up:

```bash
herdr-review close
```

Never close a review the user is still in.

## What not to do

- Do not open a review for a change the user has not asked to have looked at.
  A blocked agent is a demand for attention.
- Do not open one per file or per commit. One review covers the change.
- Do not treat `herdr-review` as a way to get a terminal. Use `herdr pane
  split` or `herdr tab create` for that.
- Do not report `review` agent state yourself with `herdr pane report-agent`.
  The script owns that pane's lifecycle, and a second reporter makes every
  herdr client lie.
- Do not report that a review passed when you never found its session. Say
  you could not read it.
