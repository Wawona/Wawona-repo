#!/bin/bash

# Wawona Repository Setup Script
# Supports: iOS (NewTerm/Terminal) and Android (Termux)

set -e

echo "[*] Wawona Repository Setup"

# Detect OS
OS_TYPE=$(uname -o 2>/dev/null || echo "Unknown")
IS_ANDROID=false
if [ "$OS_TYPE" = "Android" ]; then
    IS_ANDROID=true
fi

# Determine Prefix and Source Path
if [ "$IS_ANDROID" = true ]; then
    echo "[+] Detected Android (Termux)"
    REPO_URL="https://repo.wawona.io/android"
    SOURCE_FILE="$PREFIX/etc/apt/sources.list.d/wawona.list"
else
    echo "[+] Detected iOS/Darwin"
    REPO_URL="https://repo.wawona.io"
    # iOS typically uses /etc/apt/sources.list.d/ or similar
    # We check if we are rootless or rootful
    if [ -d "/var/jb/etc/apt" ]; then
        SOURCE_FILE="/var/jb/etc/apt/sources.list.d/wawona.list"
    else
        SOURCE_FILE="/etc/apt/sources.list.d/wawona.list"
    fi
fi

echo "[+] Adding source: $REPO_URL"

# Create sources.list.d entry
if [ "$IS_ANDROID" = true ]; then
    echo "deb $REPO_URL stable main" > "$SOURCE_FILE"
else
    # iOS might need sudo if not root
    if [ "$(id -u)" -ne 0 ]; then
        echo "deb $REPO_URL stable main" | sudo tee "$SOURCE_FILE" > /dev/null
    else
        echo "deb $REPO_URL stable main" > "$SOURCE_FILE"
    fi
fi

echo "[+] Repository added successfully!"
echo "[*] Running apt update..."

if [ "$IS_ANDROID" = true ]; then
    apt update
else
    if [ "$(id -u)" -ne 0 ]; then
        sudo apt update
    else
        apt update
    fi
fi

echo "[!] Done! You can now install Wawona packages using 'apt install <pkg>'"
