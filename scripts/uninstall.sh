#!/usr/bin/env bash
set -e

PLIST_NAME="com.user.zerocd-daemon.plist"
TARGET_BIN="/usr/local/bin/zerocd-daemon"
TARGET_PLIST="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "==> Stopping service..."
launchctl unload "$TARGET_PLIST" 2>/dev/null || true

echo "==> Removing files..."
rm -f "$TARGET_PLIST"
if [ -f "$TARGET_BIN" ]; then
    sudo rm -f "$TARGET_BIN"
fi

echo "✅ Uninstalled successfully!"
