#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/scripts/launch-agent.sh"
BIN_DIR="$DIR/bin"
LOG_DIR="$HOME/Library/Logs/MT7612U-ZeroCD"

if ! launchctl print "$LAUNCH_DOMAIN" >/dev/null; then
    echo "Run the installer from your logged-in macOS desktop account without sudo." >&2
    exit 1
fi

echo "==> Building zerocd-daemon..."
mkdir -p "$BIN_DIR"
swiftc -O "$DIR/Sources/main.swift" -o "$BIN_DIR/zerocd-daemon"

echo "==> Preparing LaunchAgent and log paths..."
mkdir -p "$LAUNCH_AGENTS_DIR" "$LOG_DIR"
staged_plist=$(mktemp "$LAUNCH_AGENTS_DIR/.$LABEL.XXXXXX")
trap 'rm -f "$staged_plist"' EXIT
cp "$DIR/$PLIST_NAME" "$staged_plist"
plutil -insert StandardOutPath -string "$LOG_DIR/zerocd-daemon.log" "$staged_plist"
plutil -insert StandardErrorPath -string "$LOG_DIR/zerocd-daemon.err" "$staged_plist"
plutil -lint "$staged_plist" >/dev/null

echo "==> Installing binary to $TARGET_BIN..."
sudo mkdir -p "$(dirname "$TARGET_BIN")"
sudo install -m 0755 "$BIN_DIR/zerocd-daemon" "$TARGET_BIN"

echo "==> Registering with launchd..."
stop_launch_agent
mv -f "$staged_plist" "$TARGET_PLIST"
launchctl bootstrap "$LAUNCH_DOMAIN" "$TARGET_PLIST"

echo "LaunchAgent registered."
printf 'Log file: %s\n' "$LOG_DIR/zerocd-daemon.log"
