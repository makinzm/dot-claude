#!/bin/bash
# Stop hook: enforce post-session improvement reflection before allowing Claude to stop.
# Exits 2 (blocks stop) until Claude writes an improvement marker file.
set -euo pipefail

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "default"')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

marker="/tmp/claude-improvements-${session_id}.md"

if [ -f "$marker" ]; then
    archive_dir="$HOME/.claude/tasks"
    mkdir -p "$archive_dir"
    cp "$marker" "$archive_dir/session-improvements-$(date +%Y%m%d-%H%M%S).md"
    rm -f "$marker"
    exit 0
fi

# Skip trivial single-turn sessions
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    turn_count=$(grep -c '"role":"user"' "$transcript_path" 2>/dev/null || echo 0)
    if [ "${turn_count:-0}" -lt 2 ]; then
        exit 0
    fi
fi

cat >&2 <<MSG
【セッション改善チェック】作業を終える前に以下のファイルを作成してください:

  $marker

記述内容:
1. コンテキスト最適化: 不要なコンテキスト消費・承認要求があれば次回への改善策
2. プロンプト改善: ユーザーの訂正・好み・やり直し指示から学んだこと（tasks/lessons.md にも転記）
3. 改善点がない場合は「改善はない」の1行だけ

ファイル作成後、作業を終了してください。
MSG
exit 2
