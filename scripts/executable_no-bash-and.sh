#!/bin/bash
# PreToolUse hook: forbid '&&' in Bash commands.
#
# Why: Even when individual commands are allow-listed, joining them with `&&`
# creates a compound command that no longer matches the allow patterns,
# triggering avoidable approval prompts. Splitting into separate Bash tool
# calls (parallel or sequential) keeps things smooth.
#
# Exceptions: a command may legitimately want a literal `&&` inside a quoted
# string (e.g. `git commit -m "fix: x && y"`). We attempt to ignore `&&` that
# appears inside single or double-quoted strings.
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // ""')

# Strip single-quoted and double-quoted segments before checking, so `&&` inside
# strings doesn't trigger the rule.
stripped=$(printf '%s' "$command" | python3 -c '
import re, sys
s = sys.stdin.read()
# Remove single-quoted segments
s = re.sub(r"\x27[^\x27]*\x27", "", s)
# Remove double-quoted segments (best effort, no escaping support)
s = re.sub(r"\"[^\"]*\"", "", s)
sys.stdout.write(s)
' 2>/dev/null || printf '%s' "$command")

if printf '%s' "$stripped" | grep -qE '&&'; then
    cat <<EOF >&2
[no-bash-and] Bash command contains '&&'. Compound commands are forbidden by policy.

Why: allow-listed individual commands stop matching once joined with '&&', so
this triggers an avoidable approval prompt.

How to fix:
- Split into separate Bash tool calls (parallel within one message if independent,
  sequential across messages if dependent).
- For a single semantic operation that genuinely needs '&&', ask the user to
  add a more specific allow pattern.

Offending command:
$command
EOF
    exit 2
fi

exit 0
