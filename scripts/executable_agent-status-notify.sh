#!/usr/bin/env bash
# Stop hook: make it mechanically clear -- not just via Claude's prose --
# whether this turn is fully done or other agents/background tasks are
# still running. Uses the Stop event's own `background_tasks` field
# (confirmed real: executable_stop-notify.sh in this repo already reads
# it), so this does not depend on any subagent-tracking state file.
set -euo pipefail

input=$(cat)
tasks_json=$(echo "$input" | jq -c '(.background_tasks // [])' 2>/dev/null || echo '[]')
count=$(echo "$tasks_json" | jq 'length' 2>/dev/null || echo 0)

if [ "$count" -gt 0 ]; then
    lines=$(echo "$tasks_json" | jq -r '.[] | "  - [" + .type + "/" + (.status // "?") + "] " + (.description // .name // .id // "?")')
    echo "[Agentステータス] ⏳ 作業中: バックグラウンドで ${count} 件が進行中"
    echo "${lines}"
else
    echo "[Agentステータス] ✅ 完了: バックグラウンドで進行中のタスクはなし"
fi
