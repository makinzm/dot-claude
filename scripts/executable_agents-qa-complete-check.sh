#!/bin/bash
# PreToolUse hook for Bash: before `gh pr create` on a branch belonging to a
# repo that follows the AGENTS.md task workflow, block if that task's
# docs/tasks/<task-id>/QA.md still has unanswered questions.
#
# Why a hook instead of relying on the agent to remember to check: PR
# creation is the workflow's own "task completion" signal (AGENTS.md §3
# step 7 ends in a PR; docs/DOD.md's checklists both key off it). Checking
# deterministically here means the agent doesn't need to re-read QA.md from
# scratch every time to decide whether it's safe to open the PR, and a human
# gets told explicitly, every time, instead of relying on the agent noticing.
#
# Opt-in detection: only enforced in repos with both an AGENTS.md and a
# docs/tasks/ directory at root; a no-op everywhere else.
#
# "Unanswered" means a `- 回答:` (or `- Answer:`, for an English-language
# task) line that is empty, or marked with the "not yet collected" markers
# this convention uses (a literal "未回収", or an inline HTML comment).
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
[ "$tool_name" = "Bash" ] || exit 0

command=$(echo "$input" | jq -r '.tool_input.command // ""')
cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd=$(pwd)

stripped=$(printf '%s' "$command" | python3 -c '
import re, sys
s = sys.stdin.read()
s = re.sub(r"\x27[^\x27]*\x27", "", s)
s = re.sub(r"\"[^\"]*\"", "", s)
sys.stdout.write(s)
' 2>/dev/null || printf '%s' "$command")

if ! printf '%s' "$stripped" | grep -qE '(^|[[:space:]])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
    exit 0
fi

repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "")
[ -n "$repo_root" ] || exit 0

if [ ! -f "$repo_root/AGENTS.md" ] || [ ! -d "$repo_root/docs/tasks" ]; then
    exit 0
fi

branch=$(git -C "$repo_root" branch --show-current 2>/dev/null || echo "")
[ -n "$branch" ] || exit 0

qa_file="$repo_root/docs/tasks/$branch/QA.md"
[ -f "$qa_file" ] || exit 0

unanswered=$(grep -nE '^- *(回答|Answer): *($|<!--|（未回収）|\(not yet collected\))' "$qa_file" || true)

if [ -n "$unanswered" ]; then
    cat >&2 <<EOF
[agents-qa-complete-check] Blocked: $qa_file has unanswered questions.

AGENTS.md §4 / docs/DOD.md: every QA.md entry touched by this task needs an
answer and a decision before the task counts as done. Ask the human to fill
these in (or resolve them with the human right now) before opening the PR:

$unanswered
EOF
    exit 2
fi

exit 0
