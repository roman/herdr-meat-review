# What this repository builds for itself.
#
# An overlay rather than a plain binding because that is the only way a name
# reaches a nixDir devshell file, which is handed a package set and nothing
# else.
final: _prev: {
  herdr-review = final.callPackage ../packages/herdr-review.nix { };
  herdr-review-check = final.callPackage ../packages/herdr-review-check.nix { };
}
