---
topic: reviews now wake the agent that asked for one instead of being polled for, the tool is exported as a package so its two packagers stopped drifting, and the whole thing was renamed to herdr-meat-review across four repositories
date: 2026-08-05
status: All four repositories pushed and clean — herdr-meat-review at ebd8188, herdr.el at 7ca5c62, minerva at 0899119, zoo.nix at 51e5e0f. Every gate green. `just install` has not been run, so the machine still has the old build and the old rules.
---

# Handoff: a review wakes the agent now, and the tool is called herdr-meat-review

Roman started by asking how the three review tools compare — this one, tuicr
underneath it, and persiyanov/herdr-reviewr — and the comparison turned up the
thing he actually wanted fixed: an agent that opened a review had to poll for
the reviewer to finish, and in practice he had to tell it "check the review".
The session ended four repositories later with that fixed, the tool exported as
a package, and everything renamed.

## The spike that decided the design

Whether any of this was possible turned on what tuicr does with a comment
before you quit. I ran a real tuicr 0.19.1 in a detached tmux, against a
throwaway repository, with `XDG_DATA_HOME` pointed at a scratch directory so
Roman's own review store was untouched. Four facts, all verified rather than
assumed:

- tuicr writes each comment to its session JSON the moment you press Enter. No
  `:w`, no quit.
- `tuicr review list` reports `active: true` while the TUI is up and `false`
  after it exits, so both edges of a review are observable from outside.
- Comments carry a stable `id` and `created_at`, so "new since I last looked"
  is a set difference rather than a guess.
- `--session` accepts a path and resolves without `--repo`.

The fourth fact is the trap: **tuicr reuses a session, with its prior comments,
when the same range is reviewed again.** A watcher that started from an empty
watermark would re-announce the last round's comments on every review. The
watermark is seeded at `bin/herdr-meat-review:470` for that reason, and a
mutation test pins it.

## What I built

`open` records the pane of the agent that asked, from `HERDR_PANE_ID`, and
passes `--notify` down to `host`, which runs a watcher beside tuicr. The
watcher polls the live session and wakes the agent on a debounced burst of new
comments. The closing wake does **not** come from the watcher — it comes from
the pane's exit path, `release_host`, so it survives a review that ended by
`close` or by the tab being taken away rather than by the reviewer quitting.

Roman chose the policy at a fork I put to him: the mid-review wake tells the
agent to read and plan but **not** to edit, because the reviewer is looking at
the very files an edit would move under them. That turns the comment wakes into
a prefetch and makes the closing wake the go-ahead.

The feature validated itself on its first production run. I opened the meat
review for this change using `./bin/herdr-meat-review` from the checkout rather
than the packaged copy, and both wakes fired unprompted — one when Roman paused
mid-review, one when he quit.

## What code-critic found

The first version had six defects; code-critic reproduced four of them. All are
fixed, and the three subtlest have mutation tests — I broke each fix and
confirmed the suite fails.

| Defect | Fix |
| --- | --- |
| The EXIT trap killed the watcher, so `close` lost the closing wake the skill now promises | the wake moved into `release_host` |
| The watcher re-resolved the session each poll, so it could follow another workspace's review | it binds one path, then only asks whether *that* one is live |
| `unread` at close read a stale variable | the count is taken from the session; `unread` dropped entirely |
| An empty review held the workspace slot for 20 seconds | `wait_briefly` deleted |
| `announced` advanced even when the wake failed to deliver | it advances only on success |
| A reused review silently woke nobody | `open` reports `notified` |

Tests went from 37 to 42. The timing-sensitive ones no longer sleep — the tuicr
stub counts polls and `settle` waits for that count to advance, so they do not
depend on machine speed.

## The duplication Roman spotted

He asked whether the Emacs plugin and the minerva skill each had their own copy
of the script. They did — not vendored source, but two build definitions and
two independent pins: a hand-written `fetchFromGitHub` revision in zoo.nix and
a flake input in minerva. Both produced byte-identical scripts and both landed
on `PATH` under one name. Moving one pin without the other, which I had just
had to do by hand, made the name mean two different things.

