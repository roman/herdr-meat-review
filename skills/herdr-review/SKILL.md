---
name: herdr-review
description: Get a human to review your change inside a herdr session and be woken when they comment, each review showing only what arrived since the last one. Use this whenever you are working in a herdr pane and the user wants a change looked at before it lands — "review this", "take a look before I merge", "put this in front of me", "wait for my review" — and again afterwards when they ask what they said, whether they left comments, or to address the review. This is for a human reviewer; when they want another agent to review instead, the herdr skill's agent start is the one. Inside herdr prefer this over the tuicr skill: do not start tuicr in tmux or zellij when herdr owns the session. Checks HERDR_ENV and stops if you are not in a herdr pane.
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
{"pane_id":"w1:p4","tab_id":"w1:t4","cwd":"/home/you/project","reused":false,
 "summary":"6 files to review","empty":false,"notified":true}
```

**Check `empty` before you tell anyone a review is waiting.** tuicr quits at
once when it is given nothing to show, which closes the tab and releases the
pane, so `"empty": true` means the review has already gone. Say so and ask
what to review, rather than waiting for a reviewer who was never shown
anything.

**Check `notified` before you hand the turn back.** `true` means this review
will wake you and you should stop and wait. `false` means it will not, and
nothing will arrive — you get that on a reused review, because the running
one wakes whoever opened it, and when the review was not opened from your own
pane. With `false`, tell the user you cannot be woken and ask them to say when
they are done.

What it does, in order: creates a tab labelled `review` in the workspace,
reports that pane to herdr as a blocked `review` agent, and starts tuicr in
it with a one-line summary of what is waiting. The blocked state is published
before the TUI exists, so the review is visible and the workspace's one
review slot is taken from the moment the tab appears.

It also starts watching the review on your behalf, so that you hear about
comments without anyone telling you. That works because you opened it from
your own pane: herdr puts the pane id in your environment, and `open` records
it as the one to wake. **So run `open` yourself.** A review opened any other
way has no agent behind it and wakes nobody.

### Each review picks up where the last one left off

With no tuicr arguments, `open` shows what has arrived since the previous
review — not the whole branch again. Every review leaves a marker at the
commit it opened on, under `refs/reviews/<n>`, and the next one starts
there. `herdr-review marks` lists them.

The first review of a branch has no marker to start from, so it uses the
branch point: everything the branch has that the default one does not.

**On the default branch itself there is no branch point**, so a first review
there is the working tree and nothing else. The same happens where the
default branch cannot be worked out at all — `origin/HEAD` is set by `git
clone` and by nothing else, so a repository that started local and is not on
`main` or `master` has nothing to measure against. Both show up as
`"empty": true`, and the answer is to name a range yourself:

```bash
herdr-review open --cwd "$PWD" -- --revisions <the commits you want>..HEAD
```

Uncommitted work is shown every time, because nothing can record that it was
seen. **So commit before asking for a review.** Work you leave uncommitted
is read once now and again in the next review, and the reviewer will not
know which parts they have already been through.

That leaves one rule, and it is the whole reason this works:

> **Address review comments in new commits. Never `commit --amend`,
> `rebase`, or `reset` at or below the newest marker.**

Rewriting a commit the marker sits on or below moves it out from under the
marker, and the next review replays everything the reviewer already read.

### Collapse the rounds when the review is over

Those per-round commits are scaffolding. They exist so each marker has
something to point at, not because the change is really five changes. When
the user says the review is finished, squash them into what they describe —
one commit, or one per concern where the work covered more than one.

This is the only moment rewriting is safe, and it is the other half of the
rule above: between two rounds a rewrite costs the reviewer a full re-read;
after the last one it costs nothing. Do not leave the scaffolding standing
because the rule above sounded absolute.

Then move the newest marker onto what you built:

```bash
git update-ref refs/reviews/<n> HEAD
```

Skip this and the marker still names a commit the branch no longer
contains, so the next review starts from nowhere and replays the whole
change. `herdr-review marks` shows which `<n>` is newest.

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
already has one focuses the first and returns `"reused": true` — and
`"notified": false`, because the review already running wakes whoever opened
it, not you. Do not work around this by creating tabs yourself: the limit is
deliberate, because two open reviews of one checkout is more than a person
can hold at once.

Do not pass `--focus` unless the user asked to be taken to the review.
Taking over their screen is what the blocked state exists to avoid.

## Hand the turn back — the review will wake you

**Do not poll.** A review you opened watches itself and prompts you. Say the
review is open, and stop. You will be given a new turn when there is
something to do.

You get woken when there is news, and always once at the end. The closing
wake goes out however the review ended — the user quitting, `close`, or the
tab being taken away — so it is safe to wait for.

**Comments arrived.** The reviewer has written something and paused. The
prompt says how many and gives you the session path.

> **Read them. Do not edit anything yet.** The reviewer is still reading the
> very files you would change, and a diff that moves under them costs them
> the read. Understand each comment, work out what you will do, ask the user
> if one is ambiguous — they are right there — then hand the turn back.

**The review is closed.** Nothing more is coming, and the count in the prompt
is of the whole session — including comments you were never woken about, and
anything the reviewer wrote in the moment before the watcher started.
**Now do the work.**

**The review never opened.** tuicr registered no session, so nothing was put
in front of anyone — usually because tuicr is not on the review pane's
`PATH`. Do not wait. Tell the user and ask what to review.

Read comments with the session path the prompt gives you:

```bash
tuicr review comments --session <path from the prompt>
```

That path resolves on its own — no `--repo`, and no slug to look up.

### When you are woken about comments but were asked something else

The wake arrives as an ordinary turn, so it can land while you are in the
middle of other work. Finish what the user asked for first, then deal with
the review. The comments are on disk and are not going anywhere.

### If you need to check by hand

`herdr-review status` still answers: a live review reports `agent_status`,
`pane_id`, and its summary at `.tokens.summary`, and `{}` means no review is
open. Use it when the user asks whether a review is still up, or when `open`
reported `"notified": false` and nothing will reach you. Do not build a
polling loop out of it when you will be woken.

Never send input to the review pane. It belongs to the user, and typing into
a TUI they are reading is worse than useless.

## Read the comments back

The wake prompts carry the session path, so prefer that. When you have lost
it — a review opened in an earlier session, or one you did not open — find it
from the `cwd` that `open` reported, not `$PWD`:

```bash
review_repo=<the cwd from the open reply>
tuicr review list --repo "$review_repo"
tuicr review comments --repo "$review_repo" --session "<slug from the listing>"
```

`--repo` is not optional on either command when you go by slug. Without it
tuicr resolves a local slug against `.` and reports the session as missing.

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
- Do not edit while a review is open. You are woken about comments so that
  you can read and plan, not so that you can start changing files the
  reviewer is looking at. Wait for the closing wake.
- Do not poll `herdr-review status` in a loop waiting for a verdict. You will
  be woken. A loop only spends turns to learn what arrives on its own.
