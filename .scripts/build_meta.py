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
REQUEST_DELAY = 0.5  # Seconds between batched queries (rate-limit courtesy)
M_PLUS_DIFFICULTY = 10
MYTHIC_RAID_DIFFICULTY = 5

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
OUTPUT_DIR = REPO_ROOT / "Orbit_MetaTalents_Data"
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
    encounters = []
    zones = world["expansion"]["zones"] if world["expansion"] else []
    for zone in zones:
        zone_name = zone["name"]
        if "beta" in zone_name.lower() or "ptr" in zone_name.lower():
            print(f"  Skipping beta zone: {zone_name}")
            continue
        for enc in zone.get("encounters", []):
            encounters.append({
                "id": enc["id"],
                "name": enc["name"],
                "zone": zone_name,
            })

    print(f"Discovered {len(class_specs)} classes, {len(encounters)} encounters")
    for enc in encounters:
        print(f"  {enc['zone']} > {enc['name']} (id: {enc['id']})")
    return class_specs, encounters

# [ BATCH RANKINGS QUERY ] --------------------------------------------------------

def build_batch_query(encounters):
    """Dynamically build a GraphQL query with aliased encounter rankings."""
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
        "  $difficulty: Int!\n"
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

def aggregate_spec(token, batch_query, class_slug, spec_slug, encounters, difficulty):
    """Fetch and tally talent pick-rates for one spec across all encounters."""
    metric = get_metric(spec_slug.lower())
    variables = {
        "className": class_slug,
        "specName": spec_slug,
        "metric": metric,
        "difficulty": difficulty,
    }

    data = graphql(batch_query, variables, token)
    world = data.get("data", {}).get("worldData", {})

    total_logs = 0
    talent_tally = defaultdict(int)

    for alias, enc_data in world.items():
        if not enc_data:
            continue
        rankings_wrapper = enc_data.get("characterRankings")
        if not rankings_wrapper:
            continue
        rankings = rankings_wrapper.get("rankings", [])
        for player in rankings:
            total_logs += 1
            for talent in player.get("talents", []):
                talent_tally[talent["talentID"]] += 1

    # Convert counts to percentages, filter noise
    result = {}
    if total_logs > 0:
        for spell_id, count in talent_tally.items():
            pct = round((count / total_logs) * 100, 1)
            if pct >= MIN_PICK_RATE:
                result[spell_id] = pct

    return result, total_logs

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

    for class_slug in sorted(meta_db.keys()):
        specs = meta_db[class_slug]
        wow_class = slug_to_wow(class_slug)
        lines.append(f'    ["{wow_class}"] = {{')
        for spec_slug in sorted(specs.keys()):
            talents = specs[spec_slug]
            wow_spec = slug_to_wow(spec_slug)
            lines.append(f'        ["{wow_spec}"] = {{')
            for spell_id in sorted(talents.keys()):
                pct = talents[spell_id]
                lines.append(f"            [{spell_id}] = {pct},")
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
    toc_path = OUTPUT_DIR / "Orbit_MetaTalents_Data.toc"
    if not toc_path.exists():
        toc_content = "\n".join([
            "## Interface: 120001, 120000",
            "## Title: Orbit - Meta Talents Data",
            "## Notes: Auto-generated WCL talent pick-rate data for Orbit.",
            "## Author: github-actions[bot]",
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
    class_specs, encounters = discover_metadata(token)

    if not encounters:
        print("Error: No encounters found for expansion", EXPANSION_ID, file=sys.stderr)
        sys.exit(1)

    # 3. Build the batched query template
    batch_query = build_batch_query(encounters)

    # 4. Aggregate across all specs
    meta_db = defaultdict(lambda: defaultdict(dict))
    total_specs = sum(len(cls_data["specs"]) for cls_data in class_specs.values())
    processed = 0

    for class_slug, cls_data in sorted(class_specs.items()):
        class_name = cls_data["name"]
        for spec_info in cls_data["specs"]:
            spec_slug = spec_info["slug"]
            spec_name = spec_info["name"]
            processed += 1
            print(f"[{processed}/{total_specs}] {class_name}/{spec_name}...", end=" ")

            talents, log_count = aggregate_spec(
                token, batch_query, class_slug, spec_slug,
                encounters, M_PLUS_DIFFICULTY,
            )

            if talents:
                meta_db[class_slug][spec_slug] = talents
                print(f"{log_count} logs, {len(talents)} talents")
            else:
                print(f"{log_count} logs, skipped (no data)")

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
