#!/usr/bin/env bash
set -e

# Path setup
SCRIPT_DIR=$(dirname "$(realpath "$0")")
ROOT=$(dirname "$SCRIPT_DIR")
REPO_ROOT="$ROOT" # Use repo root for Sileo compatibility
SUITE="stable"
IOS_ROOT="$REPO_ROOT/ios"
ANDROID_ROOT="$REPO_ROOT/android"
ARCH_IOS_64="iphoneos-arm64"
ARCH_IOS_64E="iphoneos-arm64e"
ARCH_ANDROID="aarch64"

# Helpers
get_size() { stat -c %s "$1" 2>/dev/null || stat -f %z "$1"; }
sed_i() { if sed --version 2>/dev/null | grep -q "GNU"; then sed -i "$@"; else sed -i '' "$@"; fi; }

# RootHide Patching
patch_roothide() {
    local input="$1"
    local out_dir="$2"
    local filename=$(basename "$input")
    if [[ "$filename" == *"~roothide"* ]]; then return 0; fi
    local pkg_name="${filename%%_*}"
    local pkg_ver=$(echo "$filename" | cut -d'_' -f2)
    local output_filename="${pkg_name}_${pkg_ver}~roothide_iphoneos-arm64e.deb"
    local output_path="$out_dir/$output_filename"
    if [ -f "$output_path" ]; then return 0; fi
    echo "Patching $filename for RootHide..."
    local tmp=$(mktemp -d)
    dpkg-deb -R "$input" "$tmp"
    sed_i "s/^Architecture: .*/Architecture: $ARCH_IOS_64E/" "$tmp/DEBIAN/control"
    sed_i "s/^Version: .*/Version: ${pkg_ver}~roothide/" "$tmp/DEBIAN/control"
    if ! grep -q "RootHide:" "$tmp/DEBIAN/control"; then echo "RootHide: true" >> "$tmp/DEBIAN/control"; fi
    if ! grep -q "Tag:" "$tmp/DEBIAN/control"; then echo "Tag: role::tweak, roothide::compatible" >> "$tmp/DEBIAN/control"; fi
    dpkg-deb -b "$tmp" "$output_path" > /dev/null
    rm -rf "$tmp"
}

update_dist() {
    local p_root="$1"
    local p_name="$2"
    local p_archs="$3"
    local p_rel="${p_root#$REPO_ROOT/}" # Relative path from root
    echo "Updating $p_name index..."
    
    cd "$REPO_ROOT"
    mkdir -p "$p_root/dists/$SUITE/main/"
    for arch in $p_archs; do mkdir -p "$p_root/dists/$SUITE/main/binary-$arch"; done
    
    # Scan debs from root to get correct relative paths
    dpkg-scanpackages -m "$p_rel/debs" /dev/null 2>/dev/null > "$p_root/Packages"
    sed_i 's/^Roothide: /RootHide: /g' "$p_root/Packages"
    gzip --no-name -c9 "$p_root/Packages" > "$p_root/Packages.gz"
    
    # Spread to arch dirs
    for arch in $p_archs; do
        cp "$p_root/Packages" "$p_root/dists/$SUITE/main/binary-$arch/Packages"
        gzip --no-name -c9 "$p_root/Packages" > "$p_root/dists/$SUITE/main/binary-$arch/Packages.gz"
    done
    
    # Release file
    cat > "$p_root/Release" <<EOF
Origin: Wawona
Label: Wawona ($p_name)
Suite: $SUITE
Codename: $SUITE
Architectures: $p_archs
Components: main
Description: Wawona System Utilities for $p_name
Date: $(date -R)
MD5Sum:
 $(md5sum "$p_root/Packages" | cut -d' ' -f1) $(get_size "$p_root/Packages") Packages
 $(md5sum "$p_root/Packages.gz" | cut -d' ' -f1) $(get_size "$p_root/Packages.gz") Packages.gz
EOF
}

echo "Step 1: Building multi-platform aggregate..."
# Run nix build and create links
nix build .#ios --out-link "$ROOT/result-ios" --no-link
nix build .#android --out-link "$ROOT/result-android" --no-link

echo "Step 2: Collecting binaries..."
mkdir -p "$IOS_ROOT/debs" "$IOS_ROOT/roothide" "$ANDROID_ROOT/debs"
if [ -L "$ROOT/result-ios" ]; then find "$ROOT/result-ios" -name "*.deb" -exec cp -vu {} "$IOS_ROOT/debs/" \; ; fi
if [ -L "$ROOT/result-android" ]; then find "$ROOT/result-android" -name "*.deb" -exec cp -vu {} "$ANDROID_ROOT/debs/" \; ; fi

echo "Step 3: Processing iOS RootHide..."
for deb in "$IOS_ROOT/debs"/*.deb; do [ -e "$deb" ] || continue; patch_roothide "$deb" "$IOS_ROOT/roothide"; done
cp "$IOS_ROOT/roothide"/*.deb "$IOS_ROOT/debs/" 2>/dev/null || true

echo "Step 4: Generating Indices..."
update_dist "$IOS_ROOT" "iOS" "$ARCH_IOS_64 $ARCH_IOS_64E"
update_dist "$ANDROID_ROOT" "Android" "$ARCH_ANDROID"

echo "Step 5: Sileo Root Compatibility..."
# Copy iOS indices to top root for Sileo expectations at repo.wawona.io/
cp "$IOS_ROOT/Packages" "$REPO_ROOT/Packages"
cp "$IOS_ROOT/Packages.gz" "$REPO_ROOT/Packages.gz"
cp "$IOS_ROOT/Release" "$REPO_ROOT/Release"
cp "$IOS_ROOT/Release" "$REPO_ROOT/Releases"

# Clean up legacy repo directory if it exists
if [ -d "$ROOT/repo" ]; then rm -rf "$ROOT/repo" ; fi

cd "$ROOT"
if [ -d ".git" ]; then git add repo/ ; fi
echo "Wawona Repository Updated Successfully."