The fix was to export the tool from its own repository as an overridable
package and have both consumers take it. The `follows` in zoo.nix is what
actually completes it: without it there were still two lock nodes, identical
today and free to drift on the next update. The system closure went from two
builds of the script to one, referenced by `claude-plugin-herdr`,
`emacs-default` and `skill-herdr`.

## The rename

`herdr-review` became `herdr-meat-review`, because "review" alone no longer said
whether a person or an agent was going to read the diff. Roman picked the scope:
project, command, skill and package, but not the elisp.

Two names deliberately did not move, and both would have broken things quietly:

- **`AGENT_KIND=review`.** `herdr.el` hard-codes `"review"` in
  `herdr-review-agent` and feeds it to `herdr-agents-hidden-kinds`. Renaming it
  would have put review rows back in the Agents panel. It names what herdr is
  showing, not what the project is called.
- **The elisp `herdr-review-` prefix.** Emacs Lisp names a library after the
  file that holds it. Only the `herdr-review-program` default moved. This one
  nearly caught me: a blanket rename would have silently broken
  `herdr-review = herdr-el` in the rapture plugin's library map and the
  `(setq herdr-review-program ...)` in its `config.org`, so I edited zoo.nix
  file by file instead of by `sed`.

Finally Roman asked for the term to reach the rules, so `~/.claude/CLAUDE.md`
and `personal/rules/code-refinement.md` now say *meat review* and define it once
where it is introduced.

## Gaps

- `just install` has not been run. Until it is, the machine has the old build
  and `herdr-review` on `PATH`.
- The local checkout is still `~/Projects/oss/herdr-review`, and its `git
  remote` still points at the old URL. GitHub redirects, so nothing is broken.
  I left both alone because renaming the directory mid-session would have
  broken the paths I was working from.
- An eval trace says `Emacs package herdr-session, declared wanted with
  use-package, not found`. It predates this work — the closure hash was
  unchanged across the commit that surfaced it — but nobody has looked at it.
- The watcher seeds its watermark one poll after tuicr registers, so a comment
  written inside that window is treated as belonging to an earlier round. It
  still reaches the agent in the closing count. Documented at
  `bin/herdr-meat-review:470`; the window is the time it takes a person to read
  a diff they have not seen.

## Skills and meta

**Skills used.**

- `code-critic` — reviewed the watcher before it landed — six defects, four
  reproduced by it directly; all fixed.
- `herdr:review` — opened the meat review of the watcher change — the review
  came back LGTM plus a check that I had actually read the comments.
- `elisp-development` — fired on the `herdr-review.el` edit — prompted me to
  check `:package-version`, which was correct to leave at `0.1.0` since the
  package is pre-release and every option there carries it.
- `writing:handoff` — this document.

**Steering.**

- The `UserPromptSubmit` hook suggested `writing:author` for the rename request
  and `obsidian-cli` for the handoff request. Both misfired — the first was a
  mechanical rename, not document authoring, and the second was a handoff to a
  repository directory, not an Obsidian vault. I skipped the first and used
  `writing:handoff` for the second. Worth looking at the trigger patterns.
- I truncated Roman's `~/.local/share/tuicr/reviews/index.json` to zero bytes
  early on: I wrote a `jq` filter assuming `.entries` was an array of objects
  when it is a map of slug to array, and moved the failed output over the real
  file. Restored from a backup I had taken one command earlier. The lesson is
  the one the failure-analysis rule already states — inspect the shape before
  transforming it — and the backup is what made it a non-event. Every later
  spike used an isolated `XDG_DATA_HOME` instead of touching the real store.

**Meta.**

- minerva's skill package asserts sentences from `SKILL.md` at build time. When
  I deleted the sentence about polling, the build failed rather than shipping a
  skill that described behaviour the script no longer had. That guard earned its
  keep in this session and is worth copying wherever a skill and its tool ship
  from one source.
- Renaming a flake input before the GitHub repository is renamed makes the
  consumer repositories uncommittable — the pre-commit hook evaluates the flake
  and the fetch 404s. I verified the code by substituting the local checkout for
  the input, then waited. Worth sequencing deliberately next time: rename on the
  forge first, or expect a pause.
