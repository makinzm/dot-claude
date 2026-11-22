#!/usr/bin/env python3
"""Materialize ~/.claude/skills/dod-<id>/SKILL.md from ~/.claude/dod/deliverables-dod.json.

One Claude Code Skill per DoD item, no more and no fewer: the set of
dod-*-prefixed skill directories directly under skills/ is kept in exact
sync with the "items" list in deliverables-dod.json. Adding an item creates
a new skill; removing an item deletes its skill. This is the mechanism, not
a description of one: re-run this script after editing deliverables-dod.json.

Skills live flat under skills/ (skills/dod-<id>/SKILL.md), one level deep
like every other skill in this repo (skills/<name>/SKILL.md) -- apm's
whole-repo skill discovery for a bare `git: makinzm/dot-claude` dependency
only looks one level under skills/, so nesting these under an extra
skills/dod/ namespace folder would make apm fail to find them. Other repos
can pick individual DoD skills with `apm install makinzm/dot-claude --skill
dod-<id>` (or list them under `skills:` in their own apm.yml).
"""

import json
import shutil
import sys
from pathlib import Path

CLAUDE_DIR = Path(__file__).resolve().parent.parent
DEFAULT_DOD_JSON = CLAUDE_DIR / "dod" / "deliverables-dod.json"
DEFAULT_SKILLS_ROOT = CLAUDE_DIR / "skills"

DOD_PREFIX = "dod-"

SKILL_TEMPLATE = """---
name: dod-{id}
description: {description}
---

# DoD項目: {title}

{check}

## 使い方

成果物(記事・ドキュメント・設計案・PR)を完了とする前に、上記の観点を満たしているか確認する。満たしていなければ、完了として報告する前に修正する。
"""


def load_items(dod_json: Path) -> list[dict]:
    with dod_json.open(encoding="utf-8") as f:
        data = json.load(f)
    return data["items"]


def sync(items: list[dict], skills_root: Path) -> tuple[list[str], list[str]]:
    skills_root.mkdir(parents=True, exist_ok=True)

    wanted_ids = {item["id"] for item in items}
    existing_dod_ids = {
        p.name[len(DOD_PREFIX) :]
        for p in skills_root.iterdir()
        if p.is_dir() and p.name.startswith(DOD_PREFIX)
    }

    removed = sorted(existing_dod_ids - wanted_ids)
    for stale_id in removed:
        shutil.rmtree(skills_root / f"{DOD_PREFIX}{stale_id}")

    written = []
    for item in items:
        skill_dir = skills_root / f"{DOD_PREFIX}{item['id']}"
        skill_dir.mkdir(parents=True, exist_ok=True)
        description = f"成果物をDoD項目「{item['title']}」で確認する。記事・ドキュメント・設計案・PRの完了確認時に使う。"
        content = SKILL_TEMPLATE.format(
            id=item["id"],
            title=item["title"],
            check=item["check"],
            description=description,
        )
        (skill_dir / "SKILL.md").write_text(content, encoding="utf-8")
        written.append(item["id"])

    return written, removed


def main() -> int:
    items = load_items(DEFAULT_DOD_JSON)
    written, removed = sync(items, DEFAULT_SKILLS_ROOT)
    print(f"DoD items: {len(items)}")
    print(f"Skills written: {len(written)} -> {', '.join(written)}")
    if removed:
        print(
            f"Skills removed (no longer in DoD list): {len(removed)} -> {', '.join(removed)}"
        )
    if len(written) != len(items):
        print(
            "ERROR: generated skill count does not match DoD item count",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
