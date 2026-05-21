#!/usr/bin/env python3
# Orbit Mixin Freeze Lint
#
# Enforces the CLAUDE.md mixin-freeze rule:
#
#   > After the mixin table is fully populated, call
#   > `table.freeze(MixinTable)` (12.0.5+) so any stray write at runtime
#   > errors immediately instead of silently corrupting the shared table.
#
# A mixin is any module-level table named `*Mixin` declared on the `Orbit.`
# or `Engine.` namespace (e.g. `Orbit.CastBarMixin = {}`). The repo must
# contain a `table.freeze(<MixinRef>)` call against it somewhere (typically
# at the end of the declaring file, but for mixins extended across multiple
# `.lua` files the freeze belongs at the end of the LAST extending file).
# Guard for clients without table.freeze:
#
#     if table.freeze then table.freeze(Orbit.CastBarMixin) end
#
# In addition, this script verifies that the freeze sits in a file that runs
# AFTER every file that writes to the mixin — otherwise the late write either
# silently fails or raises "attempt to modify a read-only table" at load
# time, leaving the method nil at call time. Cross-file write detection is
# alias-aware: `local M = Orbit.X` followed by `function M.Y(...)` counts.
#
# Exemptions: mixins that legitimately hold module-level state (e.g.
# AuraMixin scratch buffers). Listed in EXEMPT_MIXINS with one-line WHY.
#
# Exit 0 on success, 1 on any hard failure. Safe to run in CI.

import os
import re
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
SCAN_ROOTS = [REPO_ROOT / "Orbit"]

EXCLUDE_DIR_NAMES = {"Libs", "assets", ".git"}

DECL_RE = re.compile(r"^(Orbit|Engine)\.([A-Za-z][\w]*Mixin)\s*=\s*\{\s*\}\s*$")
FREEZE_RE_TPL = r"table\.freeze\s*\(\s*(?:Orbit|Engine|[A-Za-z_][\w]*)\.{name}\s*\)"
FREEZE_RE_LOCAL_TPL = r"table\.freeze\s*\(\s*{local_name}\s*\)"
ALIAS_DECL_TPL = r"^\s*local\s+(\w+)\s*=\s*(?:Orbit|Engine)\.{name}\s*$"
EXTERNAL_WRITE_TPLS = [
    r"^(?:function\s+)?(?:Orbit|Engine)\.{name}\.\w+\s*(?:=|\()",
    r"^(?:function\s+){alias}\.\w+\s*\(",
    r"^{alias}\.\w+\s*=",
]

# Mixins exempt from the freeze requirement, with one-line WHY for each.
# Trim this list as freezes are added.
EXEMPT_MIXINS = {
    "AuraMixin":              "stateful by design: scratch buffers + singleton curve ticker (see file header WHY).",
    "UnitAuraGridMixin":      "extended across UnitAuraGridReparenting.lua / UnitAuraGridExpirationPulse.lua; freeze would need to live in the last extending file.",
    "PluginMixin":            "core mixin — large surface, requires bottom-up audit before freezing.",
    "OOCFadeMixin":           "pending review — may write to internal caches.",
    "SystemMixin":            "Engine.SystemMixin plugin-system class; requires bottom-up audit.",
    "DispelIndicatorMixin":   "pending review — _dispelCurveCache write on plugin object only, but verify.",
    "UnitFrameMixin":         "large base mixin; pending audit.",
    "BossFramePreviewMixin":  "plugin-specific preview; pending audit.",
    "GroupFrameFactoryMixin": "pending audit.",
    "GroupFrameLayoutMixin":  "newly extracted; pending audit.",
    "GroupFramePreviewMixin": "pending audit.",
}


def iter_lua_files():
    for root in SCAN_ROOTS:
        for dirpath, dirnames, filenames in os.walk(root):
            dirnames[:] = [d for d in dirnames if d not in EXCLUDE_DIR_NAMES]
            for fn in filenames:
                if fn.endswith(".lua"):
                    yield Path(dirpath) / fn


def find_local_alias(text, mixin_name):
    # e.g. `local PG = Orbit.PandemicGlow`  →  alias `PG`
    pattern = re.compile(ALIAS_DECL_TPL.format(name=re.escape(mixin_name)), re.MULTILINE)
    m = pattern.search(text)
    return m.group(1) if m else None


def file_freezes_mixin(text, mixin_name):
    if re.search(FREEZE_RE_TPL.format(name=re.escape(mixin_name)), text):
        return True
    alias = find_local_alias(text, mixin_name)
    if alias and re.search(FREEZE_RE_LOCAL_TPL.format(local_name=re.escape(alias)), text):
        return True
    return False


