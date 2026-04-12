#!/usr/bin/env python3
# Download external library dependencies as ZIP archives.
# Usage: python fetch-libs.py [--force]

import argparse
import io
import os
import shutil
import sys
import zipfile
from pathlib import Path
from urllib.request import urlopen, Request
from urllib.error import URLError

SCRIPT_DIR = Path(__file__).resolve().parent
LIBS_DIR = SCRIPT_DIR.parent / "Orbit" / "Core" / "Libs"
CACHE_DIR = LIBS_DIR / ".cache"

EXTERNALS = [
    {"name": "LibDeflate",          "repo": "SafeteeWoW/LibDeflate",              "branch": "master"},
    {"name": "LibSerialize",        "repo": "rossnichols/LibSerialize",           "branch": "refs/tags/v1.0.0"},
    {"name": "LibCustomGlow-1.0",   "repo": "Stanzilla/LibCustomGlow",            "branch": "master"},
    {"name": "LibStub",             "repo": "wowace-clone/LibStub",               "branch": "master"},
    {"name": "CallbackHandler-1.0", "repo": "wowace-clone/CallbackHandler-1.0",   "branch": "master", "subdir": "CallbackHandler-1.0"},
    {"name": "LibSharedMedia-3.0",  "repo": "wowace-clone/LibSharedMedia-3.0",    "branch": "master", "subdir": "LibSharedMedia-3.0"},
    {"name": "LibDBIcon-1.0",       "repo": "wowace-clone/LibDBIcon-1.0",         "branch": "master"},
]

def download_lib(lib, force):
    final_dest = LIBS_DIR / lib["name"]
    if not force and final_dest.exists():
        print(f"  [skip]     {lib['name']}")
        return

    print(f"  [download] {lib['name']}")

    if final_dest.exists():
        shutil.rmtree(final_dest)

    branch = lib["branch"]
    if branch.startswith("refs/tags/"):
        url = f"https://github.com/{lib['repo']}/archive/{branch}.zip"
    else:
        url = f"https://github.com/{lib['repo']}/archive/refs/heads/{branch}.zip"

    try:
        req = Request(url, headers={"User-Agent": "fetch-libs/1.0"})
        with urlopen(req) as resp:
            data = resp.read()

        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            extract_dir = CACHE_DIR / f"{lib['name']}-extract"
            if extract_dir.exists():
                shutil.rmtree(extract_dir)
            zf.extractall(extract_dir)

            # The archive extracts to a folder like "LibDeflate-master"
            top_dirs = [d for d in extract_dir.iterdir() if d.is_dir()]
            if not top_dirs:
                raise RuntimeError(f"No directory found in archive for {lib['name']}")
            extracted = top_dirs[0]

            if "subdir" in lib:
                source = extracted / lib["subdir"]
                final_dest.mkdir(parents=True, exist_ok=True)
                for item in source.iterdir():
                    dest_item = final_dest / item.name
                    if item.is_dir():
                        shutil.copytree(item, dest_item)
                    else:
                        shutil.copy2(item, dest_item)
            else:
                shutil.move(str(extracted), str(final_dest))

            shutil.rmtree(extract_dir)

    except (URLError, OSError, zipfile.BadZipFile) as e:
        print(f"  [error] failed to download {lib['name']}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Fetch external WoW library dependencies")
    parser.add_argument("--force", action="store_true", help="Re-download even if already present")
    args = parser.parse_args()

    CACHE_DIR.mkdir(parents=True, exist_ok=True)

    for lib in EXTERNALS:
        download_lib(lib, args.force)

    print("\nDone.")

if __name__ == "__main__":
    main()
