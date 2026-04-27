#!/bin/bash
# PreToolUse hook for Write/Edit: enforce TDD (failing test before implementation)
#
# Logic:
#   - Tracks test runs per session via /tmp/claude-tdd-<session_id>
#   - If writing to an implementation file with no test run since last UserPromptSubmit → block
#   - loop-detection.sh marks the test-ran file when test commands are detected
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
session_id=$(echo "$input" | jq -r '.session_id // "default"')

# Only enforce on Write, Edit, and apply_patch (Codex uses apply_patch for file edits)
if [ "$tool_name" != "Write" ] && [ "$tool_name" != "Edit" ] && [ "$tool_name" != "apply_patch" ]; then
    exit 0
fi

# Accumulate changed-lines counter for stop-improvement-check
lines_counter="/tmp/claude-lines-${session_id}"
if [ "$tool_name" = "Write" ]; then
    new_lines=$(echo "$input" | jq -r '.tool_input.content // ""' | wc -l | tr -d ' ')
elif [ "$tool_name" = "Edit" ]; then
    new_lines=$(echo "$input" | jq -r '.tool_input.new_string // ""' | wc -l | tr -d ' ')
else
    new_lines=0
fi
current=$(cat "$lines_counter" 2>/dev/null || echo 0)
echo $((current + new_lines)) > "$lines_counter"

# Determine target file path
if [ "$tool_name" = "apply_patch" ]; then
    # Extract first modified file path from patch headers (+++ b/path)
    patch_cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
    file_path=$(echo "$patch_cmd" | grep -m1 '^\+\+\+ b/' | sed 's|^+++ b/||')
else
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
fi
if [ -z "$file_path" ]; then
    exit 0
fi

# Skip non-implementation files (config, docs, scripts, data, etc.)
if ! echo "$file_path" | grep -qiE '\.(rs|py|ts|tsx|js|jsx|go|java|kt|swift|rb|cs|cpp|cc|c|h|hpp)$'; then
    exit 0
fi

# Skip test files themselves — TDD requires writing tests first, not blocking them
if echo "$file_path" | grep -qiE '(_test\.|\.test\.|_spec\.|\.spec\.|/tests/|/test/|/__tests__/|^test_)'; then
    exit 0
fi

# Check if a test was run since the last UserPromptSubmit
test_marker="/tmp/claude-tdd-${session_id}"
if [ -f "$test_marker" ]; then
    # Tests have been run — TDD cycle started, allow implementation
    exit 0
fi

# No test ran yet: block and enforce TDD
cat >&2 <<MSG
TDDガード: テストなしで実装ファイル($file_path)への書き込みを検出しました。

テストファーストの手順:
  1. テストファイルを先に作成・編集する
  2. テストを実行して「失敗」を確認する（RED）
  3. その後で実装ファイルを書く（GREEN）

テストを実行するまでこの書き込みはブロックされます。
MSG
exit 2
