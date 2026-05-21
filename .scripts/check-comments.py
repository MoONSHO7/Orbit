#!/usr/bin/env python3
# Orbit Comment Lint
#
# Enforces the CLAUDE.md comment discipline:
#
#   1. No `--[[ ... ]]` block comments anywhere in Orbit sources. Lua block
#      comments hide structure and break grep-friendly diffs. Use single-line
#      `--` comments only.
#
#   2. No bare `-----` separator lines. Section navigation uses the canonical
#      `-- [ TITLE ] ----...` divider format (text inside, padded with dashes
#      to column 102); a bare row of dashes adds visual noise without info.
#
#   3. No stacked filename-restating headers. The pattern
#          -- BagSpace.lua
#          -- Short description of file
#      at the top of a file is decorative and duplicates the README's file
#      table. Drop both lines.
#
#   4. WARN on big multi-line module-doc blocks at file top (6+ consecutive
#      `--` lines after the divider). Most of these duplicate the README;
#      keep one canonical source of truth.
#
# Lib roots (`Core/Libs/`) and bundled assets are excluded — third-party
# libraries follow upstream conventions.
#
# Exit 0 on success, 1 on any hard failure (rules 1-3). Rule 4 is a warning.

import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
SCAN_ROOTS = [REPO_ROOT / "Orbit"]

EXCLUDE_DIR_NAMES = {"Libs", "assets", ".git"}

BLOCK_COMMENT_RE = re.compile(r"^\s*--\[\[")
BARE_SEP_RE = re.compile(r"^---+\s*$")
DIVIDER_RE = re.compile(r"^-- \[\s.+?\s\]\s*-*\s*$")
FILE_HEADER_LINE_1 = re.compile(r"^-- ([A-Za-z][\w]*)\.lua\s*$")
FILE_HEADER_LINE_2 = re.compile(r"^-- \S")

# Threshold for the "big block" warning. Files with more than this many
# consecutive `--` lines starting at line 1 (or right after a single divider)
# get flagged. Tuned so the canonical (divider + 1-line WHY) shape passes.
BIG_BLOCK_LINES = 6


def iter_lua_files():
    for root in SCAN_ROOTS:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIR_NAMES]
            for fn in filenames:
                if fn.endswith(".lua"):
                    yield Path(dirpath) / fn


def leading_comment_run(lines):
    """Count consecutive `--` lines from the start (skipping blank lines)."""
    n = 0
    for line in lines:
        s = line.rstrip("\n")
        if s.strip() == "":
            continue
        if s.startswith("--"):
            n += 1
        else:
            break
    return n


def main():
    fail = False
    print("=== Orbit Comment Lint ===")
    print(f"Repo: {REPO_ROOT}")
    print()

    block_comments = []
    bare_seps = []
    stacked_headers = []
    big_blocks = []

    for fp in iter_lua_files():
        rel = fp.relative_to(REPO_ROOT)
        try:
            with open(fp, encoding="utf-8", errors="replace") as f:
                lines = f.readlines()
        except OSError:
            continue

        for i, line in enumerate(lines, 1):
            s = line.rstrip("\n")
            if BLOCK_COMMENT_RE.match(s):
                block_comments.append((rel, i))
            if BARE_SEP_RE.match(s):
                bare_seps.append((rel, i))

        # Stacked file-header check on lines 1-2 (allow leading blank lines).
        nonblank = [(i, ln.rstrip("\n")) for i, ln in enumerate(lines, 1) if ln.strip()]
        if len(nonblank) >= 2:
            (i1, l1), (_, l2) = nonblank[0], nonblank[1]
            m = FILE_HEADER_LINE_1.match(l1)
            if m and m.group(1) == fp.stem and FILE_HEADER_LINE_2.match(l2):
                stacked_headers.append((rel, i1))

        # Big-block warning. The canonical shape is divider + 1 short WHY line,
        # so a `--` run that exceeds BIG_BLOCK_LINES at file top is suspect.
        run = leading_comment_run(lines)
        if run > BIG_BLOCK_LINES:
            big_blocks.append((rel, run))

    # 1. Block comments
    print("=== Block comments ===")
    if block_comments:
        print(f"[FAIL] {len(block_comments)} `--[[` block comment(s):")
        for rel, ln in block_comments:
            print(f"  - {rel}:{ln}")
        fail = True
    else:
        print("[ OK ] No `--[[` block comments.")
    print()

    # 2. Bare separators
    print("=== Bare separator lines ===")
    if bare_seps:
        print(f"[FAIL] {len(bare_seps)} bare `---...` separator(s):")
        for rel, ln in bare_seps:
            print(f"  - {rel}:{ln}")
        fail = True
    else:
        print("[ OK ] No bare `---...` separators.")
    print()

    # 3. Stacked file headers
    print("=== Stacked file-header comments ===")
    if stacked_headers:
        print(f"[FAIL] {len(stacked_headers)} stacked filename-restating header(s):")
        for rel, ln in stacked_headers:
            print(f"  - {rel}:{ln}")
        fail = True
    else:
        print("[ OK ] No stacked filename-restating headers.")
    print()

    # 4. Big blocks (warn only)
    print("=== Big leading comment blocks ===")
    if big_blocks:
        print(f"[WARN] {len(big_blocks)} file(s) with > {BIG_BLOCK_LINES} consecutive leading `--` lines:")
        for rel, n in sorted(big_blocks, key=lambda t: -t[1]):
            print(f"  - {rel}  ({n} lines)")
        print("       Consider moving content into the directory's README.md.")
    else:
        print(f"[ OK ] No leading comment block exceeds {BIG_BLOCK_LINES} lines.")
    print()

    if not fail:
        print("[PASS] All hard checks passed.")
        sys.exit(0)
    print("[FAIL] One or more checks failed.")
    sys.exit(1)


if __name__ == "__main__":
    main()
