#!/bin/bash
# usage: ci_wait.sh [chars]  -- waits for the "check" run of HEAD, prints analyzer and failing-test details (needs GH_TOKEN)
T="${GH_TOKEN:?set GH_TOKEN to the GitHub token}"
cd "$(git rev-parse --show-toplevel)"; SHA=$(git rev-parse HEAD)
for i in $(seq 1 16); do sleep 25
 curl -s -H "Authorization: Bearer $T" "https://api.github.com/repos/godswisdomv1/Postzera/actions/runs?head_sha=$SHA&event=push" > /tmp/r.json
 st=$(python3 -c "
import json
rs=[r for r in json.load(open('/tmp/r.json'))['workflow_runs'] if r['name']=='check']
print((rs[0]['status']+' '+str(rs[0]['conclusion'])+' '+str(rs[0]['id'])) if rs else 'none')")
 case "$st" in completed*) break;; esac
done; echo "$SHA $st"
RID=$(echo $st | awk '{print $3}')
JID=$(curl -s -H "Authorization: Bearer $T" https://api.github.com/repos/godswisdomv1/Postzera/actions/runs/$RID/jobs | python3 -c "import sys,json;print(json.load(sys.stdin)['jobs'][0]['id'])")
curl -s -H "Authorization: Bearer $T" "https://api.github.com/repos/godswisdomv1/Postzera/check-runs/$JID/annotations?per_page=80" | python3 -c "
import sys,json
for a in json.load(sys.stdin):
    m=a['message']; lv=a['annotation_level']
    if lv=='failure' or 'error •' in m or 'issues found' in m or '[E]' in m:
        print('['+lv+']',a['path'],a['start_line'],m[:${1:-1800}].replace('\n',' | '))
        print('------')"
