#!/usr/bin/env python3
# [ WCL META TALENTS PIPELINE ] ---------------------------------------------------
# Authenticates with Warcraft Logs (OAuth 2.0 Client Credentials), auto-discovers
# the latest expansion and its encounters via GraphQL, fetches Top 100 rankings for
# every class/spec, aggregates talent pick-rates, and writes OrbitData/TalentMeta.lua.
#
# Usage:
#   WCL_CLIENT_ID=xxx WCL_CLIENT_SECRET=yyy python build_meta.py
#
# Or for local dev with .env file at repo root:
#   python build_meta.py --env

import os
import re
import sys
import json
import time
import argparse
import requests
from collections import defaultdict
from pathlib import Path

# [ CONSTANTS ] -------------------------------------------------------------------

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
GRAPHQL_URL = "https://www.warcraftlogs.com/api/v2/client"
MIN_PICK_RATE = 1.0           # Filter out sub-1% noise
REQUEST_DELAY = 1.0           # Seconds between batched queries (rate-limit courtesy)
HTTP_CONNECT_TIMEOUT = 10     # Seconds to establish the TCP connection
HTTP_READ_TIMEOUT = 60        # Seconds to wait for a response body
MAX_RETRIES = 4               # Per request, on transient 429/5xx errors
BACKOFF_BASE = 2.0            # Exponential backoff base for retries

RAID_DIFFICULTIES = [
    ("Normal", 3),
    ("Heroic", 4),
    ("Mythic", 5),
]

MPLUS_DIFFICULTY_ID = 10

HEALER_SPECS = frozenset({
    "restoration", "holy", "discipline",
    "preservation", "mistweaver",
})

# Encounters sometimes come back with trailing difficulty markers like "Boss Heroic".
# Stripped via regex so the content key stays consistent across difficulties.
DIFFICULTY_SUFFIX_RE = re.compile(r"\s+(Normal|Heroic|Mythic)$", re.IGNORECASE)

# Repo-relative paths
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
OUTPUT_DIR = REPO_ROOT / "OrbitData"
OUTPUT_FILE = OUTPUT_DIR / "TalentMeta.lua"
OUTPUT_TOC = OUTPUT_DIR / "OrbitData.toc"
MAIN_TOC = REPO_ROOT / "Orbit" / "Orbit.toc"

# [ AUTH STATE ] ------------------------------------------------------------------

_credentials = {"id": None, "secret": None, "token": None}

# [ HTTP HELPERS ] ----------------------------------------------------------------

def _http_post(url, *, retries=MAX_RETRIES, **kwargs):
    """POST with exponential backoff on 429/5xx and a hard timeout."""
    kwargs.setdefault("timeout", (HTTP_CONNECT_TIMEOUT, HTTP_READ_TIMEOUT))
    last_exc = None
    for attempt in range(retries + 1):
        try:
            resp = requests.post(url, **kwargs)
            if resp.status_code in (429, 500, 502, 503, 504):
                raise requests.HTTPError(f"HTTP {resp.status_code}", response=resp)
            return resp
        except (requests.ConnectionError, requests.Timeout, requests.HTTPError) as e:
            last_exc = e
            if attempt >= retries:
                raise
            wait = BACKOFF_BASE ** attempt
            print(f"  [retry] {type(e).__name__}: {e} — sleeping {wait:.1f}s", file=sys.stderr)
            time.sleep(wait)
    raise last_exc  # unreachable

# [ AUTH ] ------------------------------------------------------------------------

def get_auth_token(client_id, client_secret):
    """Acquire an OAuth 2.0 Bearer token via Client Credentials flow."""
    resp = _http_post(
        TOKEN_URL,
        auth=(client_id, client_secret),
        data={"grant_type": "client_credentials"},
    )
    resp.raise_for_status()
    token = resp.json().get("access_token")
    if not token:
        raise RuntimeError("OAuth response missing access_token")
    _credentials["id"] = client_id
    _credentials["secret"] = client_secret
    _credentials["token"] = token
    return token

def refresh_auth_token():
    """Re-acquire a Bearer token using the cached credentials (for 401 recovery)."""
    if not _credentials["id"]:
        raise RuntimeError("Cannot refresh token: no cached credentials")
    return get_auth_token(_credentials["id"], _credentials["secret"])

# [ GRAPHQL ] ---------------------------------------------------------------------

