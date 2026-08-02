# The shell `just check' runs in: shellcheck over every script, then the
# lifecycle suite.
#
# shellcheck is the reason this shell exists. Without it `just lint' parses
# each script and says it skipped the linting, which is honest but means the
# gate answers differently on two machines.
pkgs:

pkgs.mkShell {
  packages = [
    pkgs.just
    pkgs.git
    pkgs.jq
    pkgs.shellcheck
  ];

  # Installs a pre-commit hook that runs the same gate.
  inherit (pkgs.herdr-review-git-hooks) shellHook;
}