def file_writes_mixin(text, mixin_name):
    """Return True if `text` writes a method/field onto the mixin (full or alias form)."""
    name_e = re.escape(mixin_name)
    if re.search(EXTERNAL_WRITE_TPLS[0].format(name=name_e), text, re.MULTILINE):
        return True
    alias = find_local_alias(text, mixin_name)
    if alias:
        alias_e = re.escape(alias)
        for tpl in EXTERNAL_WRITE_TPLS[1:]:
            if re.search(tpl.format(alias=alias_e), text, re.MULTILINE):
                return True
    return False


def main():
    fail = False
    print("=== Orbit Mixin Freeze Lint ===")
    print(f"Repo: {REPO_ROOT}")
    print()

    # Pass 1: index every file's text and find every mixin declaration.
    file_texts = {}
    declarations = []
    for fp in iter_lua_files():
        with open(fp, encoding="utf-8", errors="replace") as f:
            text = f.read()
        file_texts[fp] = text
        for ln, line in enumerate(text.splitlines(), 1):
            m = DECL_RE.match(line.rstrip())
            if m:
                ns, name = m.group(1), m.group(2)
                declarations.append((name, ns, fp, ln))

    print(f"Found {len(declarations)} mixin declaration(s).")
    print()

    unfrozen = []
    frozen = []
    write_after_freeze = []
    exempt_used = set()
    exempt_dead = []

    for name, ns, fp, ln in declarations:
        rel = fp.relative_to(REPO_ROOT)
        if name in EXEMPT_MIXINS:
            exempt_used.add(name)
            print(f"[skip] {ns}.{name}  ({rel})  — exempt: {EXEMPT_MIXINS[name]}")
            continue

        # Pass 2: search ALL files for a freeze of this mixin.
        freeze_file = None
        for ofp, otext in file_texts.items():
            if file_freezes_mixin(otext, name):
                freeze_file = ofp
                break

        if not freeze_file:
            unfrozen.append((name, rel, ln))
            continue
        frozen.append((name, freeze_file.relative_to(REPO_ROOT)))

        # Pass 3: only the declaring file and the freeze file may write to the
        # mixin. The declaring file is always safe (it runs first by definition),
        # and the freeze file is safe (its writes precede its own freeze call).
        # Any third file that writes is a load-order land-mine: if it loads
        # AFTER the freeze, the write either silently fails or raises
        # "attempt to modify a read-only table" depending on the client. The
        # GroupFrameMixin / GroupFrameEventHandler regression (May 2026) was
        # exactly this shape — freeze sat in the declaring file while the
        # event-handler file extended the mixin AFTER the freeze ran.
        offenders = []
        for ofp, otext in file_texts.items():
            if ofp == freeze_file or ofp == fp:
                continue
            if file_writes_mixin(otext, name):
                offenders.append(ofp.relative_to(REPO_ROOT))
        if offenders:
            write_after_freeze.append((name, freeze_file.relative_to(REPO_ROOT), offenders))

    # Detect stale exemptions (listed but no matching declaration).
    declared_names = {d[0] for d in declarations}
    for name in EXEMPT_MIXINS:
        if name not in declared_names:
            exempt_dead.append(name)

    print()
    print(f"[ OK ] {len(frozen)} mixin(s) frozen.")
    for name, rel in sorted(frozen):
        print(f"  - {name}  ({rel})")
    print()

    if unfrozen:
        print(f"[FAIL] {len(unfrozen)} mixin(s) missing `table.freeze`:")
        for name, rel, ln in unfrozen:
            print(f"  - {rel}:{ln}  declares {name} but never freezes it")
        print()
        print("       Fix: add `if table.freeze then table.freeze(Orbit.XxxMixin) end` at file end,")
        print("       or add the mixin to EXEMPT_MIXINS in this script with a one-line justification.")
        fail = True
    else:
        print("[ OK ] No unfrozen non-exempt mixins.")
    print()

    if write_after_freeze:
        print(f"[FAIL] {len(write_after_freeze)} mixin(s) written outside their freeze file:")
        for name, freeze_rel, offenders in write_after_freeze:
            print(f"  - {name} is frozen in {freeze_rel}, but also written in:")
            for o in offenders:
                print(f"      {o}")
        print()
        print("       Fix: either move the writes into the freeze file, or move the freeze")
        print("       to the end of the LAST file that writes to the mixin (load-order tail).")
        fail = True
    else:
        print("[ OK ] No external writes to frozen mixins.")
    print()

    if exempt_dead:
        print(f"[FAIL] {len(exempt_dead)} stale exemption(s) in EXEMPT_MIXINS (no matching declaration):")
        for name in exempt_dead:
            print(f"  - {name}")
        print("       Remove these from EXEMPT_MIXINS.")
        fail = True

    print()
    if not fail:
        print("[PASS] All checks passed.")
        sys.exit(0)
    print("[FAIL] One or more checks failed.")
    sys.exit(1)


if __name__ == "__main__":
    main()