def graphql(query, variables):
    """Execute a GraphQL query. Auto-refreshes the token once on 401."""
    for refreshed in (False, True):
        headers = {
            "Authorization": f"Bearer {_credentials['token']}",
            "Content-Type": "application/json",
        }
        resp = _http_post(
            GRAPHQL_URL,
            headers=headers,
            json={"query": query, "variables": variables},
        )
        if resp.status_code == 401 and not refreshed:
            print("  [auth] token expired, refreshing...", file=sys.stderr)
            refresh_auth_token()
            continue
        resp.raise_for_status()
        data = resp.json()
        if "errors" in data:
            raise RuntimeError(f"GraphQL errors: {json.dumps(data['errors'], indent=2)}")
        return data
    raise RuntimeError("Unreachable")

# [ EXPANSION DISCOVERY ] ---------------------------------------------------------

EXPANSIONS_QUERY = """
query GetExpansions {
  worldData {
    expansions { id name }
  }
}
"""

def discover_latest_expansion():
    """Return the latest expansion id + name from WCL's worldData.expansions."""
    data = graphql(EXPANSIONS_QUERY, {})
    expansions = data["data"]["worldData"]["expansions"]
    if not expansions:
        raise RuntimeError("worldData.expansions returned empty list")
    latest = max(expansions, key=lambda e: e["id"])
    return latest["id"], latest["name"]

# [ DISCOVERY QUERY ] -------------------------------------------------------------

DISCOVERY_QUERY = """
query GetGameMetadata($expansionId: Int!) {
  gameData {
    classes {
      name
      slug
      specs { name slug }
    }
  }
  worldData {
    expansion(id: $expansionId) {
      zones {
        name
        encounters { id name }
      }
    }
  }
}
"""

def discover_metadata(expansion_id):
    """Fetch class/spec taxonomy and current expansion encounters."""
    data = graphql(DISCOVERY_QUERY, {"expansionId": expansion_id})
    game = data["data"]["gameData"]
    world = data["data"]["worldData"]

    class_specs = {}
    for cls in game["classes"]:
        class_specs[cls["slug"]] = {
            "name": cls["name"],
            "specs": [{"slug": s["slug"], "name": s["name"]} for s in cls["specs"]],
        }

    raid_encounters = []
    mplus_encounters = []
    renamed = []

    zones = world["expansion"]["zones"] if world["expansion"] else []
    for zone in zones:
        zone_name = zone["name"]
        zone_lower = zone_name.lower()
        if "beta" in zone_lower or "ptr" in zone_lower:
            print(f"  Skipping beta/PTR zone: {zone_name}")
            continue
        if "complete raids" in zone_lower:
            print(f"  Skipping aggregate zone: {zone_name}")
            continue
        is_mplus_zone = "mythic+" in zone_lower
        for enc in zone.get("encounters", []):
            raw_name = enc["name"]
            clean_name = DIFFICULTY_SUFFIX_RE.sub("", raw_name)
            if clean_name != raw_name:
                renamed.append((raw_name, clean_name))
            enc_data = {"id": enc["id"], "name": clean_name, "zone": zone_name}
            if is_mplus_zone:
                mplus_encounters.append(enc_data)
            else:
                raid_encounters.append(enc_data)

    if renamed:
        print(f"  Stripped difficulty suffix from {len(renamed)} encounter name(s):")
        for before, after in renamed:
            print(f"    {before!r} -> {after!r}")

    print(f"Discovered {len(class_specs)} classes, {len(raid_encounters)} raid, {len(mplus_encounters)} M+ encounters")
    return class_specs, raid_encounters, mplus_encounters

# [ BATCH RANKINGS QUERY ] --------------------------------------------------------

def build_batch_query(encounters):
    """Build a GraphQL query that aliases one characterRankings block per encounter."""
    fragments = []
    for i, enc in enumerate(encounters):
        alias = f"enc{i}"
        fragments.append(
            f'    {alias}: encounter(id: {enc["id"]}) {{\n'
            f'      characterRankings(className: $className, specName: $specName,'
            f' metric: $metric, difficulty: $difficulty, page: 1,'
            f' includeCombatantInfo: true)\n'
            f'    }}'
        )
    body = "\n".join(fragments)
    return (
        "query GetBatchRankings(\n"
        "  $className: String!,\n"
        "  $specName: String!,\n"
        "  $metric: CharacterRankingMetricType!,\n"
        "  $difficulty: Int!,\n"
        ") {\n"
        "  worldData {\n"
        f"{body}\n"
        "  }\n"
        "}"
    )


