# herdr-review

Run [tuicr](https://github.com/dnaeon/tuicr) code reviews inside a
[herdr](https://herdr.dev) session, so a review waiting for you is as visible
as an agent waiting for you.

## herdr-review

`bin/herdr-review` is the whole tool. It opens a review, tells you whether one
is still open, and closes one nobody finished.

```bash
herdr-review open                  # review the working tree of this workspace
herdr-review open -- -r HEAD~3..HEAD   # anything after -- is tuicr's
herdr-review status                # {} once the operator is done
herdr-review close                 # for a review somebody walked away from
herdr-review marks                 # what has been reviewed so far
```

With no arguments, a review shows **what has arrived since the last one**.
Each review leaves a marker at the commit it opened on, under
`refs/reviews/<n>`, and the next starts there — so reviewing a branch twice
does not mean reading it twice. The first review has no marker to start
from and uses the branch point instead: everything this branch has that the
default one does not. On the default branch there is no branch point, so a
first review there is the working tree alone — `open` reports that as
`"empty": true` rather than leaving you to find out from a tab that closed
itself.

`open` creates a tab called `review` in the workspace, starts tuicr in it, and
prints the pane and tab it used. Quitting the tuicr TUI closes that tab again.

Run it from any herdr pane and it acts on the workspace you are in; pass
`--workspace w1` to act on another.

### How it looks in herdr

herdr has no idea what a code review is, so herdr-review piggy-backs on the
agents it already understands: it reports the review pane as an agent, and
herdr does the rest. A waiting review shows up in the Agents sidebar beside
Claude and Codex, its tab and workspace turn blocked along with it, and
`herdr agent wait` and the event stream see it like anything else.

## Requirements

- herdr 0.7.5 or later, running.
- `tuicr`, `jq`, `git` and `bash` on `PATH`.

Put `bin/herdr-review` on your `PATH`.

## Starting a review

From a coding agent. `skills/herdr-review` teaches an agent when to ask for a
review and how to read your comments back afterwards; install it and "have a
look at this before I merge" is enough. See [docs/agents.md](docs/agents.md).

By hand, from any herdr pane:

```bash
herdr-review open -- -r HEAD~3..HEAD
```

From Emacs, if you use herdr.el — it ships the panel and the commands. See
[docs/emacs.md](docs/emacs.md).

## Notes

**A workspace holds one review at a time.** Asking for a second focuses the
first and reports `"reused": true`. Two open reviews of one checkout is more
than most people can hold at once.

**Markers track commits, not the working tree.** Uncommitted work is shown
every review, because nothing can record that you saw it — commit before
asking for a review and the marker does its job. And the marker only holds
if the commits under it stay put: amending or rebasing at or below the
newest one replays everything already read. Tidy the branch after the last
review, not between two.

**The summary line counts what the review shows.** It asks git about the
same selectors tuicr was given, so a review of a range counts that range,
and no file counts twice. Where git has no answer —
a range that does not resolve, a directory outside a repository, or a
selector like `--file` that involves no history — the line reads `review
waiting` rather than naming a number nobody took.

**One writer per pane, as everywhere in herdr.** Opening the review pane
somewhere else takes input away from the terminal that had it.

## Hacking

See [docs/development.md](docs/development.md).
