
{ pkgs, fetchurl, buildPackages }:

pkgs.stdenv.mkDerivation {
  name = "apr";
  version = "1.7.0";
  src = fetchurl {
    url = "https://archive.apache.org/dist/apr/apr-1.7.0.tar.gz";
    sha256 = "18nmqbj9bl6fgjbw1hfbzagh8qvxrxngp7r5j6scgzg3bbsdpsa8";
  };
  buildInputs = [ buildPackages.clang ];
  postConfigure = ''
    sed -i 's|#error Can not determine the proper size for pid_t|typedef int apr_pid_t;|g' include/apr.h
    sed -i 's|struct iovec|/*struct iovec|g' include/apr_want.h
    sed -i 's|};|};*/|g' include/apr_want.h
    sed -i 's|msg = strerror_r(statcode, buf, bufsize);|strerror_r(statcode, buf, bufsize); msg = buf;|g' misc/unix/errorcodes.c
  '';
}
