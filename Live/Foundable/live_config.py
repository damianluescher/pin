#!/usr/bin/env python3
"""Writes <Pin home>/Foundable/live.json: every board in boards.json runs from dist/index.html#board=<id>."""
import json, os, sys
here = os.path.dirname(os.path.abspath(__file__))
home = os.path.join(sys.argv[1], 'Foundable')
web = {}
for board in json.load(open(os.path.join(here, 'src/boards.json'))):
    if not os.path.isdir(os.path.join(home, board)):
        sys.exit('No such board in Pin: ' + board)
    w, h = (402, 874) if board.startswith('iphone-') else (1280, 820)
    web[board] = {'url': 'file://' + here.replace(' ', '%20') + '/dist/index.html#board=' + board, 'width': w, 'height': h, 'persistent': False}
tmp = os.path.join(home, 'live.json.tmp')
with open(tmp, 'w') as f: json.dump({'web': web}, f, indent=1)
os.replace(tmp, os.path.join(home, 'live.json'))
print(len(web), 'Foundable boards live')
