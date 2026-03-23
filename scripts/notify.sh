#!/usr/bin/env bash

TITLE="$1"
MESSAGE="$2"

OS="$(uname -s 2>/dev/null)"

if [[ "$OS" == "Darwin" ]]; then
    if command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "$TITLE" -message "$MESSAGE" -sound default
    else
        /usr/bin/osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\" sound name \"Glass\""
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command -v notify-send &> /dev/null; then
        notify-send "$TITLE" "$MESSAGE" --hint=string:sound-name:complete
    else
        echo "notify-send not found. Install with: sudo apt install libnotify-bin" >&2
        exit 1
    fi
else
    echo "Unsupported OS: $OS" >&2
    exit 1
fi
