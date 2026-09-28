#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
BIN_DIR="$DIR/bin"
PLIST_NAME="com.user.zerocd-daemon.plist"
TARGET_BIN="/usr/local/bin/zerocd-daemon"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
TARGET_PLIST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo "==> Building zerocd-daemon binary..."
mkdir -p "$BIN_DIR"
swiftc -O "$DIR/Sources/main.swift" -o "$BIN_DIR/zerocd-daemon"

echo "==> Installing binary to /usr/local/bin..."
sudo mkdir -p /usr/local/bin
sudo cp "$BIN_DIR/zerocd-daemon" "$TARGET_BIN"
sudo chmod +x "$TARGET_BIN"

echo "==> Installing LaunchAgent to $TARGET_PLIST..."
mkdir -p "$LAUNCH_AGENTS_DIR"
cp "$DIR/$PLIST_NAME" "$TARGET_PLIST"

echo "==> Registering with launchd..."
launchctl unload "$TARGET_PLIST" 2>/dev/null || true
launchctl load "$TARGET_PLIST"

echo "✅ Installed and started successfully!"
echo "Check logs with: tail -f /tmp/zerocd-daemon.log"
