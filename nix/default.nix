{
  perl,
  stdenv,
  lib,
  fetchFromGitHub,
  ...
}: let
  perlEnv = perl.withPackages (ps:
    with ps; [
      URIFind
      AppFatPacker
      FileShareDirInstall
    ]);

  src = fetchFromGitHub {
    owner = "guilherme-n-l";
    repo = "yap";
    rev = "v1.0.0";
    sha256 = "sha256-j/YJEsqRbSjaEq7HOmEx3Zo4f9NxKl8/5NwS5ATqHMA=";
  };
in
  stdenv.mkDerivation {
    pname = "yap";
    version = "1.0.0";

    src = "${src}/src";

    buildInputs = [perlEnv];

    buildPhase = ''
      export PERL5LIB="${perlEnv}/${perlEnv.perl.libPrefix}:${src}/src:$PERL5LIB"
      export PATH=${perlEnv}/bin:$PATH

      echo "PERL5LIB=$PERL5LIB"
      fatpack trace $src/main.pl
      fatpack packlists-for $(cat fatpacker.trace) > packlists
      fatpack tree $(cat packlists)

      mkdir -p fatlib
      cp $src/Utils.pm fatlib/

      fatpack file $src/main.pl > fatpacked.pl
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp fatpacked.pl $out/bin/yap
      chmod +x $out/bin/yap
    '';

    meta = {
      description = "Yap. A Perl CLI tool to write blog posts.";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [guilhermenl];
    };
  }
