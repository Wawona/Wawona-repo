{
  description = "Wawona Repo Flake";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        deps = with pkgs; [ dpkg gzip coreutils gnused bash perl git ];
        path = pkgs.lib.makeBinPath deps;
      in {
        packages.update = pkgs.writeShellScriptBin "update-repo" "export PATH=${path}:$PATH; bash ./update.sh";
        packages.serve = pkgs.writeShellScriptBin "serve-repo" "${pkgs.python3}/bin/python3 -m http.server 8080";
        devShells.default = pkgs.mkShell { buildInputs = deps ++ [ pkgs.python3 ]; };
      }
    );
}
