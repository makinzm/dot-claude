#!/usr/bin/env bash

TITLE="$1"
MESSAGE="$2"

OS="$(uname -s 2>/dev/null)"

if [[ "$OS" == "Darwin" ]]; then
    # macOS: afplayで直接サウンド再生（tmux/devbox内でも確実に鳴る）
    /usr/bin/afplay /System/Library/Sounds/Glass.aiff &

    # 通知表示（サウンドはafplayが担当するので-soundは不要）
    if command -v terminal-notifier &> /dev/null; then
        terminal-notifier -title "$TITLE" -message "$MESSAGE"
    else
        /usr/bin/osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""
    fi
elif [[ "$OS" == "Linux" ]]; then
    if command -v notify-send &> /dev/null; then
        notify-send "$TITLE" "$MESSAGE"
    else
        echo "notify-send not found. Install with: sudo apt install libnotify-bin" >&2
        exit 1
    fi
else
    echo "Unsupported OS: $OS" >&2
    exit 1
fi
