#!/usr/bin/env python3
"""Build a clean XelAssist addon zip from the authoritative TOC."""
from pathlib import Path
import argparse
import zipfile

ROOT = Path(__file__).resolve().parents[1]
ZIP_TIMESTAMP = (1980, 1, 1, 0, 0, 0)


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
            name = (Path("XelAssist") / path.relative_to(ROOT)).as_posix()
            entry = zipfile.ZipInfo(name, ZIP_TIMESTAMP)
            entry.create_system = 3
            entry.external_attr = 0o100644 << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, path.read_bytes(), compress_type=zipfile.ZIP_DEFLATED,
                compresslevel=9)
    return output


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("output", nargs="?", type=Path, default=ROOT / "dist" / "XelAssist.zip")
    args = parser.parse_args()
    print(build(args.output.resolve()))
