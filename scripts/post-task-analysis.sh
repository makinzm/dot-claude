#!/bin/bash
# Stop hook (async): analyze completed session and suggest context/approval optimizations
set -euo pipefail

input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    exit 0
fi

# Count tool calls from transcript
total_tools=$(grep -c '"type":"tool_use"' "$transcript_path" 2>/dev/null || echo 0)
bash_calls=$(grep -o '"name":"Bash"' "$transcript_path" 2>/dev/null | wc -l | tr -d ' ')
read_calls=$(grep -o '"name":"Read"' "$transcript_path" 2>/dev/null | wc -l | tr -d ' ')

# Skip tiny sessions
if [ "${total_tools:-0}" -lt 5 ]; then
    exit 0
fi

suggestions=()

# Bash call ratio: if many bash calls, suggest adding frequent ones to allow list
if [ "${bash_calls:-0}" -gt 15 ]; then
    suggestions+=("Bashコマンドが${bash_calls}回実行されました。頻繁に使うコマンドは settings.json の permissions.allow に追加すると承認回数を減らせます。")
fi

# Context window: check if transcript is large (proxy for high context usage)
transcript_size=$(wc -c < "$transcript_path" 2>/dev/null || echo 0)
if [ "${transcript_size:-0}" -gt 500000 ]; then
    suggestions+=("会話が大きくなっています(${transcript_size}バイト)。次回の類似タスクは新しいセッションで始めるとコンテキスト効率が上がります。")
fi

# Write report if there are suggestions
if [ "${#suggestions[@]}" -gt 0 ]; then
    report_dir="$HOME/.claude/tasks"
    mkdir -p "$report_dir"
    report_file="$report_dir/session-analysis-$(date +%Y%m%d-%H%M%S).md"

    {
        echo "# セッション分析レポート"
        echo "日時: $(date)"
        echo "ツール呼び出し合計: ${total_tools} (Bash: ${bash_calls}, Read: ${read_calls})"
        echo ""
        echo "## 最適化の提案"
        for s in "${suggestions[@]}"; do
            echo "- $s"
        done
    } > "$report_file"

    # Notify user
    bash "$HOME/.claude/scripts/notify.sh" "Claude Code 分析" "セッション分析レポートを保存しました: $report_file" 2>/dev/null || true
fi
