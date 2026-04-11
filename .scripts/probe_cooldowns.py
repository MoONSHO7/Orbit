#!/usr/bin/env python3
# Probe WCL API for per-parse cooldown timeline data.
# Case study: Affliction Warlock, Imperator Averzian, Mythic, top 10 parses.
#
# Produces a per-parse timeline of every cooldown cast (major cooldowns only,
# filtered by cast-count heuristic — abilities cast <= 20x per parse on average
# are treated as cooldowns; anything cast more often is filler).
#
# Writes a sample Lua file so we can measure real file size and see the format.

import os
import sys
import json
import time
import requests
from collections import defaultdict
from pathlib import Path

# Force UTF-8 on stdout/stderr so non-ASCII player names don't blow up
# the Windows console (cp1252 by default).
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, Exception):
    pass

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
GRAPHQL_URL = "https://www.warcraftlogs.com/api/v2/client"
REPO_ROOT = Path(__file__).resolve().parent.parent

# Filter threshold: an ability is considered a "major cooldown" if its
# average casts-per-parse across the sample is at most this. Fillers are
# typically 40-200+ casts per parse; 30s+ CDs are <= ~13 in a 400s fight.
# 20 gives safety margin for 20s+ CDs that still count as "major-ish".
MAX_CASTS_PER_PARSE_AS_CD = 20

SAMPLE_SIZE = 10  # top N parses to pull


