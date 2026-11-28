# Shared paths and lifecycle commands for install.sh and uninstall.sh.
LABEL="com.user.zerocd-daemon"
PLIST_NAME="$LABEL.plist"
TARGET_BIN="/usr/local/bin/zerocd-daemon"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
TARGET_PLIST="$LAUNCH_AGENTS_DIR/$PLIST_NAME"
LAUNCH_DOMAIN="gui/$(id -u)"
SERVICE_TARGET="$LAUNCH_DOMAIN/$LABEL"

stop_launch_agent() {
    local output status
    if output=$(launchctl print "$SERVICE_TARGET" 2>&1); then
        launchctl bootout "$SERVICE_TARGET"
    else
        status=$?
        # launchctl returns 113 when the job is missing. Check that its domain exists.
        if [ "$status" -eq 113 ]; then
            launchctl print "$LAUNCH_DOMAIN" >/dev/null
        else
            printf '%s\n' "$output" >&2
            return "$status"
        fi
    fi
}
