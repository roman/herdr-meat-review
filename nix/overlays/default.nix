# Every overlay in this repository, so flake.nix carries inputs and nothing
# else. `local' is a plain function of a package set; `git-hooks' needs an
# input, which is why it takes one before the usual `final: prev'.
inputs:

{
  git-hooks = import ./git-hooks.nix inputs;
  local = import ./local.nix;
}
