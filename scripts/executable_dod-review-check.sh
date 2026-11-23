#!/usr/bin/env bash
# Stop hook: block completion if a deliverable (.md file written/edited
# this session, outside this factory's own infra paths) exists but not
# every currently-defined dod-* review Agent (agents/dod-*.md) was
# actually dispatched (Agent tool, subagent_type: dod-<id>) against it.
#
# Why this exists: "1 DoD item = 1 Skill + 1 Agent" (sync-dod-skills.py)
# only guaranteed the Agents/Skills *exist* in sync with
# dod/deliverables-dod.json -- nothing forced them to actually run before
# a deliverable was reported done. A user asking "does everything in this
# repo actually get reviewed by those, and where is that enforced?"
# surfaced that nothing did. This hook makes running every dod-* Agent on
# touched deliverables mechanically required, not just documented in
# CLAUDE.md's DoD section.
#
# Re-checks the transcript on every Stop attempt (no stop_hook_active
# bypass, same design as stop-improvement-check.sh) so it keeps blocking
# across however many retries it takes until the missing Agents are
# actually dispatched and show up in the transcript.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

input=$(cat)
transcript_path=$(echo "$input" | jq -r '.transcript_path // ""')

if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then
    exit 0
fi

# Deliverable files = .md files written/edited this session, excluding
# this factory's own infra paths (agent/skill/DoD-definition plumbing,
# session scratch dirs, and the Stop-hook improvement marker file written
# by stop-improvement-check.sh), which are governed by separate existing
# checks.
deliverable_files=$(grep -oE '"name":"(Write|Edit)","input":\{"file_path":"[^"]*\.md"' "$transcript_path" 2>/dev/null \
    | sed -E 's/.*"file_path":"([^"]*)"/\1/' \
    | grep -v -E '/\.claude/|/chezmoi/dot_claude/|/tasks/|/dod/|^/tmp/claude-improvements-' \
    | sort -u || true)

if [ -z "$deliverable_files" ]; then
    exit 0
fi

agents_dir="$HOME/.claude/agents"
required_agents=$(ls "$agents_dir" 2>/dev/null | grep -E '^dod-.*\.md$' | sed -E 's/\.md$//' | sort -u || true)

if [ -z "$required_agents" ]; then
    exit 0
fi

invoked_agents=$(grep -oE '"subagent_type":"dod-[A-Za-z0-9_-]*"' "$transcript_path" 2>/dev/null \
    | sed -E 's/.*"subagent_type":"([^"]*)"/\1/' \
    | sort -u || true)

missing=$(comm -23 <(echo "$required_agents") <(echo "$invoked_agents") 2>/dev/null | grep -v '^$' || true)

if [ -z "$missing" ]; then
    exit 0
fi

missing_count=$(echo "$missing" | wc -l | tr -d ' ')
file_lines=$(echo "$deliverable_files" | sed 's/^/  - /')
missing_lines=$(echo "$missing" | sed 's/^/  - /')

bash "$SCRIPT_DIR/notify.sh" 'Claude Code' "⚠ DoDレビューAgent未実行 (${missing_count}件)" notify || true

cat >&2 <<EOF
【DoDレビュー未実行】このセッションで以下の成果物(.md)が書き込まれましたが、
現在定義されている dod-* Agent のうち一部がまだ一度も起動されていません:

━━ 書き込まれた成果物 ━━
${file_lines}

━━ 未起動の dod-* Agent ━━
${missing_lines}

完了を報告する前に、上記それぞれを Agent ツールで
subagent_type: "dod-<id>" として個別に起動し、PASS/FAILを確認してください
(CLAUDE.md「成果物のDoD」節)。起動済みでもこのチェックは毎回再評価されるので、
Agentが実際に transcript に記録されるまでこのブロックは解除されません。
EOF
exit 2
