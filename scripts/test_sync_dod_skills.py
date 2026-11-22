"""Tests for executable_sync-dod-skills.py: one Skill per DoD item, kept in sync."""

import importlib.util
import json
from pathlib import Path

SCRIPT_PATH = Path(__file__).resolve().parent / "executable_sync-dod-skills.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("sync_dod_skills", SCRIPT_PATH)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_sync_creates_one_skill_per_item_flat_under_skills_root(tmp_path):
    # apm's whole-repo skill discovery only looks one level under skills/
    # (skills/<name>/SKILL.md), so generated DoD skills must live directly
    # there too -- not nested under an extra skills/dod/ namespace folder,
    # which apm's scanner does not descend into.
    mod = _load_module()
    items = [
        {"id": "a", "title": "A", "check": "check a"},
        {"id": "b", "title": "B", "check": "check b"},
    ]
    skills_root = tmp_path / "skills"
    skills_root.mkdir()
    (skills_root / "unrelated-skill").mkdir()  # must survive sync() untouched

    written, removed = mod.sync(items, skills_root)

    assert sorted(written) == ["a", "b"]
    assert removed == []
    dod_dirs = sorted(
        p.name for p in skills_root.iterdir() if p.name.startswith("dod-")
    )
    assert dod_dirs == ["dod-a", "dod-b"]
    assert (skills_root / "unrelated-skill").is_dir()
    content = (skills_root / "dod-a" / "SKILL.md").read_text(encoding="utf-8")
    assert "name: dod-a" in content
    assert "check a" in content


def test_sync_removes_skills_no_longer_in_items(tmp_path):
    mod = _load_module()
    skills_root = tmp_path / "skills"
    skills_root.mkdir()
    (skills_root / "unrelated-skill").mkdir()
    mod.sync(
        [
            {"id": "a", "title": "A", "check": "check a"},
            {"id": "b", "title": "B", "check": "check b"},
        ],
        skills_root,
    )

    written, removed = mod.sync(
        [{"id": "a", "title": "A", "check": "check a"}],
        skills_root,
    )

    assert written == ["a"]
    assert removed == ["b"]
    dod_dirs = sorted(
        p.name for p in skills_root.iterdir() if p.name.startswith("dod-")
    )
    assert dod_dirs == ["dod-a"]
    assert (skills_root / "unrelated-skill").is_dir()


def test_load_items_reads_json(tmp_path):
    mod = _load_module()
    dod_json = tmp_path / "deliverables-dod.json"
    dod_json.write_text(
        json.dumps({"items": [{"id": "x", "title": "X", "check": "c"}]}),
        encoding="utf-8",
    )

    items = mod.load_items(dod_json)

    assert items == [{"id": "x", "title": "X", "check": "c"}]