def get_metric(spec_slug_lower):
    """WCL requires 'hps' for healers, 'dps' for everyone else."""
    if spec_slug_lower in HEALER_SPECS:
        return "hps"
    return "dps"

# [ AGGREGATION ] -----------------------------------------------------------------

# Run-level counters, consumed by the summary at the end.
_run_stats = {
    "queries_attempted": 0,
    "queries_failed": 0,
    "combinations_with_data": 0,
    "combinations_empty": 0,
    "failed_details": [],  # (class, spec, context) tuples
}

def execute_combination_query(batch_query, class_slug, spec_slug, encounters, difficulty_info):
    diff_name, diff_id = difficulty_info
    metric = get_metric(spec_slug.lower())
    variables = {
        "className": class_slug,
        "specName": spec_slug,
        "metric": metric,
        "difficulty": diff_id,
    }

    _run_stats["queries_attempted"] += 1
    try:
        data = graphql(batch_query, variables)
    except Exception as e:
        _run_stats["queries_failed"] += 1
        _run_stats["failed_details"].append((class_slug, spec_slug, f"{diff_name}: {e}"))
        print(f"      [!] API error on {diff_name}: {e}")
        return {}

    world = data.get("data", {}).get("worldData", {})
    tally_by_content = defaultdict(lambda: defaultdict(int))
    logs_by_content = defaultdict(int)

    for i, enc in enumerate(encounters):
        alias = f"enc{i}"
        enc_data = world.get(alias)
        if not enc_data:
            continue
        rankings_wrapper = enc_data.get("characterRankings")
        if not rankings_wrapper:
            continue
        rankings = rankings_wrapper.get("rankings", [])
        if not rankings:
            continue

        content_key = enc["name"]

        # Filter out players with incomplete talent allocation. Find the modal
        # (most common) talent count and reject anyone more than 2 short of it.
        talent_counts = [len(p.get("talents", [])) for p in rankings]
        if talent_counts:
            mode_count = max(set(talent_counts), key=talent_counts.count)
            min_allowed = mode_count - 2
        else:
            min_allowed = 0

        for player in rankings:
            talents = player.get("talents", [])
            if len(talents) < min_allowed:
                continue
            logs_by_content[content_key] += 1
            for talent in talents:
                if "talentID" in talent:
                    tally_by_content[content_key][talent["talentID"]] += 1

    # Convert to pick-rate percentages.
    final_results = {}
    for content_key, tally in tally_by_content.items():
        total_logs = logs_by_content[content_key]
        if total_logs == 0:
            _run_stats["combinations_empty"] += 1
            continue
        pct_map = {}
        for entry_id, count in tally.items():
            pct = round((count / total_logs) * 100, 1)
            if pct >= MIN_PICK_RATE:
                pct_map[entry_id] = pct
        if pct_map:
            final_results[content_key] = pct_map
            _run_stats["combinations_with_data"] += 1
        else:
            _run_stats["combinations_empty"] += 1

    return final_results

# [ LUA GENERATION ] --------------------------------------------------------------

def slug_to_wow(slug):
    """Normalize WCL slug to WoW classFile format: 'DeathKnight' -> 'deathknight'.
    WoW: UnitClass returns 'DEATHKNIGHT', string.lower() gives 'deathknight'.
    WCL: Discovery returns 'DeathKnight'. Lowercase + strip hyphens to bridge."""
    return slug.replace("-", "").lower()

CATALOG_BLOCK_START = "-- _Catalog lists every content name"
CATALOG_BLOCK_END_MARKER = "Orbit.Data.TalentMeta = {"

