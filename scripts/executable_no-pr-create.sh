#!/bin/bash
# PreToolUse hook: block `gh pr create` against repos NOT owned by the user.
#
# Why: Opening a pull request against someone else's repository is a
# high-blast-radius action that affects another project. The user reviews
# and submits those PRs by hand. PRs against the user's own repos
# (e.g. forks owned by ALLOWED_OWNER) are fine and stay allowed.
#
# Decision: extract the target owner from `--repo OWNER/REPO`. If absent,
# fall back to the `origin` remote of the current working directory. If the
# owner equals ALLOWED_OWNER, allow; otherwise block. Unknown owner ->
# block (fail-closed).
#
# Read-only PR commands (`gh pr view`, `gh pr list`, `gh pr diff`,
# `gh pr checks`) remain allowed.
set -euo pipefail

ALLOWED_OWNER="makinzm"

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')
if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // ""')
cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd=$(pwd)

# Strip quoted segments so a literal `gh pr create` inside a string (commit
# message body, etc.) does not trigger the rule.
stripped=$(printf '%s' "$command" | python3 -c '
import re, sys
s = sys.stdin.read()
s = re.sub(r"\x27[^\x27]*\x27", "", s)
s = re.sub(r"\"[^\"]*\"", "", s)
sys.stdout.write(s)
' 2>/dev/null || printf '%s' "$command")

# Detect `gh pr create` with arbitrary leading whitespace / wrappers.
if ! printf '%s' "$stripped" | grep -qE '(^|[[:space:]])gh[[:space:]]+pr[[:space:]]+create([[:space:]]|$)'; then
    exit 0
fi

# Extract --repo OWNER/REPO if explicitly passed (supports space or `=`).
target_owner=""
if printf '%s' "$stripped" | grep -qE -- '--repo([[:space:]]|=)'; then
    target_owner=$(
        printf '%s' "$stripped" \
        | sed -nE 's/.*--repo[[:space:]=]+([^[:space:]]+).*/\1/p' \
        | sed -nE 's@^([^/]+)/.*@\1@p'
    )
fi

# Fall back to the origin remote of the current repo.
origin_url=""
if [ -z "$target_owner" ]; then
    origin_url=$(git -C "$cwd" remote get-url origin 2>/dev/null || true)
    if [ -n "$origin_url" ]; then
        target_owner=$(
            printf '%s' "$origin_url" \
            | sed -nE 's@^(git@github\.com:|ssh://git@github\.com/|https://github\.com/)([^/]+)/.*$@\2@p'
        )
    fi
fi

if [ "$target_owner" = "$ALLOWED_OWNER" ]; then
    exit 0
fi

display_owner="${target_owner:-<unknown>}"
cat <<EOF >&2
[no-pr-create] gh pr create blocked: target owner is "${display_owner}",
not the allowed owner "${ALLOWED_OWNER}".

Why: opening a PR against someone else's repository is a high-blast-radius
action. The user reviews and submits those PRs by hand. Forks owned by
${ALLOWED_OWNER} are allowed automatically.

How to recover:
- If you intended to PR your own fork, pass \`--repo ${ALLOWED_OWNER}/<repo>\`
  explicitly, or run from a clone whose \`origin\` is owned by ${ALLOWED_OWNER}.
- For an upstream PR, hand off the branch (push + commit summary + PR
  draft body) to the user. Do not open the PR yourself.

Offending command:
$command
EOF
exit 2
