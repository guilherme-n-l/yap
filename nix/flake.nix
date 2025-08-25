{
  description = "Yap Perl CLI tool";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = {
    self,
    flake-utils,
    nixpkgs,
    ...
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = import nixpkgs {inherit system;};
        yap = pkgs.callPackage ./default.nix {};
      in {
        packages.${system} = {default = yap;};

        defaultPackage.${system} = yap;
      }
    );
}