def build_catalog_block(raid_content, mplus_content, raid_difficulties):
    """Render just the Orbit.Data.TalentMetaCatalog section, preserving the
    order of the input lists (WCL's discovery order for encounters)."""
    lines = [
        "-- _Catalog lists every content name discovered at build time so the Lua",
        "-- dropdowns can populate themselves from a single source of truth.",
        "-- Order is preserved from WCL discovery (raid fight order for bosses,",
        "-- WCL's M+ zone order for dungeons).",
        "Orbit.Data.TalentMetaCatalog = {",
        "    raidBosses = {",
    ]
    for name in raid_content:
        lines.append(f'        "{name}",')
    lines.append("    },")
    lines.append("    mplusDungeons = {")
    for name in mplus_content:
        lines.append(f'        "{name}",')
    lines.append("    },")
    lines.append("    raidDifficulties = {")
    for diff_name in raid_difficulties:
        lines.append(f'        "{diff_name}",')
    lines.append("    },")
    lines.append("}")
    return "\n".join(lines)


def build_lua(meta_db, raid_content, mplus_content, raid_difficulties):
    """Generate the TalentMeta.lua data module for the LoD addon."""
    lines = [
        "-- [ TALENT META DATA ] -----------------------------------------------------------------",
        "-- Auto-generated by .scripts/build_meta.py - do not edit manually.",
        "",
        "-- LoD addon: write to the global Orbit table (separate addon table from core)",
        "-- Keys are lowercase WoW classFile/specName (no hyphens) for direct UnitClass lookup",
        "Orbit.Data = Orbit.Data or {}",
        "",
        build_catalog_block(raid_content, mplus_content, raid_difficulties),
        "",
        "Orbit.Data.TalentMeta = {",
    ]

    # Structure: meta_db[content][difficulty][class][spec] = { spell: pct }
    for content_name, content_data in sorted(meta_db.items()):
        lines.append(f'    ["{content_name}"] = {{')
        for diff_name, diff_data in sorted(content_data.items()):
            lines.append(f'        ["{diff_name}"] = {{')
            for class_slug, specs in sorted(diff_data.items()):
                wow_class = slug_to_wow(class_slug)
                lines.append(f'            ["{wow_class}"] = {{')
                for spec_slug, talents in sorted(specs.items()):
                    wow_spec = slug_to_wow(spec_slug)
                    lines.append(f'                ["{wow_spec}"] = {{')
                    for entry_id, pct in sorted(talents.items()):
                        lines.append(f"                    [{entry_id}] = {pct},")
                    lines.append("                },")
                lines.append("            },")
            lines.append("        },")
        lines.append("    },")

    lines.append("}")
    lines.append("")  # Trailing newline
    return "\n".join(lines)

# [ TOC GENERATION ] --------------------------------------------------------------

def read_main_interface_line():
    """Read the `## Interface:` line from the main Orbit.toc so the generated
    OrbitData.toc tracks the same game version."""
    if not MAIN_TOC.exists():
        return "## Interface: 120001"
    try:
        with open(MAIN_TOC, encoding="utf-8") as f:
            for line in f:
                if line.startswith("## Interface:"):
                    return line.rstrip("\n")
    except Exception as e:
        print(f"  [warn] Could not read {MAIN_TOC}: {e}", file=sys.stderr)
    return "## Interface: 120001"

def build_toc():
    interface_line = read_main_interface_line()
    return "\n".join([
        interface_line,
        "## Title: Data",
        "## Notes: Auto-generated data modules for Orbit (talent meta, etc).",
        "## Author: github-actions[bot]",
        "## IconTexture: Interface\\AddOns\\Orbit\\Core\\assets\\Orbit.png",
        "## Category: Orbit UI",
        "## LoadOnDemand: 1",
        "## Dependencies: Orbit",
        "",
        "TalentMeta.lua",
        "",
    ])

