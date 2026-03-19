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
echo "[+] Target file: $SOURCE_FILE"

# Prepare the source line
LINE="deb $REPO_URL stable main"

# Ensure directory exists and handle the file
if [ "$IS_ANDROID" = true ]; then
    mkdir -p "$(dirname "$SOURCE_FILE")"
    if [ -f "$SOURCE_FILE" ] && grep -qxF "$LINE" "$SOURCE_FILE"; then
        echo "[!] Repository already exists in $SOURCE_FILE"
    else
        echo "$LINE" >> "$SOURCE_FILE"
        echo "[+] Repository added to $SOURCE_FILE"
    fi
else
    # iOS - handle sudo
    DIR=$(dirname "$SOURCE_FILE")
    if [ "$(id -u)" -ne 0 ]; then
        sudo mkdir -p "$DIR"
        if [ -f "$SOURCE_FILE" ] && grep -qxF "$LINE" "$SOURCE_FILE"; then
            echo "[!] Repository already exists in $SOURCE_FILE"
        else
            echo "$LINE" | sudo tee -a "$SOURCE_FILE" > /dev/null
            echo "[+] Repository added to $SOURCE_FILE"
        fi
    else
        mkdir -p "$DIR"
        if [ -f "$SOURCE_FILE" ] && grep -qxF "$LINE" "$SOURCE_FILE"; then
            echo "[!] Repository already exists in $SOURCE_FILE"
        else
            echo "$LINE" >> "$SOURCE_FILE"
            echo "[+] Repository added to $SOURCE_FILE"
        fi
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
