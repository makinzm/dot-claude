#!/usr/bin/env bash

TITLE="$1"
MESSAGE="$2"

if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    if command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound Glass
    else
        osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"Glass\""
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux (Ubuntu)
    if command -v notify-send &> /dev/null; then
        notify-send "$TITLE" "$MESSAGE"
    else
        echo "notify-send not found. Install with: sudo apt install libnotify-bin" >&2
        exit 1
    fi
else
    echo "Unsupported OS: $OSTYPE" >&2
    exit 1
fi
EOF
