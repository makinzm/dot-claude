#!/bin/bash
# PreToolUse hook: play sound only when a tool is NOT in the allow list.
# Also logs the event for Stop hook session analysis.
# Exit 0 always — never blocks tool execution.
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
session_id=$(echo "$input" | jq -r '.session_id // "default"')

settings="$HOME/.claude/settings.json"
[ -f "$settings" ] || exit 0

# --- Allow list check (jq string match, no bash glob complexity) ---

check_bash_allowed() {
    local cmd="$1"
    # Match against any "Bash(prefix *)" or "Bash(exact)" entry, supporting
    # multi-word prefixes like "Bash(gcloud secrets versions access *)".
    while IFS= read -r entry; do
        # Strip "Bash(" prefix and ")" suffix to get the inner pattern
        local pattern="${entry#Bash(}"
        pattern="${pattern%)}"
        if [[ "$pattern" == *" *" ]]; then
            local prefix="${pattern% \*}"
            if [ "$cmd" = "$prefix" ] || [[ "$cmd" == "$prefix "* ]]; then
                return 0
            fi
        else
            if [ "$cmd" = "$pattern" ]; then
                return 0
            fi
        fi
    done < <(jq -r '.permissions.allow[] | select(startswith("Bash("))' "$settings" 2>/dev/null)
    return 1
}

check_tool_allowed() {
    local tool="$1"
    case "$tool" in
        Read|Write|Edit|Glob|Grep)
            # These have broad patterns like Read(/**) — just check prefix
            jq -e --arg t "$tool" \
               '[.permissions.allow[] | select(startswith($t + "("))] | length > 0' \
               "$settings" > /dev/null 2>&1
            ;;
        *)
            # Exact tool name match (Agent, WebSearch, TaskCreate, etc.)
            jq -e --arg t "$tool" \
               '[.permissions.allow[] | select(. == $t)] | length > 0' \
               "$settings" > /dev/null 2>&1
            ;;
    esac
}

# --- Per-tool check ---

case "$tool_name" in
    Bash)
        cmd=$(echo "$input" | jq -r '.tool_input.command // ""')
        check_bash_allowed "$cmd" && exit 0
        check="Bash(${cmd})"
        ;;
    Read|Write|Edit|Glob|Grep)
        check_tool_allowed "$tool_name" && exit 0
        path=$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.pattern // .tool_input.path // ""')
        check="${tool_name}(${path})"
        ;;
    *)
        check_tool_allowed "$tool_name" && exit 0
        check="$tool_name"
        ;;
esac

# Not in allow list → approval will be required → log and play sound
approval_log="/tmp/claude-approvals-${session_id}.log"
echo "$(date +%H:%M:%S) | ${check}" >> "$approval_log"
bash "$HOME/.claude/scripts/play-sound.sh" notify
exit 0