def load_env():
    p = REPO_ROOT / ".env"
    with open(p, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, _, v = line.partition("=")
            os.environ.setdefault(k.strip(), v.strip())


def auth():
    r = requests.post(
        TOKEN_URL,
        auth=(os.environ["WCL_CLIENT_ID"], os.environ["WCL_CLIENT_SECRET"]),
        data={"grant_type": "client_credentials"},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()["access_token"]


def gql(query, variables, token):
    r = requests.post(
        GRAPHQL_URL,
        headers={"Authorization": f"Bearer {token}", "Content-Type": "application/json"},
        json={"query": query, "variables": variables},
        timeout=120,
    )
    r.raise_for_status()
    data = r.json()
    if "errors" in data:
        raise RuntimeError(json.dumps(data["errors"], indent=2))
    return data["data"]


# [ QUERIES ] --------------------------------------------------------------------

RATE_QUERY = """
query Rate {
  rateLimitData { limitPerHour pointsSpentThisHour pointsResetIn }
}
"""

def check_rate(token, label=""):
    rl = gql(RATE_QUERY, {}, token)["rateLimitData"]
    print(f"  [rate] {label} spent={rl['pointsSpentThisHour']:.1f}/{rl['limitPerHour']}")
    return rl["pointsSpentThisHour"]


RANKINGS_QUERY = """
query Rankings($encId: Int!, $className: String!, $specName: String!, $difficulty: Int!) {
  worldData {
    encounter(id: $encId) {
      characterRankings(
        className: $className, specName: $specName, metric: dps,
        difficulty: $difficulty, page: 1, includeCombatantInfo: true
      )
    }
  }
}
"""

def get_parses(token, encounter_id, class_name, spec_name, difficulty=5):
    d = gql(RANKINGS_QUERY, {
        "encId": encounter_id, "className": class_name,
        "specName": spec_name, "difficulty": difficulty,
    }, token)
    wrapper = d["worldData"]["encounter"]["characterRankings"]
    return wrapper["rankings"] if wrapper else []


REPORT_INFO_QUERY = """
query ReportInfo($code: String!, $fightID: Int!) {
  reportData {
    report(code: $code) {
      masterData { actors(type: "Player") { id name } }
      fights(fightIDs: [$fightID]) { id startTime endTime }
    }
  }
}
"""

def get_report_info(token, code, fight_id, player_name):
    d = gql(REPORT_INFO_QUERY, {"code": code, "fightID": fight_id}, token)
    rep = d["reportData"]["report"]
    source_id = None
    for a in rep["masterData"]["actors"]:
        if a["name"] == player_name:
            source_id = a["id"]
            break
    fight = rep["fights"][0] if rep["fights"] else None
    return source_id, fight


EVENTS_QUERY = """
query Events($code: String!, $fightID: Int!, $sourceID: Int!, $startTime: Float!, $endTime: Float!) {
  reportData {
    report(code: $code) {
      events(
        fightIDs: [$fightID], sourceID: $sourceID, dataType: Casts,
        startTime: $startTime, endTime: $endTime
      ) { data nextPageTimestamp }
    }
  }
}
"""

def get_casts(token, code, fight_id, source_id, start_time, end_time):
    events = []
    cursor = start_time
    page_count = 0
    while cursor is not None and page_count < 10:
        d = gql(EVENTS_QUERY, {
            "code": code, "fightID": fight_id, "sourceID": source_id,
            "startTime": float(cursor), "endTime": float(end_time),
        }, token)
        er = d["reportData"]["report"]["events"]
        batch = er["data"] or []
        events.extend(batch)
        cursor = er.get("nextPageTimestamp")
        page_count += 1
    return events


# [ DATA EXTRACTION ] ------------------------------------------------------------

def extract_parse_timeline(casts, fight_start):
    """Return list of (ability_id, t_ms) tuples where t_ms is offset from fight
    start. Every cast event, unfiltered — we filter later once we know cast
    counts across the whole sample."""
    timeline = []
    for cast in casts:
        ability_id = cast.get("abilityGameID")
        ts = cast.get("timestamp")
        if ability_id is None or ts is None:
            continue
        timeline.append((ability_id, int(ts - fight_start)))
    return timeline


def filter_cooldowns(per_parse_timelines):
    """Identify which ability IDs qualify as "major cooldowns" based on average
    casts per parse across the sample. Returns a set of qualifying ability IDs."""
    totals = defaultdict(int)
    for timeline in per_parse_timelines:
        per_parse = defaultdict(int)
        for ability_id, _t in timeline:
            per_parse[ability_id] += 1
        for ability_id, count in per_parse.items():
            totals[ability_id] += count

    n = len(per_parse_timelines)
    if n == 0:
        return set()
    cooldowns = set()
    for ability_id, total in totals.items():
        avg = total / n
        if avg <= MAX_CASTS_PER_PARSE_AS_CD:
            cooldowns.add(ability_id)
    return cooldowns


# [ LUA OUTPUT ] -----------------------------------------------------------------

def render_lua_snippet(class_slug, spec_slug, boss_name, difficulty, per_parse_data):
    """Render a fragment of what the full CooldownMeta.lua would look like.

    Schema:
      Orbit.Data.CooldownMeta[boss][difficulty][class][spec] = {
          duration = {<ms1>, <ms2>, ...},  -- one per parse
          casts = {
              {<spell1>, <t1>, <spell2>, <t2>, ...},  -- parse 1 flat pairs
              {...},                                    -- parse 2
              ...
          },
      }
    """
    lines = []
    lines.append(f'-- [ {boss_name} / {difficulty} / {class_slug}/{spec_slug} ] --')
    lines.append(f'Orbit.Data.CooldownMeta = Orbit.Data.CooldownMeta or {{}}')
    lines.append(f'local bossTbl = Orbit.Data.CooldownMeta["{boss_name}"] or {{}}')
    lines.append(f'Orbit.Data.CooldownMeta["{boss_name}"] = bossTbl')
    lines.append(f'local diffTbl = bossTbl["{difficulty}"] or {{}}')
    lines.append(f'bossTbl["{difficulty}"] = diffTbl')
    lines.append(f'local classTbl = diffTbl["{class_slug}"] or {{}}')
    lines.append(f'diffTbl["{class_slug}"] = classTbl')
    lines.append(f'classTbl["{spec_slug}"] = {{')

    durations = [p["duration"] for p in per_parse_data]
    lines.append(f"    duration = {{{', '.join(str(d) for d in durations)}}},")
    lines.append("    casts = {")
    for parse in per_parse_data:
        flat = []
        for spell, t in parse["casts"]:
            flat.append(str(spell))
            flat.append(str(t))
        lines.append(f"        {{{', '.join(flat)}}},")
    lines.append("    },")
    lines.append("}")
    return "\n".join(lines)


# [ VISUALIZATION ] --------------------------------------------------------------

def render_ascii_timeline(per_parse_data, cooldown_ids, fight_max_ms):
    """Print an ASCII timeline of cooldown casts across parses."""
    width = 70
    print(f"\n  Timeline width = {width} chars = {fight_max_ms/1000:.0f}s")
    print(f"  Each row = one parse. Columns = time buckets. Markers = casts.")
    print("")

    for i, parse in enumerate(per_parse_data):
        grid = [" "] * width
        for spell, t in parse["casts"]:
            if spell not in cooldown_ids:
                continue
            col = int((t / fight_max_ms) * width)
            col = max(0, min(width - 1, col))
            if grid[col] == " ":
                grid[col] = "."
            elif grid[col] == ".":
                grid[col] = ":"
            else:
                grid[col] = "#"
        print(f"  [{i+1:>2}] |{''.join(grid)}|")
    print(f"       0s{' ' * (width - 6)}{fight_max_ms/1000:.0f}s")


# [ MAIN ] -----------------------------------------------------------------------

def main():
    load_env()
    print("Authenticating...")
    token = auth()
    print("Authenticated.")
    print("")

    start_points = check_rate(token, "initial")
    print("")

    print(f"Step 1: Fetching top {SAMPLE_SIZE} parses (Affliction Warlock / Imperator Averzian / Mythic)...")
    parses = get_parses(token, encounter_id=3176, class_name="Warlock", spec_name="Affliction", difficulty=5)
    parses = parses[:SAMPLE_SIZE]
    print(f"  Got {len(parses)} parses\n")

    print(f"Step 2: Fetching cast events for each parse...")
    print("")
    per_parse_data = []  # list of { duration, casts: [(spell, t_ms), ...] }

    for i, p in enumerate(parses):
        name = p.get("name", "?")
        amount = p.get("amount", 0)
        report = p.get("report", {})
        code = report.get("code")
        fight_id = report.get("fightID")
        duration = p.get("duration", 0)

        print(f"  [{i+1:>2}/{len(parses)}] {name:<15} {amount:>8.0f} DPS -- {code}/{fight_id}", end="")

        source_id, fight = get_report_info(token, code, fight_id, name)
        if source_id is None or not fight:
            print("  [SKIP]")
            continue

        fight_start = fight["startTime"]
        fight_end = fight["endTime"]
        t0 = time.time()
        casts = get_casts(token, code, fight_id, source_id, fight_start, fight_end)
        elapsed = time.time() - t0

        timeline = extract_parse_timeline(casts, fight_start)
        print(f"  {len(casts):>4} casts in {elapsed:>4.1f}s")

        per_parse_data.append({
            "rank": i + 1,
            "player": name,
            "duration": fight_end - fight_start,
            "timeline_full": timeline,  # all casts
        })

    end_points = check_rate(token, "\nafter events")
    total_cost = end_points - start_points
    print(f"  total points spent: {total_cost:.1f}")
    print("")

    # [ STEP 3: Filter to cooldowns ] ---------------------------------------
    print(f"Step 3: Filtering to major cooldowns (<= {MAX_CASTS_PER_PARSE_AS_CD} casts/parse avg)...")
    all_full_timelines = [p["timeline_full"] for p in per_parse_data]
    cooldown_ids = filter_cooldowns(all_full_timelines)
    print(f"  Identified {len(cooldown_ids)} major cooldown ability IDs")

    # Per-ability summary
    print(f"\n  {'ABILITY_ID':>12}  {'TOTAL':>6}  {'AVG/PARSE':>10}  CASTS_IN_TOP_PARSE")
    print(f"  {'-'*12}  {'-'*6}  {'-'*10}  {'-'*18}")
    ability_counts = defaultdict(int)
    for tl in all_full_timelines:
        for aid, _t in tl:
            ability_counts[aid] += 1
    cd_summary = [(aid, ability_counts[aid]) for aid in cooldown_ids]
    cd_summary.sort(key=lambda x: -x[1])
    for aid, total in cd_summary[:25]:
        avg = total / len(per_parse_data)
        parse_1_count = sum(1 for a, _t in all_full_timelines[0] if a == aid) if all_full_timelines else 0
        print(f"  {aid:>12}  {total:>6}  {avg:>10.2f}  {parse_1_count:>18}")

    # Build filtered per-parse data
    filtered = []
    for p in per_parse_data:
        filtered_casts = [(spell, t) for spell, t in p["timeline_full"] if spell in cooldown_ids]
        filtered_casts.sort(key=lambda x: x[1])
        filtered.append({
            "rank": p["rank"],
            "duration": p["duration"],
            "casts": filtered_casts,
        })

    total_cd_casts = sum(len(p["casts"]) for p in filtered)
    print(f"\n  Filtered cast total: {total_cd_casts} across {len(filtered)} parses")
    print(f"  Avg cooldown casts per parse: {total_cd_casts/len(filtered):.1f}")

    # [ STEP 4: ASCII timeline ] ---------------------------------------------
    print(f"\nStep 4: ASCII timeline preview")
    max_dur = max(p["duration"] for p in filtered)
    render_ascii_timeline(filtered, cooldown_ids, max_dur)

    # [ STEP 5: Lua output ] -------------------------------------------------
    print(f"\nStep 5: Generating Lua snippet...")
    lua = render_lua_snippet(
        class_slug="warlock", spec_slug="affliction",
        boss_name="Imperator Averzian", difficulty="Mythic",
        per_parse_data=filtered,
    )
    out_path = REPO_ROOT / ".scripts" / "cooldown_sample.lua"
    out_path.write_text(lua, encoding="utf-8")
    print(f"  Wrote {out_path} ({len(lua)} bytes)")
    print(f"  Preview (first 30 lines):")
    print("")
    for line in lua.splitlines()[:30]:
        print(f"    {line}")
    print("")

    # [ COST + SIZE PROJECTION ] ---------------------------------------------
    print("=" * 72)
    print("PROJECTIONS")
    print("=" * 72)
    per_parse_cost = total_cost / len(per_parse_data) if per_parse_data else 0
    bytes_per_combo = len(lua)
    print(f"Sample: 1 spec, 1 boss, {SAMPLE_SIZE} parses, Mythic only")
    print(f"  API cost:           {total_cost:.1f} points ({per_parse_cost:.2f}/parse)")
    print(f"  Lua file size:      {bytes_per_combo:,} bytes ({bytes_per_combo/1024:.1f} KB)")
    print(f"  Cooldown cast data: {total_cd_casts} cast records")
    print("")

    # 342 combos (38 specs x 9 bosses) for raid Mythic only
    RAID_COMBOS = 342
    raid_cost = RAID_COMBOS * (SAMPLE_SIZE * per_parse_cost + 2)
    raid_size = RAID_COMBOS * bytes_per_combo
    print(f"Scale to full raid Mythic, top {SAMPLE_SIZE}:")
    print(f"  {RAID_COMBOS} combos x {SAMPLE_SIZE} parses")
    print(f"  API cost:  ~{raid_cost:,.0f} points = ~{raid_cost/3600:.1f} hours @ 3600/hr")
    print(f"  File size: ~{raid_size:,} bytes (~{raid_size/1024/1024:.1f} MB)")
    print("")

    # Top 100
    TOP_100_FACTOR = 100 / SAMPLE_SIZE
    print(f"Scale to full raid Mythic, top 100:")
    print(f"  API cost:  ~{raid_cost * TOP_100_FACTOR:,.0f} points = ~{raid_cost * TOP_100_FACTOR/3600:.1f} hours")
    print(f"  File size: ~{raid_size * TOP_100_FACTOR/1024/1024:.1f} MB")
    print("")

    # Plus M+
    MPLUS_COMBOS = 304
    total_combos = RAID_COMBOS + MPLUS_COMBOS
    all_cost = total_combos * (SAMPLE_SIZE * per_parse_cost + 2)
    all_size = total_combos * bytes_per_combo
    print(f"Scale to full raid + M+, top {SAMPLE_SIZE}:")
    print(f"  {total_combos} combos")
    print(f"  API cost:  ~{all_cost:,.0f} points = ~{all_cost/3600:.1f} hours")
    print(f"  File size: ~{all_size/1024/1024:.1f} MB")
    print("")


if __name__ == "__main__":
    main()
