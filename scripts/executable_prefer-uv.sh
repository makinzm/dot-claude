#!/bin/bash
# PreToolUse hook: require `uv` for Python environment/dependency management.
#
# Why: bare `python -m venv` + `pip install` produces an unlocked, drifting
# environment with no reproducibility. This bit us on 2026-07-26 (dance-app
# project): a whole Phase 0 setup was built with venv+pip and had to be redone
# with uv after the fact. `uv` gives a lockfile (uv.lock), is faster, and is
# now the project standard for all Python work.
#
# Exceptions: `uv pip install ...`, `uv venv`, and `uv run pip ...` are fine
# (they ARE uv, just using its pip-compatible interface).
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

if [ "$tool_name" != "Bash" ]; then
    exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // ""')

verdict=$(printf '%s' "$command" | python3 -c '
import re, sys

s = sys.stdin.read()

# Strip quoted segments first (best effort, no escaping support), same
# technique as no-bash-and.sh -- so occurrences of "pip install" etc. inside
# a quoted string argument (e.g. an echo/printf payload, a commit message, a
# test fixture) are not mistaken for an actual shell invocation.
stripped = re.sub(r"\x27[^\x27]*\x27", "", s)
stripped = re.sub(r"\"[^\"]*\"", "", stripped)


def flagged(line):
    if re.search(r"\buv\s+(pip\s+install|venv|run\s+pip)\b", line):
        return None
    if re.search(r"\bpip3?\s+install\b", line):
        return "pip install (use \x27uv add <pkg>\x27 or \x27uv pip install <pkg>\x27)"
    if re.search(r"\bpython3?\s+-m\s+venv\b", line):
        return "python -m venv (use \x27uv venv\x27, or just \x27uv add\x27/\x27uv sync\x27 which creates one)"
    if re.search(r"(^|\s)virtualenv\b", line):
        return "virtualenv (use \x27uv venv\x27)"
    return None


hit = None
for line in stripped.splitlines() or [stripped]:
    hit = flagged(line)
    if hit:
        break
print(hit or "")
' 2>/dev/null || true)

if [ -n "$verdict" ]; then
    {
        printf '[prefer-uv] Detected: %s\n\n' "$verdict"
        printf 'This environment standardizes on uv for Python env/dependency management,\n'
        printf 'not raw pip/venv/virtualenv.\n\n'
        printf 'Common replacements:\n'
        printf -- '- Add a dependency:        uv add <package>       (or: uv add --dev <package>)\n'
        printf -- '- Create/sync the venv:    uv venv   /   uv sync\n'
        printf -- '- Run something in it:     uv run <command>\n'
        printf -- '- One-off pip-compatible:  uv pip install <package>\n\n'
        printf 'Offending command:\n%s\n' "$command"
    } >&2
    exit 2
fi

exit 0
