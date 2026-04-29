#!/bin/bash
# PreToolUse hook: block access to .env files (read, write, edit, bash cat/head/tail).
#
# Why: .env files contain secrets (API keys, passwords, tokens). Claude should
# never read or display their contents, even accidentally.
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

# Check file path for Read/Edit/Write tools
case "$tool_name" in
    Read|Edit|Write)
        file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""')
        basename=$(basename "$file_path" 2>/dev/null || true)
        # Match .env, .env.local, .env.production, etc.
        # Allow .env.example and .env.sample (templates without secrets)
        if [[ "$basename" =~ ^\.env\.(example|sample|template)$ ]]; then
            exit 0
        fi
        if [[ "$basename" =~ ^\.env($|\.) ]]; then
            cat <<EOF >&2
[no-env-read] ${tool_name} blocked: "${file_path}" is a .env file.

Why: .env files contain secrets (API keys, passwords, tokens).
Claude should never read or modify these files.

If you need to know the variable names (not values), ask the user
to provide them or check .env.example instead.
EOF
            exit 2
        fi
        ;;
    Bash)
        command=$(echo "$input" | jq -r '.tool_input.command // ""')
        # Strip quoted strings so ".env" in commit messages / echo args won't trigger
        stripped=$(printf '%s' "$command" | python3 -c '
import re, sys
s = sys.stdin.read()
s = re.sub(r"\x27[^\x27]*\x27", "", s)
s = re.sub(r"\"[^\"]*\"", "", s)
s = re.sub(r"<<.*?EOF.*?EOF", "", s, flags=re.DOTALL)
sys.stdout.write(s)
' 2>/dev/null || printf '%s' "$command")
        # Check if command references a .env file via cat/head/tail/less/more/sed/awk
        if echo "$stripped" | grep -qE '(cat|head|tail|less|more|sed|awk|source|\.)[[:space:]]+[^|]*\.env($|\.|\s)'; then
            cat <<EOF >&2
[no-env-read] Bash blocked: command appears to read a .env file.

Why: .env files contain secrets (API keys, passwords, tokens).
Claude should never read or display their contents.

Offending command:
$command
EOF
            exit 2
        fi
        ;;
esac

exit 0
