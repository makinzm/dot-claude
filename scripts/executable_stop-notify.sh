#!/usr/bin/env bash
# Stop hook: notify only when the session is truly finished.
# Claude Code's Stop event also fires while background subagents are still
# running (main turn ended, work continues in background) — in that case
# `background_tasks` is non-empty and no human action is actually needed yet,
# so skip the sound/notification to avoid noise during multi-agent runs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
pending=$(echo "$input" | jq '(.background_tasks // []) | length' 2>/dev/null || echo 0)

if [[ "$pending" -gt 0 ]]; then
    exit 0
fi

bash "$SCRIPT_DIR/notify.sh" 'Claude Code' '作業が完了しました。' stop
