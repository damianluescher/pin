#!/usr/bin/env python3
"""Writes <Pin home>/Money/live.json. Size comes from each board's picture; t=57 holds the water still, as Money's own option."""
import json, os, struct, sys
here = os.path.dirname(os.path.abspath(__file__))
home = os.path.join(sys.argv[1], 'Money')
web = {}
for board, query in json.load(open(os.path.join(here, 'boards.json'))).items():
    with open(os.path.join(home, board, 'v1.png'), 'rb') as f:
        w, h = struct.unpack('>II', f.read(24)[16:24])
    scale = 3 if board.startswith('iphone-') else 2
    web[board] = {'url': 'file://' + here + '/dist/index.html?' + query + '&t=57', 'width': w // scale, 'height': h // scale, 'persistent': False}
tmp = os.path.join(home, 'live.json.tmp')
with open(tmp, 'w') as f: json.dump({'web': web}, f, indent=1)
os.replace(tmp, os.path.join(home, 'live.json'))
print(len(web), 'Money boards live')