def write_output(lua_content):
    """Write the generated Lua and always-rewrite the TOC."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(lua_content, encoding="utf-8")
    print(f"Wrote {OUTPUT_FILE} ({len(lua_content)} bytes)")

    toc_content = build_toc()
    if not OUTPUT_TOC.exists() or OUTPUT_TOC.read_text(encoding="utf-8") != toc_content:
        OUTPUT_TOC.write_text(toc_content, encoding="utf-8")
        print(f"Updated {OUTPUT_TOC}")


def patch_catalog_only(raid_content, mplus_content, raid_difficulties):
    """Surgically inject/replace only the TalentMetaCatalog block in the
    existing TalentMeta.lua without touching the TalentMeta data section.
    Used by --catalog-only for fast content-order fixups."""
    if not OUTPUT_FILE.exists():
        raise RuntimeError(f"Cannot patch: {OUTPUT_FILE} does not exist. Run a full build first.")

    existing = OUTPUT_FILE.read_text(encoding="utf-8")
    catalog_block = build_catalog_block(raid_content, mplus_content, raid_difficulties)

    # If an existing catalog block is present, replace it. Otherwise insert
    # it before the `Orbit.Data.TalentMeta = {` line.
    marker = CATALOG_BLOCK_END_MARKER
    if marker not in existing:
        raise RuntimeError(f"Cannot find marker {marker!r} in {OUTPUT_FILE}")

    if CATALOG_BLOCK_START in existing:
        # Replace from the start-of-comment line through the blank line before
        # `Orbit.Data.TalentMeta = {`.
        pattern = re.compile(
            r"-- _Catalog lists every content name.*?(?=Orbit\.Data\.TalentMeta = \{)",
            re.DOTALL,
        )
        new_content = pattern.sub(catalog_block + "\n\n", existing, count=1)
    else:
        # No existing catalog — insert it just before the data block.
        new_content = existing.replace(
            marker,
            catalog_block + "\n\n" + marker,
            1,
        )

    OUTPUT_FILE.write_text(new_content, encoding="utf-8")
    print(f"Patched catalog in {OUTPUT_FILE}")
    print(f"  raidBosses:       {len(raid_content)} entries")
    print(f"  mplusDungeons:    {len(mplus_content)} entries")
    print(f"  raidDifficulties: {raid_difficulties}")

# [ ENV LOADER ] ------------------------------------------------------------------

def load_env_file():
    """Load .env from repo root for local development."""
    env_path = REPO_ROOT / ".env"
    if not env_path.exists():
        return
    with open(env_path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())
    print("Loaded .env file")

# [ HELPERS ] ---------------------------------------------------------------------

def _unique_ordered(items):
    """Deduplicate while preserving first-seen order. Used for content catalog
    ordering so raid bosses / M+ dungeons follow WCL's discovery order rather
    than alphabetical."""
    seen = set()
    result = []
    for item in items:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result

# [ SUMMARY REPORT ] --------------------------------------------------------------

def print_summary(total_specs, meta_db):
    total_combinations = _run_stats["queries_attempted"]
    failed = _run_stats["queries_failed"]
    with_data = _run_stats["combinations_with_data"]
    empty = _run_stats["combinations_empty"]

    content_count = len(meta_db)
    total_cells = 0
    for content_data in meta_db.values():
        for diff_data in content_data.values():
            for class_data in diff_data.values():
                total_cells += len(class_data)

    print("")
    print("-" * 60)
    print("SUMMARY")
    print("-" * 60)
    print(f"Specs processed:          {total_specs}")
    print(f"Queries attempted:        {total_combinations}")
    print(f"Queries failed:           {failed}")
    print(f"Combinations with data:   {with_data}")
    print(f"Combinations empty:       {empty}")
    print(f"Content entries in DB:    {content_count}")
    print(f"Total (content, diff, class, spec) cells written: {total_cells}")
    if _run_stats["failed_details"]:
        print("")
        print("Failed queries:")
        for cls, spec, ctx in _run_stats["failed_details"][:20]:
            print(f"  {cls}/{spec} — {ctx}")
        if len(_run_stats["failed_details"]) > 20:
            print(f"  ... and {len(_run_stats['failed_details']) - 20} more")
    print("-" * 60)

# [ MAIN ] ------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Fetch WCL Top 100 talent meta data")
    parser.add_argument("--env", action="store_true", help="Load credentials from .env file")
    parser.add_argument("--dry-run", action="store_true", help="Print Lua output without writing")
    parser.add_argument("--expansion-id", type=int, default=None,
                        help="Override auto-detected expansion id (for backfills/testing)")
    parser.add_argument("--limit", type=int, default=None,
                        help="Only process the first N specs (smoke test)")
    parser.add_argument("--catalog-only", action="store_true",
                        help="Only refresh the TalentMetaCatalog block in the existing "
                             "TalentMeta.lua. Skips the rankings phase (fast, ~5 seconds).")
    args = parser.parse_args()

    if args.env:
        load_env_file()

    client_id = os.environ.get("WCL_CLIENT_ID") or os.environ.get("WLOGS_CLIENT_ID")
    client_secret = os.environ.get("WCL_CLIENT_SECRET") or os.environ.get("WLOGS_CLIENT_SECRET")

    if not client_id or not client_secret:
        print("Error: WCL_CLIENT_ID and WCL_CLIENT_SECRET must be set", file=sys.stderr)
        sys.exit(1)

    # 1. Authenticate
    print("Authenticating with Warcraft Logs...")
    get_auth_token(client_id, client_secret)
    print("Authenticated.")

    # 2. Discover expansion (auto or override)
    if args.expansion_id is not None:
        expansion_id = args.expansion_id
        print(f"Using override expansion id: {expansion_id}")
    else:
        expansion_id, expansion_name = discover_latest_expansion()
        print(f"Latest expansion: {expansion_id} ({expansion_name})")

    # 3. Discover classes, specs, encounters
    class_specs, raid_encounters, mplus_encounters = discover_metadata(expansion_id)

    if not raid_encounters and not mplus_encounters:
        print(f"Error: No encounters found for expansion {expansion_id}", file=sys.stderr)
        sys.exit(1)

    # Catalog-only fast path: skip the rankings phase, just patch the catalog.
    if args.catalog_only:
        raid_content_names = _unique_ordered(e["name"] for e in raid_encounters)
        mplus_content_names = _unique_ordered(e["name"] for e in mplus_encounters)
        raid_diff_names = [d[0] for d in RAID_DIFFICULTIES]
        print(f"Raid order: {raid_content_names}")
        print(f"M+ order:   {mplus_content_names}")
        if args.dry_run:
            print("\n--- DRY RUN (catalog block) ---")
            print(build_catalog_block(raid_content_names, mplus_content_names, raid_diff_names))
        else:
            patch_catalog_only(raid_content_names, mplus_content_names, raid_diff_names)
        print("Done.")
        return

    batch_query_raid = build_batch_query(raid_encounters) if raid_encounters else None

    # 4. Aggregate across all combinations
    meta_db = defaultdict(lambda: defaultdict(lambda: defaultdict(dict)))
    total_specs = sum(len(cls_data["specs"]) for cls_data in class_specs.values())
    if args.limit:
        total_specs = min(total_specs, args.limit)
        print(f"[smoke test] Limiting to first {args.limit} specs")
    processed = 0
    halted = False

    for class_slug, cls_data in sorted(class_specs.items()):
        if halted:
            break
        class_name = cls_data["name"]
        for spec_info in cls_data["specs"]:
            if args.limit and processed >= args.limit:
                halted = True
                break
            spec_slug = spec_info["slug"]
            spec_name = spec_info["name"]
            processed += 1
            print(f"[{processed}/{total_specs}] {class_name}/{spec_name}...")

            # --- RAID COMBINATIONS ---
            if batch_query_raid:
                for diff_info in RAID_DIFFICULTIES:
                    results = execute_combination_query(
                        batch_query_raid, class_slug, spec_slug, raid_encounters, diff_info,
                    )
                    for content_key, pct_map in results.items():
                        meta_db[content_key][diff_info[0]][class_slug][spec_slug] = pct_map
                    time.sleep(REQUEST_DELAY)

            # --- MYTHIC+ PER-DUNGEON ---
            for enc in mplus_encounters:
                single_query = build_batch_query([enc])
                diff_info = (enc["name"], MPLUS_DIFFICULTY_ID)
                results = execute_combination_query(
                    single_query, class_slug, spec_slug, [enc], diff_info,
                )
                for content_key, pct_map in results.items():
                    meta_db[content_key]["Mythic+"][class_slug][spec_slug] = pct_map
                time.sleep(REQUEST_DELAY)

    # 5. Build catalogs for the Lua side — preserve WCL discovery order so
    # raid bosses show up in fight order, not alphabetical.
    raid_content_names = _unique_ordered(e["name"] for e in raid_encounters)
    mplus_content_names = _unique_ordered(e["name"] for e in mplus_encounters)
    raid_diff_names = [d[0] for d in RAID_DIFFICULTIES]

    lua_content = build_lua(meta_db, raid_content_names, mplus_content_names, raid_diff_names)

    # 6. Emit
    if args.dry_run:
        print("\n--- DRY RUN OUTPUT (truncated) ---")
        print(lua_content[:2000])
        print(f"... ({len(lua_content)} total bytes)")
    else:
        write_output(lua_content)

    print_summary(total_specs, meta_db)
    print("Done.")

if __name__ == "__main__":
    main()
