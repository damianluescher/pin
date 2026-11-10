#!/usr/bin/env python3
"""Gives every live LUT Cam board in Pin a fresh picture (Pin shows it when zoomed out or while zooming).
Damian, 10 Nov 2026: "sometimes it doesnt update" - the pictures were from 9 Nov, the code had moved on.
Usage: refresh-pictures.py RENDER_FOLDER  (made by LUTCamProbe render). A new file name each time: Pin caches by name."""
import json, os, re, shutil, sys, time
src = sys.argv[1]
home = os.path.expanduser('~/Library/Application Support/Pin/LUT Cam')
stamp = time.strftime('%m%d%H%M%S')
done = 0
for f in sorted(os.listdir(src)):
    if not f.endswith('.png'): continue
    sid = re.sub(r'[()]', '', f[:-4])
    folder = os.path.join(home, sid); meta = os.path.join(folder, 'screen.json')
    if not os.path.exists(meta): print('no board', sid); continue
    j = json.load(open(meta)); v = j['versions'][-1]; old = v.get('file')
    name = f'shot-{stamp}.png'
    shutil.copy(os.path.join(src, f), os.path.join(folder, name))
    v['file'] = name
    tmp = meta + '.tmp'; json.dump(j, open(tmp, 'w'), indent=2); os.replace(tmp, meta)
    if old and old.startswith('shot-') and old != name and os.path.exists(os.path.join(folder, old)): os.remove(os.path.join(folder, old))
    done += 1
print(f'pictures refreshed: {done}')
