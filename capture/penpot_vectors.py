#!/usr/bin/env python3
"""Saves each board Pin copied from Penpot as a vector PDF beside its picture (v1.pdf), so text and shapes stay sharp at any zoom.
Reads Penpot only, in its own hidden Chrome. Skips boards that already have one.
Usage: uv run --with websocket-client penpot_vectors.py PENPOT_FILE [PIN_APP] [--limit N]"""
import base64, json, os, shutil, subprocess, sys, tempfile, time, urllib.request, websocket
sys.path.insert(0, os.path.expanduser('~/tools/penpot-local'))
import rpc
PORT = 9339
HOME = os.environ.get('PIN_HOME') or os.path.expanduser('~/Library/Application Support/Pin')
args = [a for a in sys.argv[1:] if not a.startswith('--')]
limit = int(sys.argv[sys.argv.index('--limit') + 1]) if '--limit' in sys.argv else None
if limit is not None: args = [a for a in args if a != str(limit)]
name = args[0]; app = args[1] if len(args) > 1 else name
s = rpc.login('damian')
fid = next(f['id'] for f in s.call('get-project-files', projectId=s.me['defaultProjectId']) if f['name'] == name)
data = s.call('get-file', id=fid)['data']
ids = json.load(open(f'{HOME}/{app}/penpot.json'))
todo = []
for pid in data['pages']:
    ob = data['pagesIndex'][pid]['objects']
    for bid, sid in ids.items():
        if bid in ob and not os.path.exists(f'{HOME}/{app}/{sid}/v1.pdf'): todo.append((pid, ob[bid], sid))
todo = todo[:limit] if limit else todo
work = tempfile.mkdtemp(prefix='pin-vec-')
chrome = subprocess.Popen(['/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', '--headless=new', f'--user-data-dir={work}/c', f'--remote-debugging-port={PORT}', '--remote-allow-origins=*', '--no-first-run', 'about:blank'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
done = fail = 0
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
    for pid, b, sid in todo:
        w, h = b['width'], b['height']
        cmd('Emulation.setDeviceMetricsOverride', width=int(w) + 2, height=int(h) + 2, deviceScaleFactor=1, mobile=False)
        cmd('Page.navigate', url=f'{rpc.BASE}/render.html?file-id={fid}&page-id={pid}&object-id={b["id"]}&route=objects')
        for _ in range(60):
            time.sleep(.5)
            if ev("!!document.querySelector('svg[id^=screenshot]') && document.readyState==='complete'"): break
        else:
            print('did not draw:', sid, flush=True); fail += 1; continue
        time.sleep(1.5)
        ev("(()=>{const st=document.createElement('style');st.textContent='@page{margin:0}html,body{margin:0;padding:0;overflow:hidden}';document.head.appendChild(st)})()")
        r = cmd('Page.printToPDF', printBackground=True, paperWidth=w / 96, paperHeight=h / 96, marginTop=0, marginBottom=0, marginLeft=0, marginRight=0, pageRanges='1', preferCSSPageSize=False)
        if 'data' not in r: print('no pdf:', sid, r, flush=True); fail += 1; continue
        tmp = f'{HOME}/{app}/{sid}/v1.pdf.tmp'; open(tmp, 'wb').write(base64.b64decode(r['data'])); os.replace(tmp, tmp[:-4]); done += 1
        print(sid, flush=True)
finally:
    chrome.terminate(); time.sleep(1); shutil.rmtree(work, ignore_errors=True)
print(f'DONE {app}: vectors {done}, failed {fail}')
