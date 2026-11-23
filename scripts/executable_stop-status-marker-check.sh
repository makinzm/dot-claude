#!/usr/bin/env bash
# Stop hook: require the final response of every turn to open with a
# one-line status marker (状態: 完了/進行中/確認待ち/失敗) so the user can
# tell at a glance whether the turn is finished, still running, waiting on
# them, or failed -- without reading through the details first.
#
# A Rule-only version of this (CLAUDE.md "状態マーカーの明示") was not
# followed reliably across sessions, so this enforces it mechanically
# instead, matching the existing improvement-marker pattern in
# stop-improvement-check.sh.
set -euo pipefail

input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    exit 0
fi

# Bound the read for cost; the final message is always near the tail.
last_text=$(tail -n 2000 "$transcript_path" | jq -s -r '
    [ .[] | select(.type == "assistant") | select([.message.content[]?.type] | index("text")) ]
    | last
    | (.message.content // [])[]
    | select(.type == "text")
    | .text
' 2>/dev/null || true)

# Nothing to check (e.g. the turn ended without a final text message).
if [ -z "$last_text" ]; then
    exit 0
fi

if echo "$last_text" | grep -qE '^状態:.*(完了|進行中|確認待ち|失敗)'; then
    exit 0
fi

cat >&2 <<'EOF'
【状態マーカー不足】
最終応答の先頭行に状態マーカーがありません。CLAUDE.md「状態マーカーの明示」に従い、
以下いずれかを応答の最初の行に追加してから終了してください:

  状態: ✅完了       -- このターンの依頼に対応しきった
  状態: 🔄進行中     -- 作業は継続中(バックグラウンドAgent実行中・複数ステップの途中など)
  状態: ⏸️確認待ち   -- ユーザーの判断・承認を待っている
  状態: ❌失敗       -- エラー・ブロックで完了できなかった
EOF
exit 2
