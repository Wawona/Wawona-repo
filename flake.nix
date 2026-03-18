
{
  description = "A simple flake for building hello";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      pkgs = nixpkgs.legacyPackages.aarch64-darwin;
    in {
      packages.aarch64-darwin.hello = pkgs.stdenv.mkDerivation {
        name = "hello";
        version = "2.10";
        src = pkgs.fetchurl {
          url = "http://ftpmirror.gnu.org/gnu/hello/hello-2.10.tar.gz";
          sha256 = "sha256-MeBmE3qWJnbon2nRtlOC3pWn732RS4y5VvQepy4PUWs=";
        };
      };
      packages.aarch64-darwin.bash = pkgs.stdenv.mkDerivation {
        name = "bash";
        version = "5.2.15";
        buildInputs = [ pkgs.ncurses ];
        src = pkgs.fetchurl {
          url = "https://ftpmirror.gnu.org/bash/bash-5.2.15.tar.gz";
          sha256 = "132qng0jy600mv1fs95ylnlisx2wavkkgpb19c6kmz7lnmjhjwhk";
        };
      };

      packages.aarch64-darwin.xorg-server = import ./xorg-server.nix { inherit pkgs; };

      defaultPackage.aarch64-darwin = self.packages.aarch64-darwin.hello;
    };
}
