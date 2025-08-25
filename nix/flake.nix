{
  description = "Yap Perl CLI tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    flake-utils,
    nixpkgs,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
        yap = pkgs.callPackage ./default.nix {};
      in {
        packages.default = yap;
        packages.yap = yap;
        defaultPackage = yap;
      }
    );
}
