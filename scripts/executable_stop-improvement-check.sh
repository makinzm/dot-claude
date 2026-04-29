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
    # Validate marker against the required template (CLAUDE.md「改善報告の決定論的フォーマット」).
    # Skip validation if it's a "no improvement needed" session
    # (= no `### 改善 #N:` header at all).
    if grep -qE '^### 改善 #[0-9]+:' "$marker"; then
        entry_count=$(grep -cE '^### 改善 #[0-9]+:' "$marker")
        required_fields=(
            '指摘 / 動機'
            '改善の種類'
            '改善先（場所）'
            'その場所を選んだ理由'
            '実装内容'
            '永続化'
        )
        missing=""
        for field in "${required_fields[@]}"; do
            field_count=$( (grep -F -- "- **${field}**:" "$marker" 2>/dev/null || true) | wc -l | tr -d ' ' )
            field_count=${field_count:-0}
            if [ "${field_count}" -lt "$entry_count" ]; then
                missing="${missing}
  - ${field} (見つかった: ${field_count}, 期待: ${entry_count})"
            fi
        done
        if [ -n "$missing" ]; then
            cat >&2 <<EOF
【マーカー検証エラー】
$marker の各「### 改善 #N:」ブロックで必須フィールドが不足しています:${missing}

CLAUDE.md「改善報告の決定論的フォーマット」のテンプレに従って、各改善ブロックに
以下 6 フィールドを必ず含めてください:
$(printf -- '  - %s\n' "${required_fields[@]}")

マーカーを修正してから再度終了してください。
EOF
            exit 2
        fi
    fi

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

# Check for uncommitted/unpushed changes in dot_claude submodule
dot_claude_section=""
dot_claude_dir="$HOME/.local/share/chezmoi/dot_claude"
if [ -d "$dot_claude_dir/.git" ] || [ -f "$dot_claude_dir/.git" ]; then
    dirty=""
    if [ -n "$(git -C "$dot_claude_dir" status --porcelain 2>/dev/null)" ]; then
        dirty="未コミットの変更があります"
    fi
    unpushed=""
    local_head=$(git -C "$dot_claude_dir" rev-parse HEAD 2>/dev/null || true)
    remote_head=$(git -C "$dot_claude_dir" rev-parse origin/main 2>/dev/null || true)
    if [ -n "$local_head" ] && [ -n "$remote_head" ] && [ "$local_head" != "$remote_head" ]; then
        unpushed="未 push のコミットがあります"
    fi
    # Also check parent repo for submodule ref update
    parent_dirty=""
    parent_dir="$HOME/.local/share/chezmoi"
    if [ -n "$(git -C "$parent_dir" diff --name-only -- dot_claude 2>/dev/null)" ]; then
        parent_dirty="親リポジトリで dot_claude のサブモジュール参照が未コミットです"
    fi
    if [ -n "$dirty" ] || [ -n "$unpushed" ] || [ -n "$parent_dirty" ]; then
        dot_claude_section="
━━ ⚠ dot_claude 未永続化 ━━"
        [ -n "$dirty" ] && dot_claude_section="${dot_claude_section}
  - ${dirty}"
        [ -n "$unpushed" ] && dot_claude_section="${dot_claude_section}
  - ${unpushed}"
        [ -n "$parent_dirty" ] && dot_claude_section="${dot_claude_section}
  - ${parent_dirty}"
        dot_claude_section="${dot_claude_section}
dot_claude 内で commit → push し、親リポジトリでも dot_claude を add → commit → push してください。
"
    fi
fi

cat >&2 <<MSG
【セッション改善チェック】終了前に以下を実行してください。
変更行数: ${changed_lines}行
${lint_section}${dot_claude_section}${approval_section}
実行すべきこと:

1. 【allow リスト更新】上記のうち安全に自動承認できるパターンを
   ~/.local/share/chezmoi/dot_claude/settings.json の permissions.allow に追記し
   chezmoi apply を実行する（~/.claude/ の直接編集は禁止）。
   追加前にユーザーへ「副作用 / 追加理由 / 拒否時の代替」を必ず先出しする。

2. 【ユーザー指摘の棚卸し】このセッションでユーザーから受けた指摘・修正・
   「やめて」「違う」「やり直し」「勝手に」等のフィードバックを列挙し、
   それぞれを **以下のテンプレ（CLAUDE.md「改善報告の決定論的フォーマット」と
   同一）** で書く。「指摘なし」で流すのは指摘がゼロの場合のみ。

   ━━ 改善 1 件あたりのテンプレ（必須 6 フィールド）━━
   ### 改善 #N: <1 行サマリ>

   - **指摘 / 動機**: <ユーザー指摘の引用 or 発見した課題の 1 文>
   - **改善の種類**: Hook / Allow / Skill / Rule / 別途調査
   - **改善先（場所）**: <絶対パス or リポジトリ相対パス。複数なら箇条書き>
   - **その場所を選んだ理由**: <Hook > Allow > Skill > Rule の優先順位に照らした 1〜2 文>
   - **実装内容**: <1〜3 行の要点>
   - **永続化**: <commit hash / push 済 / chezmoi apply 済 / 未反映>

   このテンプレは Stop hook 内で正規表現により検証される。
   各「### 改善 #N:」ヘッダーに対して 6 フィールド全てが揃っていないと
   exit 2 で書き直しを要求される。

3. 上記の内容（allow 追記の有無 + 改善列挙 or「指摘なし」）を以下に書いて
   作業を終了:
   $marker
MSG
exit 2
