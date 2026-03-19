
{ pkgs, fetchurl, buildPackages, mainPkgs }:

pkgs.stdenv.mkDerivation {
  name = "zsign";
  pname = "zsign";
  version = "0~20220120.27016df";

  src = mainPkgs.fetchFromGitHub {
    owner = "zhlynn";
    repo = "zsign";
    rev = "27016df";
    sha256 = "sha256-DXUJ9WfRK/n+iSXOz6sly6bdZOXGzlyPj0B3pfrlX+8=";
  };

  buildInputs = [ buildPackages.clang mainPkgs.openssl ];

  buildPhase = ''
    CXX="${buildPackages.clang}/bin/clang++"
    CXXFLAGS="-O2 -I${mainPkgs.openssl.dev}/include"
    LDFLAGS="-L${mainPkgs.openssl}/lib"
    $CXX $CXXFLAGS \
      *.cpp \
      common/*.cpp \
      $LDFLAGS \
      -lcrypto \
      -o zsign
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp zsign $out/bin
  '';
}
