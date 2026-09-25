{
  description = "b2i2b - copy block devices to compressed images and back";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      packages = forAllSystems (pkgs: rec {
        b2i2b = pkgs.callPackage ./package.nix { };
        default = b2i2b;
      });

      overlays.default = final: prev: {
        b2i2b = final.callPackage ./package.nix { };
      };
    };
}
