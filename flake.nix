{
  description = "herdr-review, a code review as a first-class herdr agent";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/release-25.11";

    systems.url = "github:nix-systems/default";

    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    nixDir.url = "github:roman/nixDir/v3";
    nixDir.inputs.nixpkgs.follows = "nixpkgs";

    git-hooks.url = "github:cachix/git-hooks.nix";
    git-hooks.inputs.nixpkgs.follows = "nixpkgs";
  };

  # The whole build need here is shellcheck on PATH and a hook that runs the
  # gate. flake-parts and nixDir buy nothing this repository needs on its
  # own; they are here so that it and herdr.el are laid out the same way,
  # and someone who has read one `nix/' directory has read both.
  outputs =
    inputs:
    let
      overlays = import ./nix/overlays inputs;
    in
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = import inputs.systems;

      imports = [ inputs.nixDir.flakeModule ];

      # nixDir has no checks kind, and an empty `checks' would make `nix
      # flake check' report success without linting or testing anything.
      perSystem = { pkgs, ... }: { checks = import ./nix/checks.nix pkgs; };

      nixDir = {
        enable = true;
        root = ./.;

        # The overlays here are the channel that puts this repository's own
        # names in the `pkgs' a devshell file receives; nixDir's generated
        # one would resolve them back through `inputs.self.packages' and
        # make each package part of the fixpoint that defines it.
        generateFlakeOverlay = false;

        installOverlays = builtins.attrValues overlays;

        # Turn a directory nixDir skipped, for depth or a blocking sibling
        # file, into an error rather than an output that quietly never
        # appears.
        strictDiscovery = true;
      };
    };
}
