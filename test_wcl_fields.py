"""Dump all available fields from a WCL characterRankings entry."""
import os, json, requests, sys
from pathlib import Path

# Load .env
env_path = Path(__file__).parent / ".env"
if env_path.exists():
    for line in env_path.read_text().splitlines():
        if "=" in line and not line.startswith("#"):
            k, v = line.strip().split("=", 1)
            os.environ[k] = v

client_id = os.environ.get("WCL_CLIENT_ID")
client_secret = os.environ.get("WCL_CLIENT_SECRET")

# Auth
r = requests.post(
    "https://www.warcraftlogs.com/oauth/token",
    data={"grant_type": "client_credentials"},
    auth=(client_id, client_secret),
)
token = r.json()["access_token"]
headers = {"Authorization": f"Bearer {token}"}

# Query character rankings - get ALL fields
query = """
query {
  worldData {
    encounter(id: 2902) {
      characterRankings(
        className: "DeathKnight"
        specName: "Blood"
        metric: dps
        page: 1
        includeCombatantInfo: true
      )
    }
  }
}
"""

resp = requests.post(
    "https://www.warcraftlogs.com/api/v2/client",
    json={"query": query},
    headers=headers,
)

data = resp.json()
rankings = data["data"]["worldData"]["encounter"]["characterRankings"]["rankings"]

# Dump the FULL structure of the first entry
player = rankings[0]
print("=== TOP LEVEL KEYS ===")
print(list(player.keys()))
print()

# Print each key and its type/value
for key, val in player.items():
    if isinstance(val, list):
        print(f"  {key}: list[{len(val)}]")
        if val:
            print(f"    [0] keys: {list(val[0].keys()) if isinstance(val[0], dict) else val[0]}")
            print(f"    [0] full: {json.dumps(val[0], indent=6)}")
    elif isinstance(val, dict):
        print(f"  {key}: dict keys={list(val.keys())}")
        print(f"    full: {json.dumps(val, indent=6)}")
    else:
        print(f"  {key}: {type(val).__name__} = {val}")
