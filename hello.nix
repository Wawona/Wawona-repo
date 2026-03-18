
{ pkgs, fetchurl }:

pkgs.stdenv.mkDerivation {
  name = "hello";
  pname = "hello";
  version = "2.10";

  src = fetchurl {
    url = "http://ftpmirror.gnu.org/gnu/hello/hello-2.10.tar.gz";
    sha256 = "0ssi1wpaf7plaswqqjwigppsg5fyh99vdlb9kzl7c9lng89ndq1i";
  };
}
