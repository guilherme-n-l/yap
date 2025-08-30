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
        buildEnv = pkgs.perl.withPackages (ps:
          with ps; [
            URIFind
            AppFatPacker
            FileShareDirInstall
          ]);
        devEnv = pkgs.perl.withPackages (ps: with ps; [PLS LogLog4perl PerlTidy podlators]);
        yap = pkgs.callPackage ./default.nix {perlEnv = buildEnv;};
      in {
        packages.default = yap;
        packages.yap = yap;
        defaultPackage = yap;
        devShell = pkgs.mkShell {
          packages = [buildEnv devEnv];
          shellHook = ''
            cd ../src

            export PERL5LIB="${buildEnv}/${buildEnv.perl.libPrefix}:${devEnv}/${devEnv.perl.libPrefix}:$PWD:$PERL5LIB"
            export PATH=${buildEnv}/bin:${devEnv}:$PWD:$PATH

            for i in perl perltidy; do
                $i --version | grep -v '^[[:space:]]*$' | head -n 1
            done

            for i in PLS Log::Log4perl URI::Find App::FatPacker; do
                version=$(cpan -D "$i" | grep "Installed" | awk '{print $NF}')
                echo "$i -- $version"
            done
          '';
        };
      }
    );
}
