# herdr-review task runner

# Check the shell and run the suite
check: lint test

# Run the lifecycle suite against the stub herdr in test/bin
test *filter:
    ./test/run {{ filter }}

# Parse both scripts, and lint them when shellcheck is installed
lint:
    #!/usr/bin/env bash
    set -euo pipefail
    for file in bin/herdr-review test/bin/herdr test/bin/tuicr test/run; do
        printf 'Checking %s\n' "$file"
        bash -n "$file"
        if command -v shellcheck >/dev/null; then
            shellcheck "$file"
        else
            printf '  shellcheck not installed; parsed only\n'
        fi
    done
