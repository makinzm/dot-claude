#!/usr/bin/env bash
# Stop hook: make it mechanically clear -- not just via Claude's prose --
# whether other agents/background tasks are still running when this turn
# tries to end.
#
# Two things confirmed empirically in this exact session (both matter, see
# CLAUDE.md "Stop フック" table / feedback_explicit_completion_status.md):
#   1. Plain stdout on exit 0 is NOT shown to the user for Stop.
#   2. `exit 2` + stderr ("hook feedback") reaches the MODEL reliably, but
#      the user reported seeing *nothing at all* when this hook blocked --
#      so stderr/hook-feedback text is a Claude-facing signal, not a
#      user-facing one. The one channel independently confirmed to reach
#      the user is a real OS notification (notify.sh / play-sound.sh,
#      already used by stop-notify.sh for the completion sound).
#
# So this hook now does both: fire a real OS banner+sound via notify.sh
# (user-facing, independent of anything Claude says), AND still exit 2 so
# the model is forced to also mention it in its own chat reply (the one
# other channel actually confirmed visible to the user all session: the
# model's own text). `stop_hook_active` guards against re-notifying/
# re-blocking forever on the same still-pending background task within one
# stop attempt.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
stop_hook_active=$(echo "$input" | jq -r '.stop_hook_active // false' 2>/dev/null || echo false)
tasks_json=$(echo "$input" | jq -c '(.background_tasks // [])' 2>/dev/null || echo '[]')
count=$(echo "$tasks_json" | jq 'length' 2>/dev/null || echo 0)

if [ "$count" -gt 0 ] && [ "$stop_hook_active" != "true" ]; then
    lines=$(echo "$tasks_json" | jq -r '.[] | "  - [" + .type + "/" + (.status // "?") + "] " + (.description // .name // .id // "?")')
    bash "$SCRIPT_DIR/notify.sh" 'Claude Code' "⏳ バックグラウンドで ${count} 件が進行中です" notify || true
    cat >&2 <<EOF
【Agentステータス】⏳ バックグラウンドで ${count} 件が進行中です:
${lines}

これらが終わるまでこの応答は完了していません。終わり次第 Stop が再評価されます。
EOF
    exit 2
fi

exit 0
