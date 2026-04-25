#!/bin/bash
# PreToolUse hook: play sound when a tool is not in the allow list (approval needed).
# Runs silently (exit 0 always) — never blocks tool execution.
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

# Build a check string that mirrors the allow-list pattern format
case "$tool_name" in
    Bash)
        cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
        check="Bash(${cmd})"
        ;;
    Read|Write|Edit)
        path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
        check="${tool_name}(${path})"
        ;;
    Glob|Grep)
        path=$(echo "$input" | jq -r '.tool_input.pattern // .tool_input.path // ""')
        check="${tool_name}(${path})"
        ;;
    *)
        check="$tool_name"
        ;;
esac

# Check against allow list in settings.json (glob-style matching via bash case)
settings="$HOME/.claude/settings.json"
[ -f "$settings" ] || exit 0

while IFS= read -r pattern; do
    # shellcheck disable=SC2254
    case "$check" in
        $pattern) exit 0 ;;  # Matched → auto-approved, no sound needed
    esac
done < <(jq -r '.permissions.allow[]' "$settings" 2>/dev/null)

# Not matched by any allow pattern → user approval will be required → play sound
bash "$HOME/.claude/scripts/play-sound.sh" notify
exit 0
