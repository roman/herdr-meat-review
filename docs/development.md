# Development

```bash
just check    # parse and lint both scripts, then run the suite
just test     # the suite alone
just test race    # only tests whose name contains "race"
```

`shellcheck` is used when it is installed and skipped with a note when it is
not.

## The stub herdr

`test/bin/herdr` is a herdr that keeps a session in files instead of talking
to a server. The suite puts it first on `PATH`, so `herdr-review` drives it
without knowing the difference. It implements only the subcommands
`herdr-review` uses, and exits 64 on anything else, so a new call site cannot
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
claim at the moment `herdr-review` makes its own, which puts the script
deterministically on the losing side of it.

A failing test leaves its session directory behind and names it, so you can
read what the script did to it.

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
# delete the claim-verify block from bin/herdr-review, then:
just test race     # should report the stand-down test failing
```
