#!/usr/bin/env python3
# [ WCL META TALENTS PIPELINE ] ---------------------------------------------------
# Authenticates with Warcraft Logs (OAuth 2.0 Client Credentials), discovers the
# current expansion's encounters via GraphQL, fetches Top 100 rankings for every
# class/spec, aggregates talent pick-rates, and writes Orbit_MetaTalents_Data/TalentMeta.lua.
#
# Usage:
#   WCL_CLIENT_ID=xxx WCL_CLIENT_SECRET=yyy python build_meta.py
#
# Or for local dev with .env file:
#   python build_meta.py --env

import os
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
EXPANSION_ID = 7  # Midnight (WCL expansion numbering differs from Blizzard's)
MIN_PICK_RATE = 1.0  # Filter out sub-1% noise
REQUEST_DELAY = 1.0  # Seconds between batched queries (rate-limit courtesy)

RAID_DIFFICULTIES = [
    ("Normal", 3, 0),
    ("Heroic", 4, 0),
    ("Mythic", 5, 0),
]

MPLUS_DIFFICULTY = 10  # WCL difficulty ID for Mythic+

# Midnight Season 2 M+ Dungeon names (also used Lua-side for dropdown)
# Names must match WCL exactly
MPLUS_DUNGEONS = [
    "Algeth'ar Academy",
    "Magisters' Terrace",
    "Maisara Caverns",
    "Nexus-Point Xenas",
    "Pit of Saron",
    "Seat of the Triumvirate",
    "Skyreach",
    "Windrunner Spire",
]

HEALER_SPECS = frozenset({
    "restoration", "holy", "discipline",
    "preservation", "mistweaver",
})

TANK_SPECS = frozenset({
    "protection", "blood", "vengeance",
    "brewmaster", "guardian",
})

# Repo-relative output path
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
OUTPUT_DIR = REPO_ROOT / "OrbitData"
OUTPUT_FILE = OUTPUT_DIR / "TalentMeta.lua"

# [ AUTH ] ------------------------------------------------------------------------

def get_auth_token(client_id, client_secret):
    """Acquire an OAuth 2.0 Bearer token via Client Credentials flow."""
    resp = requests.post(
        TOKEN_URL,
        auth=(client_id, client_secret),
        data={"grant_type": "client_credentials"},
    )
    resp.raise_for_status()
    token = resp.json().get("access_token")
    if not token:
        raise RuntimeError("OAuth response missing access_token")
    return token

# [ GRAPHQL ] ---------------------------------------------------------------------

def graphql(query, variables, token):
    """Execute a GraphQL query against the WCL v2 client endpoint."""
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
    }
    resp = requests.post(
        GRAPHQL_URL,
        headers=headers,
        json={"query": query, "variables": variables},
    )
    resp.raise_for_status()
    data = resp.json()
    if "errors" in data:
        raise RuntimeError(f"GraphQL errors: {json.dumps(data['errors'], indent=2)}")
    return data

# [ DISCOVERY QUERY ] -------------------------------------------------------------

DISCOVERY_QUERY = """
query GetGameMetadata($expansionId: Int!) {
  gameData {
    classes {
      name
      slug
      specs {
        name
        slug
      }
    }
  }
  worldData {
    expansion(id: $expansionId) {
      zones {
        name
        encounters {
          id
          name
        }
      }
    }
  }
}
"""

def discover_metadata(token):
    """Fetch class/spec taxonomy and current expansion encounters."""
    data = graphql(DISCOVERY_QUERY, {"expansionId": EXPANSION_ID}, token)
    game = data["data"]["gameData"]
    world = data["data"]["worldData"]

    # Build class -> [{slug, name, specs: [{slug, name}]}] map
    class_specs = {}
    for cls in game["classes"]:
        class_specs[cls["slug"]] = {
            "name": cls["name"],
            "specs": [{"slug": s["slug"], "name": s["name"]} for s in cls["specs"]],
        }

    # Collect encounter IDs across all zones, filtering out Beta/PTR zones
    raid_encounters = []
    mplus_encounters = []

    zones = world["expansion"]["zones"] if world["expansion"] else []
    for zone in zones:
        zone_name = zone["name"]
        zone_lower = zone_name.lower()
        if "beta" in zone_lower or "ptr" in zone_lower:
            print(f"  Skipping beta zone: {zone_name}")
            continue
        if "complete raids" in zone_lower:
            print(f"  Skipping aggregate zone: {zone_name}")
            continue
        # M+ zone is "Mythic+ Season X" containing dungeon encounters
        is_mplus_zone = "mythic+" in zone_lower
        for enc in zone.get("encounters", []):
            enc_data = {
                "id": enc["id"],
                "name": enc["name"].replace(' Heroic', ''),
                "zone": zone_name,
            }
            if is_mplus_zone:
                mplus_encounters.append(enc_data)
            else:
                raid_encounters.append(enc_data)

    print(f"Discovered {len(class_specs)} classes, {len(raid_encounters)} raid, {len(mplus_encounters)} M+ encounters")
    return class_specs, raid_encounters, mplus_encounters

