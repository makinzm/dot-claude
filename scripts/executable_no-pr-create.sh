#!/bin/bash
# PreToolUse hook: forbid `gh pr create` (and equivalents).
#
# Why: Opening pull requests against shared / upstream repositories is a
# high-blast-radius action that affects other people's projects. The user
# wants to review the branch and submit the PR by hand. Claude must hand
# off the branch + commit messages, not pull the trigger.
#
# Scope: blocks any `gh pr create ...` invocation, regardless of `--repo`.
# Reading and inspecting PRs (`gh pr view`, `gh pr list`, `gh pr diff`,
# `gh pr checks`) remains allowed because they have no side effects.
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Strip quoted segments so a literal "gh pr create" inside a string (e.g.
# in a commit message or comment body) does not trigger the rule.
stripped=$(printf '%s' "$command" | python3 -c '
import re, sys
s = sys.stdin.read()
s = re.sub(r"\x27[^\x27]*\x27", "", s)
s = re.sub(r"\"[^\"]*\"", "", s)
sys.stdout.write(s)
' 2>/dev/null || printf '%s' "$command")

# Match `gh pr create` with any flags. Allow leading whitespace and other
# wrappers like `time gh pr create`.
if printf '%s' "$stripped" | grep -qE '(^|[[:space:]])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
    cat <<EOF >&2
[no-pr-create] \`gh pr create\` is forbidden by policy.

Why: opening a pull request against a shared / upstream repository is a
high-blast-radius action that affects other people's projects. The human
reviews the branch and submits the PR; Claude does not pull that trigger.

How to hand off:
- Push the branch to the user's fork (this is fine).
- Summarize the commits, the diff, and the suggested PR title / body.
- Let the user run \`gh pr create\` (or open it via the GitHub UI) themselves.

If a one-off case truly requires Claude to open a PR, the user will lift
this hook for that specific session.

Offending command:
$command
EOF
    exit 2
fi

exit 0
