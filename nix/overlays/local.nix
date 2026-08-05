# What this repository builds for itself.
#
# An overlay rather than a plain binding because that is the only way a name
# reaches a nixDir devshell file, which is handed a package set and nothing
# else.
final: _prev: {
  herdr-meat-review = final.callPackage ../packages/herdr-meat-review.nix { };
  herdr-meat-review-check = final.callPackage ../packages/herdr-meat-review-check.nix { };
}
