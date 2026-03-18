
{ pkgs, fetchurl, buildPackages, mainPkgs }:

pkgs.stdenv.mkDerivation {
  name = "zip";
  pname = "zip";
  version = "3.0";

  src = fetchurl {
    url = "https://deb.debian.org/debian/pool/main/z/zip/zip_3.0.orig.tar.gz";
    sha256 = "sha256-8Oi7H5t+sLAShUlaJpnfOkt2Z4TBdlqPGu7fY8CAY2k=";
  };

  buildInputs = [ buildPackages.clang mainPkgs.bzip2 ];

  makeFlags = [ "-f" "unix/Makefile" "generic" "LFLAGS2=-lbz2" "CFLAGS=-I. -DUNIX -DBZIP2_SUPPORT -Wno-deprecated-non-prototype" ];

  installPhase = ''
    make -f unix/Makefile install prefix=$out
  '';
}
