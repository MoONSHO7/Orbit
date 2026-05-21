#!/usr/bin/env python3
# Orbit README Lint
#
# Validates that README.md files keep pace with the code they describe.
# Catches the classes of regression that prompted the audit (May 2026):
#
#   1. Case sensitivity     — every README must be exactly `README.md`. Lowercase
#                             `readme.md` files load fine on Windows (case-insensitive
#                             NTFS) but break links on Linux CI and on case-sensitive
#                             clones. Any `readme.md` is a fail.
#
#   2. File-table drift     — if a README enumerates files (markdown table with a
#                             "file" column, or a fenced directory-tree block), every
#                             sibling `.lua` file must be mentioned. New files added
#                             without a README row are flagged.
#
#   3. Stale references     — every `*.lua` filename mentioned in a README is
#                             cross-checked against the repo. Reported as INFO,
#                             not FAIL — READMEs legitimately reference historical
#                             ("the now-deleted X.lua"), hypothetical ("would
#                             require a new TrackedRing.lua"), and Blizzard files.
#                             Set STRICT_STALE=1 to promote to FAIL.
#
# Lib roots (`Core/Libs/`) and bundled assets (`Core/assets/`, `.github/`) are
# excluded — third-party libraries follow upstream README conventions.
#
# Exit 0 on success, 1 on any hard failure. Safe to run in CI.

import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
ORBIT_ROOT = REPO_ROOT / "Orbit"

EXCLUDE_DIRS = {"Libs", "assets", ".github", ".git", ".scripts", "agent"}

TABLE_HEADER_RE = re.compile(r"\|\s*file\b", re.IGNORECASE)
TREE_LINE_RE = re.compile(r"^\s*[A-Za-z][\w/]*\.(lua|xml)\b", re.MULTILINE)
LUA_REF_RE = re.compile(r"\b([A-Za-z][\w]*)\.lua\b")

# Placeholders that READMEs use as teaching examples in "how to add a new X" sections.
# These intentionally do not exist on disk and must be excluded from stale-ref checks.
PLACEHOLDER_STEMS = {
    "MyPlugin", "MyTab", "MyModule", "MyCoolSetting", "MyBehavior",
    "NewFile", "NewBehaviorMixin", "NewWidget", "NewPlugin",
    "YourPlugin", "YourDatatext", "YourModule",
}


def iter_source_dirs(root):
    for dirpath, dirnames, _ in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        yield Path(dirpath)


def find_all_readmes(root):
    found = []
    for d in iter_source_dirs(root):
        for entry in os.listdir(d):
            if entry.lower() == "readme.md":
                found.append(d / entry)
    return found


def collect_lua_files(directory):
    return sorted(p.name for p in directory.iterdir() if p.is_file() and p.suffix == ".lua")


def collect_lua_files_recursive(directory):
    out = set()
    for dirpath, dirnames, files in os.walk(directory):
        dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIRS]
        for f in files:
            if f.endswith(".lua"):
                out.add(f)
    return out


def enumerates_files(text):
    if TABLE_HEADER_RE.search(text):
        return True
    if TREE_LINE_RE.search(text):
        return True
    return False


def stem(filename):
    return filename[:-4] if filename.endswith(".lua") else filename


def file_mentioned(text, fname):
    name = stem(fname)
    pattern = re.compile(r"\b" + re.escape(name) + r"\b")
    return bool(pattern.search(text))


def main():
    if not ORBIT_ROOT.is_dir():
        print(f"FAIL: {ORBIT_ROOT} not found")
        sys.exit(1)

    fail = False
    strict_stale = os.environ.get("STRICT_STALE", "0") == "1"
    print("=== Orbit README Lint ===")
    print(f"Repo: {REPO_ROOT}")
    print()

    # 1. Lowercase / mixed-case READMEs
    print("=== README casing ===")
    casing_errors = []
    for d in iter_source_dirs(REPO_ROOT):
        for entry in os.listdir(d):
            full = d / entry
            if not full.is_file():
                continue
            if entry.lower() == "readme.md" and entry != "README.md":
                casing_errors.append(full.relative_to(REPO_ROOT))
    if casing_errors:
        print(f"[FAIL] {len(casing_errors)} non-canonical README filename(s):")
        for p in casing_errors:
            print(f"  - {p} (must be README.md)")
        fail = True
    else:
        print("[ OK ] All README files use canonical uppercase name.")
    print()

    # 2. File-table completeness and stale references
    # Build a case-insensitive repo-wide set of every .lua stem so cross-module
    # references (e.g. StatusBars/README pointing at ComponentSettingsSchema.lua
    # under Core/CanvasMode, or a `shared/constants.lua` prose reference) don't
    # get flagged as stale.
    all_lua_repo = collect_lua_files_recursive(ORBIT_ROOT)
    all_stems_ci = {stem(f).lower() for f in all_lua_repo}

    print("=== File-table coverage ===")
    readmes = find_all_readmes(ORBIT_ROOT)
    missing_rows = []
    stale_refs = []
    enforced = 0
    skipped_narrative = 0

    for readme in sorted(readmes):
        with open(readme, encoding="utf-8", errors="replace") as f:
            text = f.read()

        directory = readme.parent
        rel = readme.relative_to(REPO_ROOT)

        # Stale-reference check: a .lua reference must resolve somewhere in the repo,
        # not necessarily under the README's own subtree (cross-module pointers are valid).
        # Case-insensitive to allow prose like `shared/constants.lua` when the real file
        # is `Constants.lua`.
        refs = set(LUA_REF_RE.findall(text))
        for r in sorted(refs):
            if r in PLACEHOLDER_STEMS:
                continue
            if r.lower() not in all_stems_ci:
                stale_refs.append((rel, r + ".lua"))

        # Completeness check only fires when the README clearly enumerates files.
        if not enumerates_files(text):
            skipped_narrative += 1
            continue
        enforced += 1

        siblings = collect_lua_files(directory)
        for sib in siblings:
            if not file_mentioned(text, sib):
                missing_rows.append((rel, sib))

    if missing_rows:
        print(f"[FAIL] {len(missing_rows)} unlisted sibling file(s):")
        for rel, fname in missing_rows:
            print(f"  - {rel} should mention {fname}")
        fail = True
    else:
        print(f"[ OK ] {enforced} enumerating README(s) cover all their siblings.")

    if stale_refs:
        tag = "[FAIL]" if strict_stale else "[INFO]"
        print(f"{tag} {len(stale_refs)} .lua reference(s) not found anywhere in repo:")
        for rel, fname in stale_refs:
            print(f"  - {rel} references {fname}")
        if strict_stale:
            fail = True
        else:
            print("       (Run with STRICT_STALE=1 to fail on these; most are intentional")
            print("        historical/hypothetical/Blizzard references.)")
    else:
        print("[ OK ] No unresolved .lua references.")

    print(f"       (Skipped {skipped_narrative} narrative-only README(s).)")
    print()

    if not fail:
        print("[PASS] All checks passed.")
        sys.exit(0)
    print("[FAIL] One or more checks failed.")
    sys.exit(1)


if __name__ == "__main__":
    main()
