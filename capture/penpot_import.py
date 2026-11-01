#!/usr/bin/env python3
"""Copies every board of a local Penpot file into Pin, one Pin page per Penpot page, each board where it sits in Penpot.
Draws them in its own hidden Chrome, so it never touches the agents' window or the Penpot lock. Reads Penpot only.
Usage: uv run --with websocket-client penpot_import.py PENPOT_FILE [PIN_APP]"""
import base64, json, os, re, shutil, subprocess, sys, tempfile, time, urllib.request, urllib.error, zipfile, websocket
sys.path.insert(0, os.path.expanduser('~/tools/penpot-local'))
import rpc
PORT, PIN = 9338, os.path.expanduser('~/.local/bin/pin')
ROOT = '00000000-0000-0000-0000-000000000000'
name = sys.argv[1]; app = sys.argv[2] if len(sys.argv) > 2 else name
s = rpc.login('damian')
fid = next(f['id'] for f in s.call('get-project-files', projectId=s.me['defaultProjectId']) if f['name'] == name)
work = tempfile.mkdtemp(prefix='pin-import-')
req = urllib.request.Request(rpc.BASE + '/api/main/methods/export-binfile', json.dumps({'fileId': fid, 'version': 3, 'includeLibraries': False, 'embedAssets': False}).encode(), {'content-type': 'application/json', 'accept': 'text/event-stream'})
uri = re.findall(r'https?://[^"\s\\]+', s.o.open(req, timeout=300).read().decode())[-1]
open(f'{work}/f.zip', 'wb').write(s.o.open(uri, timeout=300).read())
z = zipfile.ZipFile(f'{work}/f.zip'); pages = {}; shapes = {}
for n in z.namelist():
    m = re.match(r'files/[^/]+/pages/([^/]+)\.json$', n)
    if m: pages[m[1]] = json.loads(z.read(n))
    m = re.match(r'files/[^/]+/pages/([^/]+)/([^/]+)\.json$', n)
    if m: shapes.setdefault(m[1], {})[m[2]] = json.loads(z.read(n))
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
    existing = {l.split('\t')[0] for l in subprocess.run([PIN, 'screens', app], capture_output=True, text=True).stdout.splitlines()}
    done = fail = 0; ids = {}
    for pid in sorted(pages, key=lambda p: pages[p].get('index', 0)):
        page = pages[pid]['name']; sh = shapes[pid]
        for sid in sh[ROOT].get('shapes', []):
            b = sh.get(sid)
            if not b or b.get('type') != 'frame': continue
            w, h = b['width'], b['height']
            kind, scale = ('iphone', 3) if w <= 500 else ('mac', 2)
            title = b['name'].replace('/', '·').strip() or 'Board'
            slug = re.sub(r'[^\w]+', '-', title.lower()).strip('-')
            if slug in existing or slug in ids.values():
                title = f'{page} · {title}'; slug = re.sub(r'[^\w]+', '-', title.lower()).strip('-')
            cmd('Emulation.setDeviceMetricsOverride', width=int(w) + 2, height=int(h) + 2, deviceScaleFactor=scale, mobile=False)
            cmd('Page.navigate', url=f'{rpc.BASE}/render.html?file-id={fid}&page-id={pid}&object-id={sid}&route=objects')
            for _ in range(60):
                time.sleep(.5)
                if ev("!!document.querySelector('svg[id^=screenshot]') && document.readyState==='complete'"): break
            else:
                print('did not draw:', page, title, flush=True); fail += 1; continue
            time.sleep(1.5)
            d = cmd('Page.captureScreenshot', format='png', captureBeyondViewport=True, clip=dict(x=0, y=0, width=w, height=h, scale=1))['data']
            out = f'{work}/b.png'; open(out, 'wb').write(base64.b64decode(d))
            r = subprocess.run([PIN, 'add', app, title, out, '--kind', kind, '--page', page, '--source', f'Penpot: {name} / {page} / {b["name"]}'], capture_output=True, text=True)
            if r.returncode: print('failed:', title, r.stderr, flush=True); fail += 1; continue
            subprocess.run([PIN, 'place', app, title, str(b['x']), str(b['y'])], check=True)
            ids[sid] = slug; done += 1; print(page, '|', title, kind, flush=True)
    links = 0
    for pid, sh in shapes.items():
        for shape in sh.values():
            for it in shape.get('interactions') or []:
                dest = it.get('destination')
                owner = shape
                while owner and owner.get('id') not in ids and owner.get('parentId') != ROOT and owner.get('id') != ROOT:
                    owner = sh.get(owner.get('parentId'))
                if dest in ids and owner and owner.get('id') in ids and owner['id'] != dest:
                    subprocess.run([PIN, 'flow', app, ids[owner['id']], ids[dest]]); links += 1
    print(f'DONE boards {done}, failed {fail}, flow steps {links}, pages {len(pages)}')
finally:
    chrome.terminate(); time.sleep(1); shutil.rmtree(work, ignore_errors=True)
