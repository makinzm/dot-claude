#!/usr/bin/env bash
# Stop hook: make it mechanically clear -- not just via Claude's prose --
# whether other agents/background tasks are still running when this turn
# tries to end. Plain stdout on exit 0 is NOT shown to the user for the
# Stop event (confirmed empirically: an earlier version of this script did
# exactly that and nothing appeared). `exit 2` + stderr IS the confirmed
# visible channel for Stop (same mechanism stop-improvement-check.sh uses,
# observed working every turn this session). `stop_hook_active` guards
# against blocking forever on the same still-pending background task.
set -euo pipefail

input=$(cat)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
tasks_json=$(echo "$input" | jq -c '(.background_tasks // [])' 2>/dev/null || echo '[]')
count=$(echo "$tasks_json" | jq 'length' 2>/dev/null || echo 0)

if [ "$count" -gt 0 ] && [ "$stop_hook_active" != "true" ]; then
    lines=$(echo "$tasks_json" | jq -r '.[] | "  - [" + .type + "/" + (.status // "?") + "] " + (.description // .name // .id // "?")')
    cat >&2 <<EOF
【Agentステータス】⏳ バックグラウンドで ${count} 件が進行中です:
${lines}

これらが終わるまでこの応答は完了していません。終わり次第 Stop が再評価されます。
EOF
    exit 2
fi

exit 0
