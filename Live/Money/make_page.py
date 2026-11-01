#!/usr/bin/env python3
"""Money's real page, changed in two places: the head (no-network rule, invented data, stand-in) and where icons come from.
WebKit refuses mask pictures from file: addresses, so the icons go in as data: addresses. Stops if a line it relies on moved."""
import base64, glob, json, os, sys
src, out = sys.argv[1:]
page = open(src, encoding='utf-8').read()
CSP = "default-src 'none'; script-src 'unsafe-inline' file:; style-src 'unsafe-inline'; img-src file: data:; font-src file:; connect-src 'none'; form-action 'none'; base-uri 'none'"
HEAD = f'<meta http-equiv="Content-Security-Policy" content="{CSP}"><script src="invented.js"></script><script src="standin.js"></script>'
if page.count('<head>') != 1 or "fetch('/data')" not in page:
    sys.exit("Money's page changed: check how it reads its data before using it here")
if 'data.json' in page:
    sys.exit('The page names data.json: stop')
ICON = 'url(icons/${g}.svg)'
if page.count(ICON) != 1:
    sys.exit("Money's page changed: check how it draws icons")
icons = {os.path.basename(f)[:-4]: 'data:image/svg+xml;base64,' + base64.b64encode(open(f, 'rb').read()).decode()
         for f in glob.glob(os.path.join(os.path.dirname(src), 'icons', '*.svg'))}
HEAD += f'<script>window.MONEY_ICONS={json.dumps(icons)}</script>'
page = page.replace(ICON, 'url(${window.MONEY_ICONS[g]})')
open(out, 'w', encoding='utf-8').write(page.replace('<head>', '<head>' + HEAD))
