#!/usr/bin/env python3
"""Copies a local Penpot file into Pin: every board as a picture on its page and at its place, flows, and all comments.
Safe to run again: boards and comments already copied are skipped, and boards he has moved in Pin stay where they are.
Draws in its own hidden Chrome, so it never touches the agents' window or the Penpot lock. Reads Penpot only.
Usage: uv run --with websocket-client penpot_import.py PENPOT_FILE [PIN_APP]"""
import base64, json, os, re, shutil, subprocess, sys, tempfile, time, urllib.request, websocket
sys.path.insert(0, os.path.expanduser('~/tools/penpot-local'))
import rpc
PORT, PIN = 9338, os.path.expanduser('~/.local/bin/pin')
HOME = os.environ.get('PIN_HOME') or os.path.expanduser('~/Library/Application Support/Pin')
ROOT = '00000000-0000-0000-0000-000000000000'
WEB_APPS = {'Foundable'}
name = sys.argv[1]; app = sys.argv[2] if len(sys.argv) > 2 else name
s = rpc.login('damian')
fid = next(f['id'] for f in s.call('get-project-files', projectId=s.me['defaultProjectId']) if f['name'] == name)
data = s.call('get-file', id=fid)['data']
pages = [(pid, data['pagesIndex'][pid]) for pid in data['pages']]
slug = lambda t: '-'.join(re.findall(r'[^\W_]+', t.lower()))
map_path = f'{HOME}/{app}/penpot.json'
ids = json.load(open(map_path)) if os.path.exists(map_path) else {}  # Penpot board id -> Pin screen id


def existing_screens():
    folder = f'{HOME}/{app}'
    out = {}
    if os.path.isdir(folder):
        for d in os.listdir(folder):
            p = f'{folder}/{d}/screen.json'
            if os.path.exists(p): out[d] = json.load(open(p))
    return out


def boards_of(page):
    ob = page['objects']
    return [ob[i] for i in ob[ROOT].get('shapes', []) if i in ob and ob[i]['type'] == 'frame']


def save_map():
    os.makedirs(os.path.dirname(map_path), exist_ok=True)
    json.dump(ids, open(map_path, 'w'), indent=1)


# Boards copied before this map existed are found by the source line written on them.
have = existing_screens()
by_source = {}
for sid, sc in sorted(have.items(), key=lambda kv: kv[1].get('order', 0)):
    by_source.setdefault(sc.get('source') or '', []).append(sid)
for pid, page in pages:
    for b in boards_of(page):
        src = f'Penpot: {name} / {page["name"]} / {b["name"]}'
        if b['id'] not in ids and by_source.get(src):
            ids[b['id']] = by_source[src].pop(0)
save_map()

