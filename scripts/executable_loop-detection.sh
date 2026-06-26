#!/bin/bash
# PreToolUse hook: detect repetitive loops and block to ask user for direction
set -euo pipefail

input=$(cat)
session_id=$(echo "$input" | jq -r '.session_id // "default"')
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

counter_file="/tmp/claude-loop-${session_id}"

# Track all tool calls (append tool name)
echo "$tool_name" >> "$counter_file"

# For Bash specifically, track the command content for exact-match detection
if [ "$tool_name" = "Bash" ]; then
    command=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

    # Mark test runs for TDD guard
    if echo "$command" | grep -qiE \
        '(cargo test|pytest|npm test|npx jest|go test|rspec|bun test|deno test|make test|jest|vitest|mocha)'; then
        touch "/tmp/claude-tdd-${session_id}" 2>/dev/null || true
    fi

    # Mark lint / formatter runs for stop-improvement-check
    if echo "$command" | grep -qiE \
        '(cargo clippy|cargo fmt|ruff[[:space:]]+(check|format)|eslint|pyright|mypy|biome[[:space:]]+(check|lint|format)|prettier[[:space:]]+--check|golangci-lint|gofmt|tsc(\b|[[:space:]])|rubocop|stylua|shellcheck|markdownlint)'; then
        touch "/tmp/claude-lint-${session_id}" 2>/dev/null || true
    fi

    # Use first 120 chars as key to normalize slight variations
    key=$(echo "$command" | head -c 120 | tr -s '[:space:]' ' ')
    cmd_file="${counter_file}-cmds"
    echo "$key" >> "$cmd_file"

    # Check last 10 commands for repeated identical command (3+ times)
    if [ -f "$cmd_file" ]; then
        recent=$(tail -10 "$cmd_file")
        # Count how many of the last 10 match the current key exactly
        repeat_count=$(echo "$recent" | grep -cxF "$key" 2>/dev/null || echo 0)
        if [ "${repeat_count:-0}" -ge 3 ]; then
            echo "ループ検出: 同じBashコマンドが${repeat_count}回繰り返されています。" >&2
            echo "一度立ち止まって方針をユーザーに確認してください。別のアプローチを検討するか、ユーザーに現状と詰まっている点を報告してください。" >&2
            exit 2
        fi
    fi
fi

# Total tool call count guard: if >150 calls without user reset, warn
# 40 was too low for multi-step BACKLOG task sequences (TDD RED→GREEN→lint→commit etc.)
total=$(wc -l < "$counter_file" 2>/dev/null || echo 0)
if [ "${total:-0}" -ge 150 ]; then
    echo "長時間ループ検出: ユーザー入力なしに${total}回のツール呼び出しが発生しています。" >&2
    echo "作業の進捗と課題をユーザーに報告し、続行の確認を取ってください。" >&2
    # Reset counter to avoid spamming every subsequent call
    echo "" > "$counter_file"
    exit 2
fi

exit 0
