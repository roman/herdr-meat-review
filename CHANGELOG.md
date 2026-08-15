# Changelog

Notable changes to herdr-meat-review, newest first.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the version in [VERSION](VERSION) is the one the tool reports and the nix
package carries. While the major version is 0, a behaviour change that a
consumer could be relying on bumps the minor. That includes the wording of a
wake, since agents are told to read it, and the fields `open` prints, since
callers parse them.

## 0.3.0 — 2026-08-15

### Added

- `herdr-meat-review version`, also `--version` and `-V`, and the version as
  the first line of the usage output.

### Changed

- Every wake names the checkout the review is of. A session path is an opaque
  file name, so an agent woken about another project's review could not tell
  it from its own without opening the session.
- The `cwd` reported by `open` is the top of the working tree rather than the
  directory passed to `--cwd`. That is the value tuicr answers to when looking
  a session up again. The review itself still opens on the directory given, so
  relative tuicr arguments are unaffected.
- The closing wake for a review with no session no longer says that nothing
  was put in front of the reviewer. Two causes produce that state and nothing
  at that point can tell them apart, so it names the directory it searched and
  no cause.

### Fixed

- A review no longer wakes an agent working on a different project. The pane
  to wake came from the environment and the directory to review from `--cwd`,
  and nothing checked the two agreed, so opening a review of one checkout from
  another project's agent interrupted that agent about work it was not doing.
  Projects are compared by their shared git directory, so an agent that has
  moved into a linked worktree still counts as working on what it asked for.
- Reviews opened on a subdirectory are found again. tuicr files a session
  under the top of the working tree but matches `--repo` against the exact
  path it is handed, so a review opened below the root was stored in one place
  and searched for in another. In a monorepo that was every review: no comment
  was ever announced, and the closing wake reported that the review had never
  opened while a person was reading it.

## 0.2.0 — 2026-08-05

### Added

- Reviews wake the agent that asked for them, rather than being polled. A
  watcher started beside the TUI reports comments as they arrive and again
  when the review closes, however it ended. A burst of comments is one wake,
  and an agent that is mid-turn is never interrupted.
- `open` reports whether the review will wake its caller at all, in
  `notified`; `--no-notify` opens one that wakes nobody.
- A nix package, so consumers stop packaging the script from pins of their
  own and the wrapper's tool list has one home.

### Changed

- Renamed from `herdr-review` to `herdr-meat-review`, the name distinguishing
  a review a person reads from one an agent performs.

## 0.1.0 — 2026-08-02

### Added

- Run a tuicr code review in its own herdr tab, reported to herdr as a blocked
  `review` agent so it reaches whatever herdr client the user is looking at.
- One review per workspace, claimed before the pane starts so two callers
  racing cannot both open one.
- Each review shows what arrived since the last one, marked with
  `refs/reviews/<n>`; the first review of a branch measures against its branch
  point.
- `open` says in its reply when there is nothing to show, rather than opening
  a tab that closes itself again.
- `open`, `close`, `status` and `marks` subcommands, each printing one JSON
  object.
