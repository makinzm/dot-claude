#!/bin/bash
# PreToolUse hook for Write/Edit/apply_patch: mechanically enforce the
# AGENTS.md task workflow (request -> approval -> commit -> requirements &
# design -> approval -> commit -> implementation) for any repo that opts in
# to that convention.
#
# Opt-in detection: a repo only gets enforced if it has both an AGENTS.md
# and a docs/tasks/ directory at its root. Everywhere else this hook is a
# silent no-op, so it's safe to run globally across every project.
#
# What it enforces:
#   1. Never write/edit files directly on `main`/`master` in such a repo —
#      create a task branch first (AGENTS.md "never work on main" rule).
#   2. Before writing any file that is NOT part of the governance docs
#      (docs/**, AGENTS.md, README.md, devbox.json/devbox.lock,
#      .gitignore), require that docs/tasks/<branch>/design.md already
#      exists in the committed HEAD of the branch.
#      design.md is created exactly at the "Requirements & Design" step and
#      committed together with requirements.md at Commit #2 (AGENTS.md §3) —
#      so "design.md exists in HEAD" is a clean, deterministic proxy for
#      "both human approvals + both commits already happened", without the
#      brittle "is this an implementation commit" heuristic that an earlier
#      ADR (docs/adr/architecture/2026-10-10.md, Option B) flagged as a risk.
#
# What it cannot enforce: that a human actually said "approved" in chat —
# only that the corresponding commit exists. The chat approval itself stays
# a procedural, trust-based step.
set -euo pipefail

input=$(cat)
tool_name=$(echo "$input" | jq -r '.tool_name // ""')

if [ "$tool_name" != "Write" ] && [ "$tool_name" != "Edit" ] && [ "$tool_name" != "apply_patch" ]; then
    exit 0
fi

cwd=$(echo "$input" | jq -r '.cwd // empty')
[ -n "$cwd" ] || cwd=$(pwd)

if [ "$tool_name" = "apply_patch" ]; then
    patch_cmd=$(echo "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")
    file_path=$(echo "$patch_cmd" | grep -m1 '^\+\+\+ b/' | sed 's|^+++ b/||')
else
    file_path=$(echo "$input" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
fi
[ -n "$file_path" ] || exit 0

case "$file_path" in
    /*) abs_path="$file_path" ;;
    *) abs_path="$cwd/$file_path" ;;
esac

# Canonicalize both sides the same way (resolve symlinks, e.g. macOS
# /var -> /private/var), so the later prefix-strip actually matches. The
# target file (and even its parent directories) may not exist yet (Write
# creates new, possibly nested, files), so use Python's realpath, which
# resolves whatever symlink components do exist and leaves the rest alone,
# instead of a realpath/pwd -P that requires the full path to exist.
canon() { python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$1"; }
abs_path=$(canon "$abs_path")

repo_root=$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null || echo "")
[ -n "$repo_root" ] || exit 0
repo_root=$(canon "$repo_root")

# Opt-in: only enforce in repos that actually adopt this convention.
if [ ! -f "$repo_root/AGENTS.md" ] || [ ! -d "$repo_root/docs/tasks" ]; then
    exit 0
fi

# chezmoi-managed dotfiles repos have their own explicit main-branch
# exception (CLAUDE.md) and don't use this docs/tasks/ convention anyway;
# exempt defensively in case that ever changes.
case "$repo_root" in
    */.local/share/chezmoi*) exit 0 ;;
esac

branch=$(git -C "$repo_root" branch --show-current 2>/dev/null || echo "")

if [ "$branch" = "main" ] || [ "$branch" = "master" ]; then
    cat >&2 <<EOF
[agents-workflow-guard] Blocked: writing to "$file_path" directly on branch
"$branch" in a repo that follows AGENTS.md's task workflow.

AGENTS.md: never work directly on main. Create a task branch first:
  git checkout -b <task-id>
EOF
    exit 2
fi

# Path relative to repo root, for the governance-doc allowlist below.
rel_path="${abs_path#"$repo_root"/}"

case "$rel_path" in
    docs/*|AGENTS.md|README.md|devbox.json|devbox.lock|.gitignore|*/README.md)
        exit 0
        ;;
esac

task_dir="docs/tasks/$branch"
if git -C "$repo_root" show "HEAD:$task_dir/design.md" >/dev/null 2>&1; then
    exit 0
fi

cat >&2 <<EOF
[agents-workflow-guard] Blocked: writing implementation file "$file_path" on
branch "$branch", but $task_dir/design.md is not committed to HEAD yet.

AGENTS.md §3: requirements.md and design.md must be written, approved by
the human, and committed (Commit #2) before any implementation file lands.
Finish that step on this branch first (or write files only under docs/**,
AGENTS.md, README.md, devbox.json in the meantime).
EOF
exit 2
