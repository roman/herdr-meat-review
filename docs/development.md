# Development

```bash
nix develop       # shellcheck, jq, git and just, and a pre-commit hook
just check        # lint every script, then run the suite
just test         # the suite alone
just test race    # only tests whose name contains "race"
nix flake check   # the same gate, hermetically, from a clean checkout
```

The flake is how the gate answers the same on two machines. Outside it,
`just lint` falls back to parsing each script with `bash -n` and says it
skipped the linting — enough to work without nix, but it is not the gate.

`test/lint` finds every executable file under `bin/` and `test/`, so a new
script is linted without anybody adding it to a list. It is a script rather
than a recipe because a justfile recipe with a shebang runs through
`/usr/bin/env`, which does not exist inside the `nix flake check` sandbox.
That sandbox is stricter than any shell you will develop in, and it has
already caught two things that only fail there.

The shell carries no herdr and no tuicr, but it cannot take away the ones
you have installed — `mkShell` only prepends. What keeps the suite off a
live server is `test/run` putting `test/bin` first on `PATH`, so the stubs
shadow whatever else is there. That shadowing is also what lets the suite
reach states a live server cannot be asked for.

## The stub herdr

`test/bin/herdr` is a herdr that keeps a session in files instead of talking
to a server. The suite puts it first on `PATH`, so `herdr-meat-review` drives it
without knowing the difference. It implements only the subcommands
`herdr-meat-review` uses, and exits 64 on anything else, so a new call site cannot
pass unnoticed.

Its session lives under `$HERDR_STUB_STATE`:

| file | holds |
| --- | --- |
| `panes` | one `PANE TAB WORKSPACE CWD` per line |
| `claims` | the panes currently reporting an agent |
| `workspaces` | one `WORKSPACE ACTIVE_TAB LABEL` per line |
| `next` | the counter public ids are cut from |
| `log` | one line per command, for a test to assert against |
| `on-claim` | optional hook, run after each `report-agent` |

`on-claim` is the reason the stub exists at all. A live server cannot be asked
for two callers claiming one workspace in the same instant, and that race is
what the one-review-per-workspace rule turns on. The hook injects a competing
claim at the moment `herdr-meat-review` makes its own, which puts the script
deterministically on the losing side of it.

A failing test leaves its session directory behind and names it, so you can
read what the script did to it.

## The stub tuicr

`test/bin/tuicr` draws nothing and returns at once, so the pane-side half of
a review — the `host` subcommand — can be driven without a terminal or a
reviewer. It appends its own arguments to the same `log` the herdr stub
writes, which is how a test asks whether the row and the TUI were given the
same review to answer for.

## Adding a test

Add a function named `test_*` to `test/run`. The runner finds it, gives it a
fresh session holding one workspace `w1` whose root pane is `w1:p1`, and
counts one failure per test however many assertions notice it.

```bash
test_open_does_the_thing() {
  local reply
  reply=$("$REVIEW" open --workspace w1)
  assert_equal w1:p2 "$(printf '%s' "$reply" | jq -r .pane_id)" "pane"
  assert_contains "$(state_file log)" "report-agent" "log"
}
```

## Checking that a test would fail

A test that has never failed has not been shown to test anything. The cheapest
check is to break the thing on purpose and run the suite:

```bash
# delete the claim-verify block from bin/herdr-meat-review, then:
just test race     # should report the stand-down test failing
```

## Releasing

`VERSION` holds the number. The nix package reads it, the script reads it to
answer `version`, and a passthru test fails if the installed tool disagrees
with the package — so there is nowhere else to change.

A change that anyone using the tool would notice goes in `CHANGELOG.md` under
a new heading, with `VERSION` bumped to match in the same commit. While the
major version is 0, anything a consumer could be relying on bumps the minor:
that includes wake wording, since agents are told to read it, and the fields
`open` prints, since callers parse them.
