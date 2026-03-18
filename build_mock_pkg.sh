#!/usr/bin/env bash
set -e
T=$(mktemp -d)
P="$T/pkg"
mkdir -p "$P/var/jb/usr/bin" "$P/DEBIAN"
echo -e "#!/bin/sh\necho 'Hello, Wawona World!'" > "$P/var/jb/usr/bin/hello"
chmod +x "$P/var/jb/usr/bin/hello"
cat > "$P/DEBIAN/control" <<EOF
Package: com.aspauldingcode.hello
Name: Hello
Version: 0.1.0
Architecture: iphoneos-arm64
Description: Rootless Hello
Maintainer: aspauldingcode
Author: aspauldingcode
Section: Utilities
EOF
dpkg-deb -b "$P" "./debs/hello_0.1.0_iphoneos-arm64.deb"
rm -rf "$T"
