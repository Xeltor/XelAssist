"""Authoritative XelAssist runtime manifest helpers.

WoW 1.12 has no module loader: the TOC is both the package manifest and the
dependency order. Development tools must therefore read the same file instead
of maintaining their own source lists.
"""
from collections import Counter
from pathlib import Path

RUNTIME_DIRECTORIES = ("Core", "Game", "Combat", "Graph", "UI")


def toc_entries(root: Path):
    entries = []
    for raw in (root / "XelAssist.toc").read_text().splitlines():
        entry = raw.strip()
        if not entry or entry.startswith("#"):
            continue
        path = Path(entry.replace("\\", "/"))
        if path.is_absolute() or ".." in path.parts:
            raise SystemExit(f"unsafe TOC entry: {entry}")
        entries.append(path)
    return entries


def production_lua_files(root: Path):
    entries = toc_entries(root)
    counts = Counter(entries)
    duplicates = sorted(path.as_posix() for path, count in counts.items() if count > 1)
    if duplicates:
        raise SystemExit("duplicate TOC entries: " + ", ".join(duplicates))

    listed = [path for path in entries if path.suffix.lower() == ".lua"]
    discovered = set()
    for directory in RUNTIME_DIRECTORIES:
        runtime_root = root / directory
        if runtime_root.is_dir():
            discovered.update(path.relative_to(root) for path in runtime_root.rglob("*.lua"))

    unlisted = sorted(path.as_posix() for path in discovered.difference(listed))
    missing = sorted(path.as_posix() for path in set(listed).difference(discovered))
    if unlisted:
        raise SystemExit("runtime Lua missing from TOC: " + ", ".join(unlisted))
    if missing:
        raise SystemExit("TOC Lua outside runtime tree or missing: " + ", ".join(missing))
    return [root / path for path in listed]
