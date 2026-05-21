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
# or `Engine.` namespace (e.g. `Orbit.CastBarMixin = {}`). The file that
# declares the mixin must also contain a freeze call against it, guarded for
# clients without table.freeze:
#
#     if table.freeze then table.freeze(Orbit.CastBarMixin) end
#
# Exemptions: mixins that legitimately hold module-level state (e.g.
# AuraMixin scratch buffers), or mixins extended across multiple files where
# the freeze cannot live at the end of the declaring file. These are listed
# in EXEMPT_MIXINS with a one-line justification.
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
    pattern = re.compile(
        r"^\s*local\s+([A-Za-z_][\w]*)\s*=\s*(?:Orbit|Engine)\." + re.escape(mixin_name) + r"\s*$",
        re.MULTILINE,
    )
    m = pattern.search(text)
    return m.group(1) if m else None


def file_freezes_mixin(text, mixin_name):
    if re.search(FREEZE_RE_TPL.format(name=re.escape(mixin_name)), text):
        return True
    alias = find_local_alias(text, mixin_name)
    if alias and re.search(FREEZE_RE_LOCAL_TPL.format(local_name=re.escape(alias)), text):
        return True
    return False


def main():
    fail = False
    print("=== Orbit Mixin Freeze Lint ===")
    print(f"Repo: {REPO_ROOT}")
    print()

    declarations = []
    for fp in iter_lua_files():
        with open(fp, encoding="utf-8", errors="replace") as f:
            text = f.read()
        for ln, line in enumerate(text.splitlines(), 1):
            m = DECL_RE.match(line.rstrip())
            if m:
                ns, name = m.group(1), m.group(2)
                declarations.append((name, ns, fp, ln, text))

    print(f"Found {len(declarations)} mixin declaration(s).")
    print()

    unfrozen = []
    frozen = []
    exempt_used = set()
    exempt_dead = []

    for name, ns, fp, ln, text in declarations:
        rel = fp.relative_to(REPO_ROOT)
        if name in EXEMPT_MIXINS:
            exempt_used.add(name)
            print(f"[skip] {ns}.{name}  ({rel})  — exempt: {EXEMPT_MIXINS[name]}")
            continue
        if file_freezes_mixin(text, name):
            frozen.append((name, rel))
        else:
            unfrozen.append((name, rel, ln))

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
