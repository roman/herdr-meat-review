# herdr-tuicr task runner

emacs := env_var_or_default("EMACS", "emacs")
lisp := "herdr-tuicr.el"
tests := "test/herdr-tuicr-tests.el"

# List the available recipes
default:
    @just --list

# Byte-compile, check declarations and doc strings, run tests
check: build check-declare checkdoc test

# Byte-compile the package and its tests, treating warnings as errors
build:
    #!/usr/bin/env bash
    set -euo pipefail
    load_path=$({{ just_executable() }} _load-path)
    for file in {{ lisp }} {{ tests }}; do
        printf 'Compiling %s\n' "$file"
        {{ emacs }} -Q --batch $load_path -L test \
            --eval '(setq byte-compile-error-on-warn t)' \
            --funcall batch-byte-compile "$file"
    done

# Run the ERT suite
test: build
    #!/usr/bin/env bash
    set -euo pipefail
    load_path=$({{ just_executable() }} _load-path)
    load=()
    for file in {{ tests }}; do
        load+=(-l "$(basename "$file" .el)")
    done
    {{ emacs }} -Q --batch $load_path -L test \
        "${load[@]}" -f ert-run-tests-batch-and-exit

# Run the ERT suite in a live Emacs, for stepping through a failure
test-interactive: build
    #!/usr/bin/env bash
    set -euo pipefail
    load_path=$({{ just_executable() }} _load-path)
    load=()
    for file in {{ tests }}; do
        load+=(-l "$(basename "$file" .el)")
    done
    {{ emacs }} -Q $load_path -L test "${load[@]}" --eval '(ert t)'

# Verify that every `declare-function' matches its definition
check-declare:
    #!/usr/bin/env bash
    set -euo pipefail
    load_path=$({{ just_executable() }} _load-path)
    printf 'Checking function declarations\n'
    {{ emacs }} -Q --batch $load_path \
        --eval '(check-declare-directory default-directory)'

# Check doc strings against checkdoc
checkdoc:
    #!/usr/bin/env bash
    set -euo pipefail
    load_path=$({{ just_executable() }} _load-path)
    printf 'Checking doc strings\n'
    # `checkdoc-file' reports to stderr and still exits successfully, so
    # the exit status is rebuilt from whether it said anything at all.
    {{ emacs }} -Q --batch $load_path -L test --eval '(progn
      (require (quote checkdoc))
      (let ((issues nil))
        (advice-add (quote checkdoc-error) :before
                    (lambda (&rest _) (setq issues t)))
        (dolist (file command-line-args-left) (checkdoc-file file))
        (when issues (kill-emacs 1))))' {{ lisp }} {{ tests }}

# Check the shell that owns the review lifecycle
checkbash:
    #!/usr/bin/env bash
    set -euo pipefail
    for file in bin/herdr-review test/bin/herdr; do
        printf 'Checking %s\n' "$file"
        bash -n "$file"
        if command -v shellcheck >/dev/null; then
            shellcheck "$file"
        fi
    done

# Remove byte-compiled files
clean:
    #!/usr/bin/env bash
    set -euo pipefail
    printf 'Cleaning *.elc\n'
    for file in {{ lisp }} {{ tests }}; do
        rm -f "${file}c"
    done

# Print the -L flags for herdr-tuicr and its dependencies.
#
# herdr.el is a separate project, so it is looked for as an installed
# package first and as a sibling checkout second.  Set HERDR_LISP_PATH to
# a checkout elsewhere, or EMACS_LOAD_PATH to take over entirely.
[private]
_load-path:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -n "${EMACS_LOAD_PATH:-}" ]; then
        echo "-L . ${EMACS_LOAD_PATH}"
        exit 0
    fi
    herdr=${HERDR_LISP_PATH:-}
    if [ -z "$herdr" ] && [ -f ../herdr.el/herdr-session.el ]; then
        herdr=$(cd ../herdr.el && pwd -P)
    fi
    echo "-L . ${herdr:+-L $herdr} $({{ emacs }} -Q --batch -f package-initialize --eval '
      (dolist (lib (list "magit-section"))
        (let ((file (locate-library lib)))
          (unless file
            (error "Cannot locate %s; set EMACS_LOAD_PATH" lib))
          (princ "-L ")
          (princ (file-name-directory file))
          (princ " "))))'"
