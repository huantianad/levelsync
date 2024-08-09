{
  description = "test";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [];
        };
      in {
        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.nim2
            pkgs.nimble
            pkgs.sqlite
          ];
        };
      }
    );
}
