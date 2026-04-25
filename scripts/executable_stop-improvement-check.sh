#!/bin/bash
# Stop hook: enforce post-session improvement reflection.
# Exits 2 (blocks stop) until Claude writes an improvement marker file.
# The marker must include: allow-list additions, context improvements, approval analysis.
set -euo pipefail

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "default"')
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

marker="/tmp/claude-improvements-${session_id}.md"
approval_log="/tmp/claude-approvals-${session_id}.log"

if [ -f "$marker" ]; then
    # Archive to runtime tasks dir (not chezmoi source)
    archive_dir="$HOME/.claude/tasks"
    mkdir -p "$archive_dir"
    cp "$marker" "$archive_dir/session-improvements-$(date +%Y%m%d-%H%M%S).md"
    rm -f "$marker" "$approval_log"
    exit 0
fi

# Skip trivial single-turn sessions
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    turn_count=$(grep -c '"role":"user"' "$transcript_path" 2>/dev/null || echo 0)
    if [ "${turn_count:-0}" -lt 2 ]; then
        exit 0
    fi
fi

# Build approval section from log
approval_section=""
if [ -f "$approval_log" ] && [ -s "$approval_log" ]; then
    approval_count=$(wc -l < "$approval_log" | tr -d ' ')
    approval_section="
━━ 承認が必要だったツール (${approval_count}件) ━━
$(cat "$approval_log")
"
fi

cat >&2 <<MSG
【セッション改善チェック】終了前に以下を実行してください。
${approval_section}
実行すべきこと:

1. 【allow リスト更新】承認ログのうち安全に自動承認できるパターンを
   ~/.local/share/chezmoi/dot_claude/settings.json の permissions.allow に追記し
   chezmoi apply を実行する（~/.claude/ の直接編集は禁止）

2. 【コンテキスト削減】このセッションで無駄なコンテキスト消費があれば次回への改善策

3. 上記の実施内容（または「改善はない」）を以下に書いて作業を終了:
   $marker
MSG
exit 2
