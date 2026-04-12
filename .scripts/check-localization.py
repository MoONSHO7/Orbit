#!/usr/bin/env python3
# Orbit Localization Lint
#
# Validates the Orbit.L central localization system:
#   1. Every L.KEY reference in the codebase resolves to a defined key.
#   2. Prefix isolation — each domain prefix lives in exactly one file.
#   3. No cross-domain key collisions.
#   4. Reports unused keys as a warning (non-fatal).
#
# Exit 0 on success, 1 on any hard failure. Safe to run in CI.

import os
import re
import sys
from collections import defaultdict
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
LOC_DIR = REPO_ROOT / "Orbit" / "Localization" / "Domains"
CODE_ROOT = REPO_ROOT / "Orbit"

KEY_DEF_RE = re.compile(r"^\s*([A-Z]{3,4}_[A-Z0-9_]+)\s*=", re.MULTILINE)
KEY_REF_RE = re.compile(r"(?:^|[^A-Za-z0-9_])L\.([A-Z]{3,4}_[A-Z0-9_]+)")
ENUS_BLOCK_RE = re.compile(r"enUS\s*=\s*\{")
PREFIXES = ["CMN", "CFG", "PLG", "PLU", "CMD", "MSG", "TOUR"]

def extract_enus_keys(filepath):
    """Extract keys defined inside enUS = { ... } blocks."""
    with open(filepath, encoding="utf-8") as f:
        content = f.read()

    keys = []
    # Find each enUS block and extract keys from it
    pos = 0
    while True:
        m = ENUS_BLOCK_RE.search(content, pos)
        if not m:
            break
        # Track brace depth to find matching close
        start = m.end()
        depth = 1
        i = start
        while i < len(content) and depth > 0:
            if content[i] == "{":
                depth += 1
            elif content[i] == "}":
                depth -= 1
            i += 1
        block = content[start:i - 1]
        keys.extend(KEY_DEF_RE.findall(block))
        pos = i

    return keys

def extract_references(code_root):
    """Find all L.KEY references in .lua files, excluding Localization/ and Libs/."""
    refs = set()
    for root, dirs, files in os.walk(code_root):
        dirs[:] = [d for d in dirs if d not in ("Localization", "Libs")]
        for fname in files:
            if not fname.endswith(".lua"):
                continue
            fpath = os.path.join(root, fname)
            with open(fpath, encoding="utf-8", errors="replace") as f:
                for line in f:
                    refs.update(KEY_REF_RE.findall(line))
    return refs

def main():
    if not LOC_DIR.is_dir():
        print(f"FAIL: {LOC_DIR} not found")
        sys.exit(1)

    fail = False
    verbose = os.environ.get("VERBOSE", "0") == "1"

    print("=== Orbit Localization Lint ===")
    print(f"Repo: {REPO_ROOT}")
    print()

    # 1. Extract defined keys from enUS blocks
    defined = set()
    keys_by_file = defaultdict(list)
    for lua_file in sorted(LOC_DIR.glob("*.lua")):
        file_keys = extract_enus_keys(lua_file)
        for k in file_keys:
            defined.add(k)
            keys_by_file[lua_file.name].append(k)

    print(f"Defined keys (enUS source of truth): {len(defined)}")

    # 2. Extract referenced keys from codebase
    referenced = extract_references(CODE_ROOT)
    print(f"Referenced keys: {len(referenced)}")
    print()

    # 3. Orphan check (referenced but not defined)
    orphans = sorted(referenced - defined)
    if orphans:
        print(f"[FAIL] Orphan references ({len(orphans)}) — used in code, not defined in any domain:")
        for k in orphans:
            print(f"  - L.{k}")
        print()
        fail = True
    else:
        print("[ OK ] No orphan references.")

    # 4. Prefix isolation
    print()
    print("=== Prefix isolation ===")
    for prefix in PREFIXES:
        prefix_files = []
        for fname, fkeys in keys_by_file.items():
            if any(k.startswith(prefix + "_") for k in fkeys):
                prefix_files.append(fname)
        if len(prefix_files) > 1:
            print(f"[FAIL] {prefix} defined in multiple files: {' '.join(prefix_files)}")
            fail = True
        elif len(prefix_files) == 0:
            print(f"[WARN] {prefix} not defined anywhere")
        else:
            print(f"[ OK ] {prefix}: {prefix_files[0]}")

    # 5. Cross-domain collision check
    print()
    print("=== Cross-domain collision check ===")
    key_sources = defaultdict(list)
    for fname, fkeys in keys_by_file.items():
        for k in fkeys:
            key_sources[k].append(fname)
    collisions = {k: files for k, files in key_sources.items() if len(files) > 1}
    if collisions:
        print(f"[FAIL] Cross-domain collisions ({len(collisions)}):")
        for k, files in sorted(collisions.items()):
            print(f"  - {k}: {' '.join(files)}")
        fail = True
    else:
        print("[ OK ] No cross-domain collisions.")

    # 6. Unused keys (warning only)
    print()
    unused = sorted(defined - referenced)
    if unused:
        print(f"[INFO] Unused keys ({len(unused)}) — defined but not yet referenced.")
        print("       This is expected pre-Phase-4; keys are pre-populated for migration.")
        if verbose:
            for k in unused:
                print(f"  - {k}")
        else:
            print("       Run with VERBOSE=1 to list them.")

    print()
    if not fail:
        print("[PASS] All hard checks passed.")
        sys.exit(0)
    else:
        print("[FAIL] One or more checks failed.")
        sys.exit(1)

if __name__ == "__main__":
    main()