todo = [(pid, page, b) for pid, page in pages for b in boards_of(page) if b['id'] not in ids]
done = fail = 0
if todo:
    work = tempfile.mkdtemp(prefix='pin-import-')
    chrome = subprocess.Popen(['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '--headless=new', f'--user-data-dir={work}/chrome', f'--remote-debugging-port={PORT}', '--remote-allow-origins=*', '--no-first-run', 'about:blank'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(3)
        t = [x for x in json.load(urllib.request.urlopen(f'http://127.0.0.1:{PORT}/json')) if x['type'] == 'page'][0]
        ws = websocket.create_connection(t['webSocketDebuggerUrl'], suppress_origin=True, timeout=120); i = [0]
        def cmd(m, **k):
            i[0] += 1; ws.send(json.dumps({'id': i[0], 'method': m, 'params': k}))
            while True:
                r = json.loads(ws.recv())
                if r.get('id') == i[0]: return r.get('result', r)
        ev = lambda e: cmd('Runtime.evaluate', expression=e, returnByValue=True)['result'].get('value')
        cmd('Network.setCookie', name='auth-token', value=s.token(), url=rpc.BASE, path='/')
        cmd('Emulation.setDefaultBackgroundColorOverride', color={'r': 0, 'g': 0, 'b': 0, 'a': 1})
        taken = set(have) | set(ids.values())
        for pid, page, b in todo:
            w, h = b['width'], b['height']
            narrow = w <= 500
            kind = 'iphone' if narrow else ('web' if name in WEB_APPS else 'mac')
            scale = 3 if narrow else 2
            title = b['name'].replace('/', '·').strip() or 'Board'
            if not slug(title): title = 'Board'
            if slug(title) in taken: title = f'{page["name"]} · {title}'
            base, n = title, 2
            while slug(title) in taken: title = f'{base} {n}'; n += 1
            cmd('Emulation.setDeviceMetricsOverride', width=int(w) + 2, height=int(h) + 2, deviceScaleFactor=scale, mobile=False)
            cmd('Page.navigate', url=f'{rpc.BASE}/render.html?file-id={fid}&page-id={pid}&object-id={b["id"]}&route=objects')
            for _ in range(60):
                time.sleep(.5)
                if ev("!!document.querySelector('svg[id^=screenshot]') && document.readyState==='complete'"): break
            else:
                print('did not draw:', page['name'], title, flush=True); fail += 1; continue
            time.sleep(1.5)
            shot = cmd('Page.captureScreenshot', format='png', captureBeyondViewport=True, clip=dict(x=0, y=0, width=w, height=h, scale=1))['data']
            out = f'{work}/b.png'; open(out, 'wb').write(base64.b64decode(shot))
            r = subprocess.run([PIN, 'add', app, title, out, '--kind', kind, '--page', page['name'], '--source', f'Penpot: {name} / {page["name"]} / {b["name"]}'], capture_output=True, text=True)
            if r.returncode: print('failed:', title, r.stderr, flush=True); fail += 1; continue
            sid = slug(title)
            subprocess.run([PIN, 'place', app, sid, str(b['x']), str(b['y'])], check=True)
            ids[b['id']] = sid; taken.add(sid); done += 1; save_map()
            print(page['name'], '|', title, kind, flush=True)
    finally:
        chrome.terminate(); time.sleep(1); shutil.rmtree(work, ignore_errors=True)

# Flows: real prototype links, then the arrows drawn by hand ("Flow line" groups between two boards).
links = set()
for pid, page in pages:
    ob = page['objects']; bs = [b for b in boards_of(page) if b['id'] in ids]
    for shape in ob.values():
        for it in shape.get('interactions') or []:
            dest = it.get('destination'); owner = shape
            while owner and owner['id'] not in ids and owner['id'] != ROOT:
                owner = ob.get(owner.get('parentId'))
            if dest in ids and owner and owner['id'] in ids and owner['id'] != dest:
                links.add((ids[owner['id']], ids[dest]))
    for sid in ob[ROOT].get('shapes', []):
        g = ob.get(sid)
        if not g or g['type'] != 'group' or 'flow' not in g['name'].lower(): continue
        top, bottom = g['y'] - 8, g['y'] + g['height'] + 8
        overlaps = lambda b: b['y'] < bottom and b['y'] + b['height'] > top
        left = [b for b in bs if overlaps(b) and abs(b['x'] + b['width'] - g['x']) < 60]
        right = [b for b in bs if overlaps(b) and abs(b['x'] - (g['x'] + g['width'])) < 60]
        for a in left[:1]:
            for c in right:
                links.add((ids[a['id']], ids[c['id']]))
for a, c in sorted(links):
    subprocess.run([PIN, 'flow', app, a, c], capture_output=True)

# Comments, with their real authors, dates, replies and done state. Each Pin thread keeps Penpot's id, so reruns skip it.
threads = s.call('get-comment-threads', fileId=fid)
copied = skipped = moved = 0
clean = lambda t: re.sub(r'[​﻿]', '', t or '').strip()
stamp = lambda d: re.sub(r'\.\d+', '', d)
for th in threads:
    page = data['pagesIndex'].get(th['pageId'])
    if not page: print('comment on a page that is gone:', th['id'], flush=True); skipped += 1; continue
    ob = page['objects']; p = th['position']
    boards = [b for b in boards_of(page) if b['id'] in ids]
    if not boards: print('comment with no board:', th['id'], flush=True); skipped += 1; continue
    inside = lambda b: b['x'] <= p['x'] <= b['x'] + b['width'] and b['y'] <= p['y'] <= b['y'] + b['height']
    owner = ob.get(th.get('frameId'))
    while owner and owner['id'] not in ids and owner['id'] != ROOT:
        owner = ob.get(owner.get('parentId'))
    if not (owner and owner['id'] in ids and inside(owner)):
        hit = [b for b in boards if inside(b)]
        def gap(b):
            dx = max(b['x'] - p['x'], 0, p['x'] - b['x'] - b['width']); dy = max(b['y'] - p['y'], 0, p['y'] - b['y'] - b['height'])
            return dx * dx + dy * dy
        owner = hit[-1] if hit else (owner if owner and owner['id'] in ids else min(boards, key=gap))
        if not hit: moved += 1; print('comment beside a board, pinned to its nearest edge:', page['name'], '|', ids[owner['id']], flush=True)
    screen = ids[owner['id']]
    folder = f'{HOME}/{app}/{screen}/threads'; path = f'{folder}/{th["id"]}.json'
    if os.path.exists(path): skipped += 1; continue
    x = min(max((p['x'] - owner['x']) / owner['width'], 0), 1); y = min(max((p['y'] - owner['y']) / owner['height'], 0), 1)
    msgs = [{'id': c['id'], 'author': c.get('ownerFullname') or 'Damian', 'text': clean(c['content']), 'at': stamp(c['createdAt'])}
            for c in sorted(s.call('get-comments', threadId=th['id']), key=lambda c: c['createdAt'])]
    msgs = [m for m in msgs if m['text']]
    if not msgs: skipped += 1; continue
    os.makedirs(folder, exist_ok=True)
    tmp = path + '.tmp'
    json.dump({'id': th['id'], 'app': app, 'screen': screen, 'version': 1, 'x': x, 'y': y, 'resolved': bool(th.get('isResolved')), 'created': msgs[0]['at'], 'messages': msgs}, open(tmp, 'w'), ensure_ascii=False, indent=1)
    os.replace(tmp, path); copied += 1
print(f'DONE {app}: boards added {done}, failed {fail}, flows {len(links)}, comments copied {copied}, already there or empty {skipped}, beside a board {moved}, of {len(threads)}')
