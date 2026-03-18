#!/usr/bin/env bash
set -e

ROOT=$(dirname "$(realpath "$0")")
ARCH_64="iphoneos-arm64"
ARCH_64E="iphoneos-arm64e"
SUITE="stable"

# Path setup
DEBS_DIR="$ROOT/debs"
ROOTHIDE_DIR="$ROOT/roothide"
DISTS_DIR="$ROOT/dists/$SUITE/main"
ARCH_DIR_64="$DISTS_DIR/binary-$ARCH_64"
ARCH_DIR_64E="$DISTS_DIR/binary-$ARCH_64E"

mkdir -p "$ROOTHIDE_DIR" "$ARCH_DIR_64" "$ARCH_DIR_64E"

# Detect OS
OS="$(uname)"

# Function to get file size portably
get_size() {
    if stat --version 2>/dev/null | grep -q "GNU"; then
        stat -c %s "$1"
    else
        stat -f %z "$1"
    fi
}

# Function for portable sed -i
sed_i() {
    if sed --version 2>/dev/null | grep -q "GNU"; then
        sed -i "$@"
    else
        sed -i '' "$@"
    fi
}

# Function to patch for RootHide
patch_roothide() {
    local input="$1"
    local out_dir="$2"
    local filename=$(basename "$input")
    local pkg_name="${filename%%_*}"
    local pkg_ver=$(echo "$filename" | cut -d'_' -f2)
    
    local output_filename="${pkg_name}_${pkg_ver}~roothide_iphoneos-arm64e.deb"
    local output_path="$out_dir/$output_filename"
    
    if [ -f "$output_path" ]; then
        return 0
    fi
    
    echo "Patching $filename for RootHide..."
    local tmp=$(mktemp -d)
    dpkg-deb -R "$input" "$tmp"
    sed_i "s/^Architecture: .*/Architecture: $ARCH_64E/" "$tmp/DEBIAN/control"
    sed_i "s/^Version: .*/Version: ${pkg_ver}~roothide/" "$tmp/DEBIAN/control"
    if ! grep -q "RootHide:" "$tmp/DEBIAN/control"; then
        echo "RootHide: true" >> "$tmp/DEBIAN/control"
    fi
    if ! grep -q "Tag:" "$tmp/DEBIAN/control"; then
        echo "Tag: role::tweak, roothide::compatible" >> "$tmp/DEBIAN/control"
    else
        sed_i "s/^Tag: .*/&, roothide::compatible/" "$tmp/DEBIAN/control"
    fi
    dpkg-deb -b "$tmp" "$output_path" > /dev/null
    rm -rf "$tmp"
}

# 1. Patch debs
for deb in "$DEBS_DIR"/*.deb; do
    [ -e "$deb" ] || continue
    patch_roothide "$deb" "$ROOTHIDE_DIR"
done

# 2. Update repository indices
cd "$ROOT"

# Generate individual indices for dists
echo "Generating architecture-specific indices..."
dpkg-scanpackages -m ./debs /dev/null 2>/dev/null > Packages.arm64
dpkg-scanpackages -m ./roothide /dev/null 2>/dev/null > Packages.arm64e

# Unified Index (Root)
echo "Generating unified index..."
cp Packages.arm64 Packages
cat Packages.arm64e >> Packages
# Fix case-sensitivity and tagging
sed_i 's/^Roothide: /RootHide: /g' Packages
gzip --no-name -c9 Packages > Packages.gz

# 3. Standard Release metadata
cat > Release <<EOF
Origin: Wawona
Label: Wawona
Suite: $SUITE
Version: 1.0
Codename: $SUITE
Architectures: $ARCH_64 $ARCH_64E
Components: main
Description: Wawona System Utilities
MD5Sum:
 $(md5sum Packages | cut -d' ' -f1) $(get_size Packages) Packages
 $(md5sum Packages.gz | cut -d' ' -f1) $(get_size Packages.gz) Packages.gz
SHA1:
 $(sha1sum Packages | cut -d' ' -f1) $(get_size Packages) Packages
 $(sha1sum Packages.gz | cut -d' ' -f1) $(get_size Packages.gz) Packages.gz
SHA256:
 $(sha256sum Packages | cut -d' ' -f1) $(get_size Packages) Packages
 $(sha256sum Packages.gz | cut -d' ' -f1) $(get_size Packages.gz) Packages.gz
EOF

# 4. Update dists structure
cp Packages.arm64 "$ARCH_DIR_64/Packages"
gzip --no-name -c9 Packages.arm64 > "$ARCH_DIR_64/Packages.gz"

cp Packages.arm64e "$ARCH_DIR_64E/Packages"
sed_i 's/^Roothide: /RootHide: /g' "$ARCH_DIR_64E/Packages"
gzip --no-name -c9 "$ARCH_DIR_64E/Packages" > "$ARCH_DIR_64E/Packages.gz"

# Dist Release
cat > "$DISTS_DIR/../Release" <<EOF
Origin: Wawona
Label: Wawona
Suite: $SUITE
Version: 1.0
Codename: $SUITE
Architectures: $ARCH_64 $ARCH_64E
Components: main
Description: Wawona System Utilities
MD5Sum:
 $(md5sum "$ARCH_DIR_64/Packages" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64/Packages") main/binary-$ARCH_64/Packages
 $(md5sum "$ARCH_DIR_64/Packages.gz" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64/Packages.gz") main/binary-$ARCH_64/Packages.gz
 $(md5sum "$ARCH_DIR_64E/Packages" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64E/Packages") main/binary-$ARCH_64E/Packages
 $(md5sum "$ARCH_DIR_64E/Packages.gz" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64E/Packages.gz") main/binary-$ARCH_64E/Packages.gz
SHA1:
 $(sha1sum "$ARCH_DIR_64/Packages" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64/Packages") main/binary-$ARCH_64/Packages
 $(sha1sum "$ARCH_DIR_64/Packages.gz" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64/Packages.gz") main/binary-$ARCH_64/Packages.gz
 $(sha1sum "$ARCH_DIR_64E/Packages" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64E/Packages") main/binary-$ARCH_64E/Packages
 $(sha1sum "$ARCH_DIR_64E/Packages.gz" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64E/Packages.gz") main/binary-$ARCH_64E/Packages.gz
SHA256:
 $(sha256sum "$ARCH_DIR_64/Packages" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64/Packages") main/binary-$ARCH_64/Packages
 $(sha256sum "$ARCH_DIR_64/Packages.gz" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64/Packages.gz") main/binary-$ARCH_64/Packages.gz
 $(sha256sum "$ARCH_DIR_64E/Packages" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64E/Packages") main/binary-$ARCH_64E/Packages
 $(sha256sum "$ARCH_DIR_64E/Packages.gz" | cut -d' ' -f1) $(get_size "$ARCH_DIR_64E/Packages.gz") main/binary-$ARCH_64E/Packages.gz
EOF

# 5. Sync to Git Index
if [ -d .git ]; then
    echo "Updating Git index..."
    git add Packages Packages.gz Release releases roothide/*.deb dists/ .nojekyll
    echo "Git index synchronized successfully."
fi

echo "Repository updated successfully with unified indexing and stable suite."


