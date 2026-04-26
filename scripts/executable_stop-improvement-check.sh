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
lines_counter="/tmp/claude-lines-${session_id}"
lint_marker="/tmp/claude-lint-${session_id}"

changed_lines=$(cat "$lines_counter" 2>/dev/null || echo 0)

if [ -f "$marker" ]; then
    archive_dir="$HOME/.claude/tasks"
    mkdir -p "$archive_dir"
    cp "$marker" "$archive_dir/session-improvements-$(date +%Y%m%d-%H%M%S).md"
    rm -f "$marker" "$approval_log" "$lines_counter" "$lint_marker"
    exit 0
fi

# Skip trivial single-turn sessions
if [ -n "$transcript_path" ] && [ -f "$transcript_path" ]; then
    turn_count=$(grep -c '"role":"user"' "$transcript_path" 2>/dev/null || echo 0)
    if [ "${turn_count:-0}" -lt 2 ]; then
        exit 0
    fi
fi

# Investigation sessions (< 10 lines changed) → skip regardless of approval log
if [ "${changed_lines}" -lt 10 ]; then
    rm -f "$lines_counter"
    exit 0
fi

# Large implementation sessions (≥ 50 lines) → force improvement check always
force_check=0
if [ "${changed_lines}" -ge 50 ]; then
    force_check=1
fi

# Build lint warning section: implementation changes without lint run is suspicious.
lint_section=""
if [ ! -f "$lint_marker" ]; then
    # No lint detected this session.
    if [ "${changed_lines}" -ge 10 ]; then
        lint_section="
━━ ⚠ lint / formatter 未実行 ━━
このセッションで ${changed_lines} 行の変更が記録されていますが、
cargo clippy / cargo fmt --check / ruff / eslint / mypy / pyright / 等の
lint 系コマンドの実行ログがありません。
完了前に必ず lint と formatter を実行し、その出力を timeline に貼ってください。
"
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
else
    if [ "$force_check" -eq 0 ] && [ -z "$lint_section" ]; then
        # No approvals, not a large implementation, lint OK → skip
        archive_dir="$HOME/.claude/tasks"
        mkdir -p "$archive_dir"
        echo "改善なし（このセッションで allow リスト外のツール使用なし）" > \
            "$archive_dir/session-improvements-$(date +%Y%m%d-%H%M%S).md"
        rm -f "$approval_log" "$lines_counter" "$lint_marker"
        exit 0
    fi
    approval_section="
━━ 承認ログなし（すべて allow 対象）━━
"
fi

cat >&2 <<MSG
【セッション改善チェック】終了前に以下を実行してください。
変更行数: ${changed_lines}行
${lint_section}${approval_section}
実行すべきこと:

1. 【allow リスト更新】上記のうち安全に自動承認できるパターンを
   ~/.local/share/chezmoi/dot_claude/settings.json の permissions.allow に追記し
   chezmoi apply を実行する（~/.claude/ の直接編集は禁止）。
   追加前にユーザーへ「副作用 / 追加理由 / 拒否時の代替」を必ず先出しする。

2. 【ユーザー指摘の棚卸し】このセッションでユーザーから受けた指摘・修正・
   「やめて」「違う」「やり直し」「勝手に」等のフィードバックを箇条書きで
   列挙し、それぞれの改善先（Hook / Allow / Skill / Rule / 別途調査）を決める。
   「改善なし」「追加不要」で流すのは指摘がゼロの場合のみ。指摘があったのに
   改善先を決めずに済ますのは禁止。

3. 上記の実施内容を以下に書いて作業を終了:
   $marker

   フォーマット:
     - allow リスト追記の有無と内容
     - ユーザー指摘の列挙（または「指摘なし」）
     - 各指摘の改善先（hook 化、ルール追記、調査タスク化、等）
MSG
exit 2
