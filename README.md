# herdr-tuicr

Code review as a first-class citizen of a herdr session.

A review is a [tuicr](https://github.com/dnaeon/tuicr) TUI running in its own
tab of the workspace whose code is under review, and herdr treats it as an
agent: it goes `blocked` while it waits for the operator, and that state
rolls up to the tab and the workspace like any other. herdr's own sidebar
lists it beside Claude and Codex, because to herdr it is just another agent.
herdr.el goes further and gives reviews a panel of their own.

This is deliberately a separate initiative from herdr.el. herdr.el is a
porcelain over herdr and should work on a machine that has never heard of
tuicr; nothing in it mentions tuicr, and nothing here is loaded unless you ask
for it.

## How it works

herdr has no concept of a code review, and it does not need one. The socket
API accepts a state report for any agent label, not just the twenty-one
coding agents it detects natively:

```bash
herdr pane report-agent w1:p4 --source custom:herdr-review --agent tuicr --state blocked
```

That single call is the whole trick. herdr adds the pane to `agent.list`,
rolls `blocked` up to the tab and the workspace, and emits
`pane.agent_detected` and `pane.updated` on the event stream — the same
stream herdr.el already follows. Every herdr client learns about the review
without being taught what tuicr is.

Around that, `bin/herdr-review` owns the lifecycle: it creates the tab, runs
tuicr in it, attaches a display-only summary of what is waiting, and on exit
releases the agent and closes the tab.

## Requirements

- herdr 0.7.5 or later, running.
- `tuicr`, `jq`, `git` and `bash` on `PATH`.
- For the panel: Emacs 29.1, magit-section, and a herdr.el with
  `herdr-ui-add-panel` and `herdr-agents-hidden-kinds`. Both landed for this
  package; against an older checkout, loading fails with `Symbol's value as
  variable is void: herdr-agents-hidden-kinds`.

The script needs none of the Emacs side. `herdr-review` works on its own in
any herdr pane.

## Install

Put `bin/herdr-review` on your `PATH`, or set `herdr-tuicr-program` to its
full path. Then:

```elisp
(add-to-list 'load-path "/path/to/herdr-tuicr")
(require 'herdr-tuicr)
```

Loading it adds the Reviews panel to the herdr layout and takes review rows
out of the Agents panel, so a review appears in exactly one place.

## Starting a review

The same script backs all three, so a review started one way ends the same
way as one started another.

From a coding agent, using the skill in `skills/herdr-review`:

```bash
herdr-review open
```

From any herdr pane, by hand:

```bash
herdr-review open --workspace w1 -- --revisions HEAD~3..HEAD
```

From Emacs, on the row at point in any herdr panel:

```
M-x herdr-tuicr-open      (or + in the Reviews panel)
```

## One review per workspace

Asking for a second review of a workspace focuses the first. Two open reviews
of one checkout is more than an operator can hold at once, and the constraint
is what lets the panel show one row per workspace instead of a list that
needs reading.

## Ending a review

Quit the tuicr TUI. The script releases the agent authority and closes the
review tab, which frees the workspace for the next one. `herdr-review close`
(or `-` in the panel, or `M-x herdr-tuicr-close`) is for the review somebody
walked away from.

## Tests

`just test` runs these with the rest of herdr.el's suites.

The panel is driven from a hand-written session snapshot. The lifecycle is
driven for real, against the stub herdr in `test/bin`, which keeps a session
in files instead of a server. That stub exists for the one state a live
server cannot be asked for: its `on-claim` hook injects a competing claim at
the instant the script makes its own, which is the race the one-review rule
turns on.

## What herdr.el had to grow

Two extension points, both generic and neither aware of this package:

- `herdr-agents-hidden-kinds` — kinds of agent the Agents panel leaves out,
  for a kind that has a panel of its own.
- `herdr-ui-panels` and `herdr-ui-add-panel` — the column of panels as a
  list. The option holds the panels herdr ships and the weights you give
  them; a package registers its own panel separately, so that a value saved
  by Customize cannot silently drop a registration made before it was read.
  This replaced `herdr-ui-spaces-height`, which is now obsolete.

## Caveats

- **The summary is a count of uncommitted files, taken once.** It reads `git
  status --porcelain` in the workspace directory when the review opens, and
  it ignores whatever tuicr arguments you passed — review a commit range and
  the row still describes the working tree. It also does not track comments
  the operator adds while reviewing; tuicr owns those, and reading them back
  is `tuicr review comments`.
- **The review pane is single-writer, like every herdr pane.** Opening it in
  Emacs takes control from a terminal that had it.
- **Killing the pane skips the cleanup.** The `EXIT` trap covers quitting
  tuicr and interrupting it, but a pane closed out from under the script
  takes the agent record with it anyway, so the workspace still ends up
  free.
