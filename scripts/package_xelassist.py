#!/usr/bin/env python3
"""Build a clean XelAssist addon zip from the authoritative TOC."""
from pathlib import Path
import argparse
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def addon_files():
    files = [ROOT / "XelAssist.toc", ROOT / "Bindings.xml", ROOT / "README.md", ROOT / "CHANGELOG.md"]
    for raw in (ROOT / "XelAssist.toc").read_text().splitlines():
        entry = raw.strip()
        if entry and not entry.startswith("##"):
            path = ROOT / entry.replace("\\", "/")
            if path not in files:
                files.append(path)
    missing = [str(path.relative_to(ROOT)) for path in files if not path.is_file()]
    if missing:
        raise SystemExit("missing package files: " + ", ".join(missing))
    return files


def build(output):
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in addon_files():
            archive.write(path, Path("XelAssist") / path.relative_to(ROOT))
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", nargs="?", type=Path, default=ROOT / "dist" / "XelAssist.zip")
    args = parser.parse_args()
    print(build(args.output.resolve()))
