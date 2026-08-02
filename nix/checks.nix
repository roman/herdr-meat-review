# The gate as something `nix flake check' can run.
#
# nixDir has no checks kind, so this one is wired up by hand in flake.nix.
# Without it `nix flake check' evaluates a shell and builds a wrapper and
# reports success having linted nothing and run no test, which is a worse
# answer than no check at all.
pkgs:

{
  gate = pkgs.runCommand "herdr-review-gate" {
    nativeBuildInputs = [
      pkgs.just
      pkgs.git
      pkgs.jq
      pkgs.shellcheck
      pkgs.findutils
    ];
  } ''
    cp -R ${../.} source
    chmod -R u+w source
    cd source

    # There is no /usr/bin/env in here, so every `#!/usr/bin/env bash' has
    # to be rewritten to a store path before anything will run.
    patchShebangs bin test

    # git refuses to read a config it cannot find a home for, and the suite
    # makes a repository per test.
    export HOME=$TMPDIR

    just check
    touch $out
  '';
}
