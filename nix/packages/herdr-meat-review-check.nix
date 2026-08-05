# `just check' with its tools baked in, so the pre-commit hook holds whether
# the commit comes from the dev shell, from magit, or from an editor that
# inherited neither PATH.
#
# Which is why the list below runs past the obvious three: the suite makes a
# repository per test and reads the stub's state back, so it reaches sed,
# awk, grep and half of coreutils on the way. `writeShellApplication' only
# prepends to PATH, so anything missing here is borrowed from the caller and
# the guarantee above is not one.
{
  writeShellApplication,
  just,
  git,
  jq,
  shellcheck,
  bash,
  coreutils,
  findutils,
  gnused,
  gawk,
  gnugrep,
}:

writeShellApplication {
  name = "herdr-meat-review-check";

  runtimeInputs = [
    just
    git
    jq
    shellcheck
    bash
    coreutils
    findutils
    gnused
    gawk
    gnugrep
  ];

  text = ''
    just check
  '';
}
