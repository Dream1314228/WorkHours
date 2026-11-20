#!/usr/bin/env python3
"""用 GitHub Git Data API 把本地 HEAD 推到 main。
沙盒里 git-over-https 会被中断（SSL EOF / 408），REST 反而稳定。
本地不需要有远程那个 commit 对象，用两边 tree 的 blob sha 对比。
用法: python3 tools/push_api.py
"""
import json, base64, subprocess, urllib.request

TOKEN = open('/mounts/Downloads/工作站/.ghtoken').read().strip()
API = 'https://api.github.com/repos/Dream1314228/WorkHours'

def req(method, path, data=None):
    body = json.dumps(data).encode() if data is not None else None
    r = urllib.request.Request(API + path, data=body, method=method)
    r.add_header('Authorization', 'Bearer ' + TOKEN)
    r.add_header('Accept', 'application/vnd.github+json')
    if body is not None:
        r.add_header('Content-Type', 'application/json')
    with urllib.request.urlopen(r, timeout=180) as resp:
        txt = resp.read().decode()
        return json.loads(txt) if txt.strip() else {}

def git(*args):
    return subprocess.run(['git', *args], capture_output=True, text=True, check=True).stdout

remote_sha = req('GET', '/git/ref/heads/main')['object']['sha']
base_tree = req('GET', f'/git/commits/{remote_sha}')['tree']['sha']
print('remote', remote_sha[:7])

remote = {}
page = req('GET', f'/git/trees/{base_tree}?recursive=1')
for e in page.get('tree', []):
    if e['type'] == 'blob':
        remote[e['path']] = e['sha']
while page.get('truncated'):
    page = req('GET', f"/git/trees/{base_tree}?recursive=1&page={len(remote)}")
    for e in page.get('tree', []):
        if e['type'] == 'blob':
            remote[e['path']] = e['sha']

local = {}
for line in git('ls-tree', '-r', 'HEAD').strip().split('\n'):
    meta, path = line.split('\t', 1)
    local[path] = meta.split()[2]

entries, up, deleted = [], 0, 0
for path, sha in local.items():
    if remote.get(path) == sha:
        continue
    raw = open(path, 'rb').read()
    b = req('POST', '/git/blobs', {"content": base64.b64encode(raw).decode(), "encoding": "base64"})
    entries.append({"path": path, "mode": "100644", "type": "blob", "sha": b['sha']})
    up += 1
for path in remote:
    if path not in local:
        entries.append({"path": path, "mode": "100644", "type": "blob", "sha": None})
        deleted += 1

print('changed', up, 'deleted', deleted)
if not entries:
    print('nothing to push')
    raise SystemExit(0)

tree = req('POST', '/git/trees', {"base_tree": base_tree, "tree": entries})
msg = git('log', '-1', '--format=%B').strip()
commit = req('POST', '/git/commits', {"message": msg, "tree": tree['sha'], "parents": [remote_sha]})
req('PATCH', '/git/refs/heads/main', {"sha": commit['sha'], "force": True})
print('pushed', commit['sha'])
