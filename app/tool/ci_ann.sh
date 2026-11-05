#!/bin/bash
# usage: ci_ann.sh RUN_ID [chars]  -- prints the annotations of a run (needs GH_TOKEN)
T="${GH_TOKEN:?set GH_TOKEN to the GitHub token}"
JID=$(curl -s -H "Authorization: Bearer $T" https://api.github.com/repos/godswisdomv1/Postzera/actions/runs/$1/jobs | python3 -c "import sys,json;print(json.load(sys.stdin)['jobs'][0]['id'])")
curl -s -H "Authorization: Bearer $T" "https://api.github.com/repos/godswisdomv1/Postzera/check-runs/$JID/annotations?per_page=100" | python3 -c "
import sys,json
n=${2:-3500}
for a in json.load(sys.stdin):
    t=a.get('title') or ''; m=a['message']
    if 'details' in t or 'error •' in m or 'warning •' in m:
        i=m.find('EXCEPTION'); print((m[i:i+n] if i>=0 else m[:n])); print('=====')"
