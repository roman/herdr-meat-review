# herdr-review task runner

# Check the shell and run the suite
check: lint test

# Run the lifecycle suite against the stub herdr in test/bin
test *filter:
    ./test/run {{ filter }}

# Parse every script, and lint them when shellcheck is installed
lint:
    ./test/lint
