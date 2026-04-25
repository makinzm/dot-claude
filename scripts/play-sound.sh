#!/usr/bin/env bash
# Play a notification sound, controlled by env vars.
#
# Usage: play-sound.sh [event_type]
#   event_type: "stop" (default) | "notify"
#
# Env vars:
#   CLAUDE_SOUND=1               master switch (1=on, 0=off). Default: 1
#   CLAUDE_SOUND_STOP_NAME=Glass sound name for task completion (Mac system sound name)
#   CLAUDE_SOUND_NOTIFY_NAME=Ping sound name for approval/notification events
#
# Mac system sounds: Glass Ping Purr Tink Hero Sosumi Basso Blow Bottle Frog
# Located at: /System/Library/Sounds/<Name>.aiff

EVENT="${1:-stop}"

# Master switch: default ON
if [[ "${CLAUDE_SOUND:-1}" == "0" ]]; then
    exit 0
fi

# Debounce: skip if a sound was played within the last 2 seconds
# (prevents double-play when both Stop and Notification hooks fire together)
LOCK_FILE="/tmp/claude-sound-lock"
now=$(date +%s)
last=$(cat "$LOCK_FILE" 2>/dev/null || echo 0)
if (( now - last < 2 )); then
    exit 0
fi
echo "$now" > "$LOCK_FILE"

OS="$(uname -s 2>/dev/null)"

play_mac() {
    local name="$1"
    local sound_file="/System/Library/Sounds/${name}.aiff"
    if [[ -f "$sound_file" ]]; then
        afplay "$sound_file" &>/dev/null &
    else
        # Fallback: treat as full path
        afplay "$name" &>/dev/null & 2>/dev/null || true
    fi
}

play_linux() {
    local name="$1"
    if [[ -f "$name" ]]; then
        # Full path given
        if command -v paplay &>/dev/null; then
            paplay "$name" &>/dev/null & 2>/dev/null || true
        elif command -v aplay &>/dev/null; then
            aplay "$name" &>/dev/null & 2>/dev/null || true
        fi
    else
        # Try common Ubuntu sound paths
        local candidates=(
            "/usr/share/sounds/freedesktop/stereo/complete.oga"
            "/usr/share/sounds/ubuntu/stereo/desktop-login.ogg"
            "/usr/share/sounds/ubuntu/stereo/message.ogg"
        )
        for f in "${candidates[@]}"; do
            if [[ -f "$f" ]]; then
                if command -v paplay &>/dev/null; then
                    paplay "$f" &>/dev/null & 2>/dev/null || true
                elif command -v aplay &>/dev/null; then
                    aplay "$f" &>/dev/null & 2>/dev/null || true
                fi
                return
            fi
        done
    fi
}

case "$EVENT" in
    stop)
        sound_name="${CLAUDE_SOUND_STOP_NAME:-Glass}"
        ;;
    notify)
        sound_name="${CLAUDE_SOUND_NOTIFY_NAME:-Ping}"
        ;;
    *)
        sound_name="${CLAUDE_SOUND_STOP_NAME:-Glass}"
        ;;
esac

if [[ "$OS" == "Darwin" ]]; then
    play_mac "$sound_name"
elif [[ "$OS" == "Linux" ]]; then
    play_linux "$sound_name"
fi
