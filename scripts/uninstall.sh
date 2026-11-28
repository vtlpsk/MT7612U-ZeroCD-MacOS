#!/usr/bin/env bash
set -e

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$DIR/scripts/launch-agent.sh"

echo "==> Stopping service..."
stop_launch_agent

echo "==> Removing files..."
rm -f "$TARGET_PLIST"
if [ -f "$TARGET_BIN" ]; then
    sudo rm -f "$TARGET_BIN"
fi

echo "Uninstalled successfully."