# [ BATCH RANKINGS QUERY ] --------------------------------------------------------

def build_batch_query(encounters, use_bracket=False):
    """Dynamically build a GraphQL query with aliased encounter rankings."""
    bracket_param = ", bracket: $bracket" if use_bracket else ""
    fragments = []
    for i, enc in enumerate(encounters):
        alias = f"enc{i}"
        fragments.append(
            f'    {alias}: encounter(id: {enc["id"]}) {{\n'
            f'      characterRankings(className: $className, specName: $specName,'
            f' metric: $metric, difficulty: $difficulty{bracket_param}, page: 1,'
            f' includeCombatantInfo: true)\n'
            f'    }}'
        )
    body = "\n".join(fragments)
    bracket_decl = "  $bracket: Int!,\n" if use_bracket else ""
    return (
        "query GetBatchRankings(\n"
        "  $className: String!,\n"
        "  $specName: String!,\n"
        "  $metric: CharacterRankingMetricType!,\n"
        "  $difficulty: Int!,\n"
        f"{bracket_decl}"
        ") {\n"
        "  worldData {\n"
        f"{body}\n"
        "  }\n"
        "}"
    )


def get_metric(spec_lower):
    """WCL requires 'hps' for healers, 'dps' for everyone else."""
    if spec_lower in HEALER_SPECS:
        return "hps"
    return "dps"


# [ AGGREGATION ] -----------------------------------------------------------------

def execute_combination_query(token, batch_query, class_slug, spec_slug, encounters, difficulty_info, is_mplus=False):
    diff_name, diff_id, bracket_val = difficulty_info
    metric = get_metric(spec_slug.lower())
    variables = {
        "className": class_slug,
        "specName": spec_slug,
        "metric": metric,
        "difficulty": diff_id,
    }
    if bracket_val:
        variables["bracket"] = bracket_val

    try:
        data = graphql(batch_query, variables, token)
    except Exception as e:
        print(f"      [!] API Error on diff {diff_name}: {e}")
        return {}, 0

    world = data.get("data", {}).get("worldData", {})

    tally_by_content = defaultdict(lambda: defaultdict(int))
    logs_by_content = defaultdict(int)

    for i, enc in enumerate(encounters):
        alias = f"enc{i}"
        enc_data = world.get(alias)
        if not enc_data: continue
        rankings_wrapper = enc_data.get("characterRankings")
        if not rankings_wrapper: continue
        rankings = rankings_wrapper.get("rankings", [])
        if not rankings: continue

        content_key = enc["name"]

        # Filter out players with incomplete talent allocation
        # Find the modal (most common) talent count, then reject outliers
        talent_counts = [len(p.get("talents", [])) for p in rankings]
        if talent_counts:
            mode_count = max(set(talent_counts), key=talent_counts.count)
            min_allowed = mode_count - 2  # allow small variance
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

    # Convert to %
    final_results = {}
    for content_key, tally in tally_by_content.items():
        total_logs = logs_by_content[content_key]
        if total_logs == 0: continue
        pct_map = {}
        for entry_id, count in tally.items():
            pct = round((count / total_logs) * 100, 1)
            if pct >= MIN_PICK_RATE:
                pct_map[entry_id] = pct
        final_results[content_key] = pct_map

    total_logs_all = sum(logs_by_content.values())
    return final_results, total_logs_all

# [ LUA GENERATION ] --------------------------------------------------------------

def slug_to_wow(slug):
    """Normalize WCL slug to WoW classFile format: 'DeathKnight' -> 'deathknight'.
    WoW: UnitClass returns 'DEATHKNIGHT', string.lower() gives 'deathknight'.
    WCL: Discovery returns 'DeathKnight'. Lowercase + strip hyphens to bridge."""
    return slug.replace("-", "").lower()

