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
      sdkVer = "15.0";  # Adjust to your target iOS version
      # Use Xcode SDK if available; Nix will leverage it for cross-compilation
    };

    # Import nixpkgs with cross-compilation overlay
    pkgs = import nixpkgs {
      system = hostSystem;
      crossSystem = targetSystem;
      overlays = [];  # Add overlays for roothide or iOS-specific patches later
    };
  in {
    # Default dev shell for building/testing
    devShells.${hostSystem}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        clang  # For iOS compilation
        # Add more tools as needed, e.g., ldid for signing
      ];
      shellHook = ''
        echo "Wawona iOS flake dev shell ready. Target: aarch64-apple-ios"
      '';
    };

    # Placeholder for packages; we'll add converted ones here
    packages.${hostSystem} = {
      # Example: hello (to be filled in next task)
      hello = pkgs.stdenv.mkDerivation rec {
        pname = "hello";
        version = "2.12";  # Matches typical Procursus GNU Hello version; adjust if needed

        src = pkgs.fetchurl {
          url = "mirror://gnu/hello/hello-\${version}.tar.gz";
          sha256 = "cf04af86dc085268c5f4470fbae49b18afbc221b78096aab842d934a76bad0ab";
        };

        # For iOS rootless/Roothide: Add patches or flags if needed (e.g., for /var/jb/ prefixing)
        # Currently none specific to hello, but we can add e.g., patches = [ ./roothide-patch.diff ];
        configureFlags = [
          "--host=aarch64-apple-ios"
          "--enable-static"  # For jailbreak compatibility
        ];

        meta = {
          description = "Wawona port of GNU Hello for iOS jailbreaks - produces a friendly greeting";
          homepage = "https://repo.wawona.io";
          maintainers = ["Wawona Team"];  # Rebranded from Procursus
          license = pkgs.lib.licenses.gpl3Plus;
        };
      };

      libiosexec = pkgs.stdenv.mkDerivation rec {
        pname = "libiosexec";
        version = "1.3.1";

        src = pkgs.fetchFromGitHub {
          owner = "roothide";
          repo = "libiosexec";
          rev = "54a0866ed9b25adf252d20b9e0366280be4e29d3";
          sha256 = "008k883yvk9kkljk62jz4v49phr0cad5ky6c4vdxazgxz0lv4vbr";
        };

        preBuild = ''
          sed -i 's/$(shell uname -s)/Darwin/g' Makefile
        '';

        installPhase = ''
          make install DESTDIR=''${out} \
            SHEBANG_REDIRECT_PATH="/var/jb" \
            LIBIOSEXEC_PREFIXED_ROOT=1 \
            DEFAULT_PATH_PREFIX="/var/jb" \
            DEFAULT_INTERPRETER="/var/jb/bin/sh"
        '';

        meta = {
          description = "libiosexec is a library for iOS that allows for shebang execution and other process-related functionality.";
          homepage = "https://github.com/roothide/libiosexec";
        };
      };

      bash = pkgs.stdenv.mkDerivation rec {
        pname = "bash";
        version = "5.2.15";

        src = pkgs.fetchurl {
          url = "mirror://gnu/bash/bash-5.2.15.tar.gz";
          sha256 = "132qng0jy600mv1fs95ylnlisx2wavkkgpb19c6kmz7lnmjhjwhk";
        };

        buildInputs = with pkgs; [ ncurses readline ];

        configureFlags = [
          "--host=aarch64-apple-ios"
          "--enable-static-link"
          "--disable-nls"
          "--without-bash-malloc"
          "--prefix=/var/jb" # Roothide compatibility
        ];

        meta = {
          description = "Wawona port of GNU Bash shell for iOS jailbreaks";
          homepage = "https://repo.wawona.io";
          license = pkgs.lib.licenses.gpl3Plus;
        };
      };

      system-cmds = pkgs.stdenv.mkDerivation rec {
        pname = "system-cmds";
        version = "950";

        src = pkgs.fetchurl {
          url = "https://github.com/apple-oss-distributions/system_cmds/archive/refs/tags/system_cmds-${version}.tar.gz";
          sha256 = "1405fs99vaaznspc1kvqmjcnz7v1gki8sz54ipdl16ajxgyabqpn";
        };

        patches = [
          ./patches/system-cmds/0001-system_cmds-shutdown-may-not-work.patch
          ./patches/system-cmds/0002-Add-missing-int-reboot3-int-declaration.patch
          ./patches/system-cmds/bettercrypt.diff
          ./patches/system-cmds/fix-pwd_mkdb-comment-handling.diff
        ];

        buildInputs = with pkgs; [ libxcrypt openpam ncurses ] ++ [ self.libiosexec ];

        preConfigure = ''
          sed -i '/#include <stdio.h>/a #include <crypt.h>' login.tproj/login.c
          sed -i '1 i\#include <libiosexec.h>' login.tproj/login.c
          sed -i '1 i\#define IOPOL_TYPE_VFS_HFS_CASE_SENSITIVITY 1\n#define IOPOL_SCOPE_PROCESS 0\n#define IOPOL_VFS_HFS_CASE_SENSITIVITY_DEFAULT 0\n#define IOPOL_VFS_HFS_CASE_SENSITIVITY_FORCE_CASE_SENSITIVE 1\n#define PRIO_DARWIN_ROLE_UI 0x2' taskpolicy.tproj/taskpolicy.c
          sed -i -E -e 's|/usr|/var/jb/usr|g' -e 's|/sbin|/var/jb/sbin|g' \
            shutdown.tproj/pathnames.h getty.tproj/{ttys,gettytab}.5 sc_usage.tproj/sc_usage.{1,c} at.tproj/{at.1,pathnames.h}
          sed -i 's|/etc|/var/jb/etc|' passwd.tproj/{file_,}passwd.c
          sed -i 's|#include <mach/i386/vm_param.h>|#include <mach/vm_param.h>|' memory_pressure.tproj/memory_pressure.c
          sed -i 's|/System/Library/Kernels/kernel.development|/var/jb/Library/Kernels/kernel.development|' latency.tproj/latency.{1,c}
        '';

        buildPhase = ''
          # Compile gperf files
          for gperf in getconf.tproj/*.gperf; do
            LC_ALL=C awk -f getconf.tproj/fake-gperf.awk < $gperf > getconf.tproj/"$(basename $gperf .gperf).c"
          done

          rm -f passwd.tproj/{od,nis}_passwd.c

          # Compile wait4path
          $CC $CFLAGS $LDFLAGS -o wait4path.x wait4path/*.c

          # Compile all the tproj projects
          for tproj in ac accton arch at atrun cpuctl dmesg dynamic_pager fs_usage getconf getty hostinfo iostat latency login lskq memory_pressure mkfile newgrp purge pwd_mkdb reboot shutdown stackshot trace passwd sync sysctl vifs vipw zdump zic nologin taskpolicy lsmp sc_usage ltop; do
            echo "Building $tproj"
            TARGET_CFLAGS=""
            TARGET_LDFLAGS=""
            case $tproj in
              arch) TARGET_LDFLAGS="-framework CoreFoundation -framework Foundation -lobjc";;
              login) TARGET_CFLAGS="-DUSE_PAM=1"; TARGET_LDFLAGS="-lpam -liosexec";;
              dynamic_pager) TARGET_CFLAGS="-Idynamic_pager.tproj";;
              pwd_mkdb) TARGET_CFLAGS="-D_PW_NAME_LEN=MAXLOGNAME -D_PW_YPTOKEN=__YP!";;
              passwd) TARGET_CFLAGS="-DINFO_PAM=4"; TARGET_LDFLAGS="-lcrypt -lpam";;
              shutdown) TARGET_LDFLAGS="-lbsm -liosexec";;
              sc_usage) TARGET_LDFLAGS="-lncurses";;
              at) TARGET_LDFLAGS="-Iat.tproj -DPERM_PATH=/var/jb/usr/lib/cron -DDAEMON_UID=1 -DDAEMON_GID=1 -D__FreeBSD__ -DDEFAULT_AT_QUEUE='a' -DDEFAULT_BATCH_QUEUE='b'";;
              fs_usage) TARGET_LDFLAGS="-Wno-error-implicit-function-declaration";; # ktrace framework is not available, maybe this is ok
              latency) TARGET_LDFLAGS="-lncurses -lutil";;
              trace) TARGET_LDFLAGS="-lutil";;
              lskq) TARGET_LDFLAGS="-Ilskq.tproj -DEVFILT_NW_CHANNEL=(-16)";;
              zic) TARGET_CFLAGS='-DUNIDEF_MOVE_LOCALTIME -DTZDIR="/var/db/timezone/zoneinfo" -DTZDEFAULT="/var/db/timezone/localtime"';;
            esac
            $CC $CFLAGS -D__kernel_ptr_semantics="" -Iinclude -o $tproj $tproj.tproj/*.c -D'__FBSDID(x)=' $TARGET_CFLAGS $LDFLAGS $TARGET_LDFLAGS -framework CoreFoundation -framework IOKit -DPRIVATE -D__APPLE_PRIVATE
          done
        '';

        installPhase = ''
          mkdir -p $out/var/jb/Library/LaunchDaemons $out/var/jb/etc/pam.d $out/var/jb/bin $out/var/jb/sbin $out/var/jb/usr/bin $out/var/jb/usr/sbin $out/var/jb/usr/libexec $out/var/jb/usr/share/man/man{1,5,8}

          sed 's|/usr|/var/jb/usr|' < atrun.tproj/com.apple.atrun.plist > $out/var/jb/Library/LaunchDaemons/com.apple.atrun.plist

          install -m755 pagesize.tproj/pagesize.sh $out/var/jb/usr/bin/pagesize
          install -m755 wait4path.x $out/var/jb/bin/wait4path

          cp -a dmesg dynamic_pager nologin reboot shutdown $out/var/jb/sbin
          cp -a sync $out/var/jb/bin

          cp -a ac accton iostat mkfile pwd_mkdb sysctl taskpolicy vifs vipw zdump zic $out/var/jb/usr/sbin
          cp -a arch at cpuctl fs_usage getconf hostinfo latency login lskq lsmp ltop memory_pressure newgrp passwd purge sc_usage stackshot trace $out/var/jb/usr/bin
          cp -a atrun getty $out/var/jb/usr/libexec

          # man pages
          cp -a {arch,at,fs_usage,getconf,latency,login,lskq,lsmp,ltop,memory_pressure,newgrp,pagesize,passwd,trace,vm_stat,zprint}.tproj/*.1 wait4path/*.1 $out/var/jb/usr/share/man/man1
          cp -a {getty,nologin,sysctl}.tproj/*.5 $out/var/jb/usr/share/man/man5
          cp -a {ac,accton,atrun,cpuctl,dmesg,dynamic_pager,getty,hostinfo,iostat,mkfile,nologin,nvram,purge,pwd_mkdb,reboot,sa,shutdown,sync,sysctl,taskpolicy,vifs,vipw,zdump,zic}.tproj/*.8 $out/var/jb/usr/share/man/man8

          ln -s $out/var/jb/usr/bin/arch $out/var/jb/usr/bin/machine
          ln -s $out/var/jb/sbin/reboot $out/var/jb/sbin/halt
        '';

        meta = {
          description = "Apple's system commands (including passwd) ported for iOS jailbreaks.";
          homepage = "https://opensource.apple.com/";
        };
      };
    };

    # For hosting on repo.wawona.io, we can generate a repo index or tarballs here
    # (e.g., via hydraJobs or custom outputs)
  };
}