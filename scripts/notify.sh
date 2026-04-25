#!/usr/bin/env bash
# Show a system notification and optionally play a sound.
# Usage: notify.sh <title> <message> [event_type]
#   event_type: "stop" (default) | "notify"

TITLE="$1"
MESSAGE="$2"
EVENT="${3:-notify}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS="$(uname -s 2>/dev/null)"

# Show notification
if [[ "$OS" == "Darwin" ]]; then
    if command -v terminal-notifier &>/dev/null; then
        terminal-notifier -title "$TITLE" -message "$MESSAGE" &>/dev/null &
    else
        /usr/bin/osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" &>/dev/null || true
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command -v notify-send &>/dev/null; then
        notify-send "$TITLE" "$MESSAGE" &>/dev/null || true
    fi
fi

# Play sound (respects CLAUDE_SOUND env var)
bash "$SCRIPT_DIR/play-sound.sh" "$EVENT" 2>/dev/null || true
