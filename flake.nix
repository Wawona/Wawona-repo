{
  description = "Wawona Nix flake for iOS jailbreak packages (converted from Procursus-roothide)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: let
    # System for the build host (macOS)
    hostSystem = "aarch64-darwin";  # Adjust if you're on x86_64-darwin

    # Target system for iOS cross-compilation
    targetSystem = {
      config = "aarch64-apple-ios";
      isStatic = true;  # For static linking in jailbreak envs
      sdkVer = "15.5";  # Adjust to your target iOS version
      # Use Xcode SDK if available; Nix will leverage it for cross-compilation
    };

    # iOS package set (cross-compilation)
    pkgsIOS = import nixpkgs {
      system = hostSystem;
      crossSystem = targetSystem;
      overlays = [
        (final: prev: {
          Libc = prev.Libc.overrideAttrs (oldAttrs: {
            preConfigure = ''
              export SDKROOT=${prev.apple_sdk.sdkPath}
            '';
          });
        })
      ];
    };

    # Android package set (cross-compilation for Termux)
    pkgsAndroid = import nixpkgs {
      system = hostSystem;
      crossSystem = {
        config = "aarch64-unknown-linux-android";
        androidSdkVersion = "33";
      };
    };

    # Native pkgs for host tools (dpkg, etc)
    nativePkgs = import nixpkgs {
      system = hostSystem;
    };

    # Modular package sets
    iosPackages = import ./pkgs/top-level.nix { 
      inherit self nativePkgs;
      pkgs = pkgsIOS;
      target = "ios";
    };

    androidPackages = import ./pkgs/top-level.nix {
      inherit self nativePkgs;
      pkgs = pkgsAndroid;
      target = "android";
    };
  in {
    # Default dev shell for building/testing
    devShells.${hostSystem}.default = nativePkgs.mkShell {
      buildInputs = with nativePkgs; [
        clang
        dpkg
        gnused
        coreutils
      ];
      shellHook = ''
        echo "Wawona Multi-Platform Flake. Targets: iOS (Rootless/Roothide), Android (Termux)"
      '';
    };

    packages.${hostSystem} = {
      # Platform bundles
      ios = iosPackages.all;
      android = androidPackages.all;

      # Individual access
      ios-pkgs = iosPackages;
      android-pkgs = androidPackages;

      # Default to ios hello for legacy convenience
      hello = iosPackages.hello;
    };

    apps.${hostSystem} = {
      update = {
        type = "app";
        program = "${nativePkgs.writeShellScript "update-repo" ''
          export PATH="${nativePkgs.lib.makeBinPath (with nativePkgs; [ dpkg gnused coreutils gnugrep findutils ])}:$PATH"
          ./scripts/update.sh
        ''}";
      };
    };
  };
}