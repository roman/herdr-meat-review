# Reviews in Emacs

[herdr.el](https://github.com/roman/herdr.el) ships the Emacs half: a Reviews
panel beside its Spaces and Agents panels, and the commands that open and
close a review. Nothing Emacs-related lives in this repository.

The Emacs side keeps the `herdr-review` prefix on its own symbols. Elisp names
a library after the file it lives in, and that file is herdr.el's to rename.
Only the script this repository ships is called `herdr-meat-review`.

## Setup

Put `bin/herdr-meat-review` on your `PATH`, then load the file:

```elisp
(require 'herdr-review)
```

That is the whole setup. `herdr-review` is not loaded with the rest of herdr.el
— it needs this tool, which herdr.el does not — so requiring it is the opt-in.
Loading it puts the Reviews panel in the column and takes review rows out of
the Agents panel, so a review appears in one place rather than two.

If the script is somewhere `exec-path` does not reach, name it:

```elisp
(setq herdr-review-program "/path/to/herdr-meat-review/bin/herdr-meat-review")
```

## Using it

| | |
| --- | --- |
| `M-x herdr-review` | the panel on its own |
| `M-x herdr-review-open` | review the workspace at point, or the one you are in |
| `M-x herdr-review-close` | end that workspace's review |
| `+` and `-` | the same two, in the panel |
| `RET` | open the review's terminal here |

`herdr-review-open` works from a row in any herdr panel, not just the Reviews
one: every panel can name the pane its current row stands for, and the pane
names the workspace.

A row shows the workspace under review, a mark carrying its state, and what is
waiting:

```
Reviews
 ● herdr.el ⌥
   8 files to review
```

## Requirements

Emacs 29.1, magit-section, and a herdr.el new enough to have
`herdr-agents-hidden-kinds` and a `herdr-ui-panels` that lists
`herdr-review-panel`. Against an older herdr.el, `(require 'herdr-review)` fails
with `Symbol's value as variable is void: herdr-agents-hidden-kinds`.
