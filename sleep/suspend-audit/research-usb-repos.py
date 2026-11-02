#!/usr/bin/env python3
"""Read-only GitHub research; writes only project evidence files."""
import concurrent.futures, json, pathlib, urllib.request, urllib.parse
out = pathlib.Path('sleep/suspend-audit/usb-repo-research'); out.mkdir(exist_ok=True)
queries = {
 'mbp-usb': 'repo:Dunedan/mbp-2016-linux USB',
 'mbp-thunderbolt': 'repo:Dunedan/mbp-2016-linux thunderbolt',
 'mbp-hotplug': 'repo:Dunedan/mbp-2016-linux hotplug',
 'mbp-ethernet': 'repo:Dunedan/mbp-2016-linux ethernet',
 'audio-usb': 'repo:davidjo/snd_hda_macbookpro USB',
 'audio-thunderbolt': 'repo:davidjo/snd_hda_macbookpro thunderbolt',
}
def fetch(task):
 name, url = task
 try:
  req = urllib.request.Request(url, headers={'User-Agent':'macbook-fedora-readonly-audit','Accept':'application/vnd.github+json'})
  with urllib.request.urlopen(req, timeout=40) as r: data=r.read()
  (out/(name+'.json')).write_bytes(data)
  return name, json.loads(data)
 except Exception as e:
  print(name, 'ERROR', e); return name, {}
tasks=[(n,'https://api.github.com/search/issues?q='+urllib.parse.quote(q)+'&per_page=100') for n,q in queries.items()]
issues={}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for name,data in pool.map(fetch,tasks):
  print(name, 'total',data.get('total_count'))
  for i in data.get('items',[]):
   issues[i['url']]=i
   print(i['html_url'],i['title'])
tasks=[]
for url,i in issues.items():
 repo=url.split('/repos/')[1].split('/issues/')[0].replace('/','-'); prefix=f'{repo}-{i["number"]}'
 (out/(prefix+'-issue.json')).write_text(json.dumps(i,indent=2))
 if i.get('comments'): tasks.append((prefix+'-comments',url+'/comments?per_page=100'))
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
 for name,data in pool.map(fetch,tasks):
  if isinstance(data,list): print(name,len(data),'comments fetched (first page)')
