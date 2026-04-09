import os, requests
client_id = os.environ.get('WCL_CLIENT_ID')
client_secret = os.environ.get('WCL_CLIENT_SECRET')
r = requests.post('https://www.warcraftlogs.com/oauth/token', data={'grant_type': 'client_credentials'}, auth=(client_id, client_secret))
token = r.json().get('access_token')
q = """query { worldData { encounter(id: 2902) { characterRankings(className: "DeathKnight", specName: "Blood", metric: "dps", page: 1, includeCombatantInfo: true) } } }"""
resp = requests.post('https://www.warcraftlogs.com/api/v2/client', json={'query': q}, headers={'Authorization': 'Bearer ' + str(token)})
try:
    rankings = resp.json()['data']['worldData']['encounter']['characterRankings']['rankings']
    print('KEYS:', rankings[0].keys())
    if 'talents' in rankings[0] and isinstance(rankings[0]['talents'], list) and len(rankings[0]['talents']) > 0:
        print('TALENTS HAS THESE ITESM:', rankings[0]['talents'][0])
except Exception as e:
    print("Error:", e, resp.text)