def build_lua(meta_db):
    """Generate the TalentMeta.lua data module for the LoD addon."""
    lines = [
        "-- [ TALENT META DATA ] -----------------------------------------------------------------",
        "-- Auto-generated by .scripts/build_meta.py — do not edit manually.",
        "",
        "-- LoD addon: write to the global Orbit table (separate addon table from core)",
        "-- Keys are lowercase WoW classFile/specName (no hyphens) for direct UnitClass lookup",
        "Orbit.Data = Orbit.Data or {}",
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

def write_output(lua_content):
    """Write the generated Lua to the LoD addon directory."""
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    OUTPUT_FILE.write_text(lua_content, encoding="utf-8")
    print(f"Wrote {OUTPUT_FILE} ({len(lua_content)} bytes)")

    # Ensure the TOC exists
    toc_path = OUTPUT_DIR / "OrbitData.toc"
    if not toc_path.exists():
        toc_content = "\n".join([
            "## Interface: 120001, 120000",
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
        toc_path.write_text(toc_content, encoding="utf-8")
        print(f"Created {toc_path}")

# [ ENV LOADER ] ------------------------------------------------------------------

def load_env_file():
    """Load .env from repo root for local development."""
    env_path = REPO_ROOT / ".env"
    if not env_path.exists():
        return
    with open(env_path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, value = line.partition("=")
            os.environ.setdefault(key.strip(), value.strip())
    print("Loaded .env file")

# [ MAIN ] ------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Fetch WCL Top 100 talent meta data")
    parser.add_argument("--env", action="store_true", help="Load credentials from .env file")
    parser.add_argument("--dry-run", action="store_true", help="Print Lua output without writing")
    args = parser.parse_args()

    if args.env:
        load_env_file()

    # Resolve credentials — support both naming conventions
    client_id = os.environ.get("WCL_CLIENT_ID") or os.environ.get("WLOGS_CLIENT_ID")
    client_secret = os.environ.get("WCL_CLIENT_SECRET") or os.environ.get("WLOGS_CLIENT_SECRET")

    if not client_id or not client_secret:
        print("Error: WCL_CLIENT_ID and WCL_CLIENT_SECRET must be set", file=sys.stderr)
        sys.exit(1)

    # 1. Authenticate
    print("Authenticating with Warcraft Logs...")
    token = get_auth_token(client_id, client_secret)
    print("Authenticated.")

    # 2. Discover classes, specs, encounters
    class_specs, raid_encounters, mplus_encounters = discover_metadata(token)

    if not raid_encounters:
        print("Error: No encounters found for expansion", EXPANSION_ID, file=sys.stderr)
        sys.exit(1)

    batch_query_raid = build_batch_query(raid_encounters, use_bracket=False)

    # 4. Aggregate across all combinations
    # Structure: db[content][difficulty][class_slug][spec_slug] = {}
    meta_db = defaultdict(lambda: defaultdict(lambda: defaultdict(dict)))
    
    total_specs = sum(len(cls_data["specs"]) for cls_data in class_specs.values())
    processed = 0

    for class_slug, cls_data in sorted(class_specs.items()):
        class_name = cls_data["name"]
        for spec_info in cls_data["specs"]:
            spec_slug = spec_info["slug"]
            spec_name = spec_info["name"]
            processed += 1
            print(f"[{processed}/{total_specs}] {class_name}/{spec_name}...")

            # --- RAID COMBINATIONS ---
            for diff in RAID_DIFFICULTIES:
                diff_name = diff[0]
                results, logs = execute_combination_query(
                    token, batch_query_raid, class_slug, spec_slug, raid_encounters, diff, is_mplus=False
                )
                for content_key, pct_map in results.items():
                    meta_db[content_key][diff_name][class_slug][spec_slug] = pct_map
                time.sleep(REQUEST_DELAY)
                
            # --- MYTHIC+ PER-DUNGEON ---
            # Each dungeon is a single encounter in WCL's "Mythic+ Season X" zone
            for enc in mplus_encounters:
                single_query = build_batch_query([enc], use_bracket=False)
                diff_info = (enc["name"], MPLUS_DIFFICULTY, 0)
                results, logs = execute_combination_query(
                    token, single_query, class_slug, spec_slug, [enc], diff_info, is_mplus=True
                )
                for content_key, pct_map in results.items():
                    meta_db[content_key]["Mythic+"][class_slug][spec_slug] = pct_map
                time.sleep(REQUEST_DELAY)

    # 5. Generate and write
    lua_content = build_lua(meta_db)

    if args.dry_run:
        print("\n--- DRY RUN OUTPUT ---")
        print(lua_content)
    else:
        write_output(lua_content)
        print("Done.")

if __name__ == "__main__":
    main()
