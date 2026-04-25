#!/bin/bash
# UserPromptSubmit hook: estimate task difficulty and manage state
set -euo pipefail

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "default"')
prompt=$(echo "$input" | jq -r '.prompt // ""')

# Reset loop counter and TDD marker on new user input
rm -f "/tmp/claude-loop-${session_id}" "/tmp/claude-loop-${session_id}-cmds" "/tmp/claude-tdd-${session_id}" 2>/dev/null

word_count=$(echo "$prompt" | wc -w | tr -d ' ')

# Heuristics for architectural/complex keywords
has_arch=$(echo "$prompt" | grep -ciE \
  "アーキテクチャ|設計|リファクタ|リファクタリング|システム|architecture|refactor|design|migrate|migration" \
  2>/dev/null || echo 0)
has_multi=$(echo "$prompt" | grep -ciE \
  "複数.*ファイル|multiple.*file|全体|entire|全部|すべて" \
  2>/dev/null || echo 0)
has_new_system=$(echo "$prompt" | grep -ciE \
  "新しく|新規|作って|作成して|ゼロから|from scratch|implement.*new|新しいシステム" \
  2>/dev/null || echo 0)

arch_score=$(( has_arch + has_multi + has_new_system ))

if [ "$word_count" -lt 20 ] && [ "$arch_score" -eq 0 ]; then
    difficulty="S"
elif [ "$word_count" -lt 80 ] && [ "$arch_score" -le 1 ]; then
    difficulty="M"
elif [ "$word_count" -lt 250 ] && [ "$arch_score" -le 2 ]; then
    difficulty="L"
else
    difficulty="XL"
fi

# No output for S/M — avoid adding noise for small tasks
if [ "$difficulty" = "S" ] || [ "$difficulty" = "M" ]; then
    exit 0
fi

task_dir="$HOME/.claude/tasks/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$task_dir"

cat > "$task_dir/state.md" <<STATEOF
# Task State
Started: $(date -Iseconds)
Difficulty: $difficulty
Status: in_progress

## Prompt
${prompt}
STATEOF

if [ "$difficulty" = "XL" ]; then
    cat <<MSG
[難易度自動推定: XL]
このタスクは非常に大規模です。メインコンテキストの汚染を防ぐため、Agent toolでサブエージェント（tdd-pr-workflow や architect など）に委譲することを強く推奨します。
状態ファイル: ${task_dir}/state.md
MSG
else
    cat <<MSG
[難易度自動推定: L]
このタスクは大規模です。tasks/ に状態ファイルを作成しました: ${task_dir}/state.md
大きな変更の前に計画を立て、必要に応じてサブエージェントへの委譲を検討してください。
MSG
fi
