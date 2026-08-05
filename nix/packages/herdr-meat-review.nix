# The tool itself, for anyone who packages it.
#
# It exists because two consumers were each packaging this script from a pin
# of their own — one through a flake input, one through a hand-written
# revision — and the two could name different versions of a tool that goes
# on `PATH' under one name. The wrapper's tool list belongs here as well:
# both copies of it were kept in step by hand, and this file is the only one
# that knows which of those tools the script actually reaches for.
{
  lib,
  stdenv,
  makeWrapper,
  runCommand,
  bash,
  coreutils,
  gawk,
  git,
  gnugrep,
  gnused,
  jq,
  # The two tools the script talks to, which this repository pins neither
  # of. A consumer that has them as packages passes them in and gets a
  # script that finds them whatever a pane has on `PATH'; one that does not
  # gets the plain `PATH' lookup the README asks for.
  herdrPackage ? null,
  tuicrPackage ? null,
}:

let
  # Everything the script runs, whether or not the caller supplied the two
  # above. `jq' and `git' are not optional to it: `open' reads herdr's
  # snapshot through one and measures the review through the other.
  runtimeTools =
    [
      coreutils
      gnugrep
      gnused
      gawk
      git
      jq
    ]
    ++ lib.optional (herdrPackage != null) herdrPackage
    ++ lib.optional (tuicrPackage != null) tuicrPackage;

  package = stdenv.mkDerivation {
    pname = "herdr-meat-review";
    version = "0.2.0";

    # The script and nothing else, so that a change to the documentation or
    # the suite does not rebuild every consumer of the tool.
    src = lib.fileset.toSource {
      root = ../..;
      fileset = ../../bin;
    };

    nativeBuildInputs = [ makeWrapper ];

    postPatch = ''
      patchShebangs bin/herdr-meat-review
    '';

    doCheck = true;
    checkPhase = ''
      runHook preCheck
      ${bash}/bin/bash -n bin/herdr-meat-review
      runHook postCheck
    '';

    installPhase = ''
      runHook preInstall
      install -Dm755 bin/herdr-meat-review $out/bin/herdr-meat-review
      wrapProgram $out/bin/herdr-meat-review \
        --prefix PATH : ${lib.makeBinPath runtimeTools}
      runHook postInstall
    '';

    passthru.tests = {
      # The script reports its own usage without touching a server, which is
      # enough to prove the wrapper resolves and the interpreter is patched.
      runs = runCommand "herdr-meat-review-runs-test" { } ''
        ${package}/bin/herdr-meat-review --help > help.txt
        grep -Fq "herdr-meat-review open" help.txt
        touch $out
      '';
    };

    meta = {
      homepage = "https://github.com/roman/herdr-meat-review";
      description = "Run a tuicr code review as a first-class herdr agent";
      mainProgram = "herdr-meat-review";
      license = lib.licenses.asl20;
      platforms = lib.platforms.darwin ++ lib.platforms.linux;
    };
  };
in
package
