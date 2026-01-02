{
  stdenv,
  perlEnv,
  lib,
  fetchFromGitHub,
  ...
}: let
  src = fetchFromGitHub {
    owner = "guilherme-n-l";
    repo = "yap";
    rev = "v2.0.0";
    sha256 = "sha256-D7/Kp3/3gLsfCWHQp/1t0BEemw1lrq2pDVEegQlpdZA=";
  };
  version = "1.0.1";
in
  stdenv.mkDerivation {
    pname = "yap";
    version = version;

    src = "${src}/src";

    buildInputs = [perlEnv];

    buildPhase = ''
      export PERL5LIB="${perlEnv}/${perlEnv.perl.libPrefix}:${src}/src:$PERL5LIB"
      export PATH=${perlEnv}/bin:$PATH

      echo "PERL5LIB=$PERL5LIB"

      mkdir -p man/man1
      pod2man --section=1 --center="Yap Documentation" --name="YAP" --release="yap ${version}" $src/main.pl man/man1/yap.1

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

      mkdir -p $out/share/man/man1
      cp man/man1/yap.1 $out/share/man/man1/
    '';

    meta = {
      description = "Yap. A Perl CLI tool to write blog posts.";
      license = lib.licenses.mit;
      maintainers = with lib.maintainers; [guilhermenl];
    };
  }
