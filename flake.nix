{
  description = "Reopen Claude Code sessions in tmux or cmux after a reboot";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in {
      packages = forAllSystems (system: rec {
        claude-restore = nixpkgs.legacyPackages.${system}.callPackage ./package.nix { };
        default = claude-restore;
      });

      homeManagerModules.default = import ./module.nix;

      checks = self.packages;
    };
}
