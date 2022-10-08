{
  description = "test";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    nimble.url = "github:nix-community/flake-nimble";
    nimble.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { self, flake-utils, nixpkgs, nimble }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        someOverlay = self: super: {
          nimPackages = super.nimPackages.overrideScope' (nself: nsuper: {
            zippy = nsuper.zippy.overrideAttrs (attrs: {
              # nativeBuildInputs = [ super.unzip ];
              doCheck = false;
            });
            testutils = nsuper.testutils.overrideAttrs (attrs: {
              doCheck = false;
            });
            stew = nsuper.stew.overrideAttrs (attrs: {
              doCheck = false;
            });
            chronos = nsuper.chronos.overrideAttrs (attrs: {
              doCheck = false;
            });
            faststreams = nsuper.faststreams.overrideAttrs (attrs: {
              doCheck = false;
            });
            json_serialization  = nsuper.json_serialization.overrideAttrs (attrs: {
              doCheck = false;
            });
            chronicles  = nsuper.chronicles.overrideAttrs (attrs: {
              doCheck = false;
            });
          });
        };

        pkgs = import nixpkgs {
          inherit system;
          overlays = [ nimble.overlay someOverlay ];
        };
      in
      rec {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            nim
            nimPackages.yaml
            nimPackages.zippy
            nimPackages.chronicles
            sqlite
          ];
        };
      }
    );
}
