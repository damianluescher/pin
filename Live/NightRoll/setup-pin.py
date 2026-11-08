#!/usr/bin/env python3
"""Puts Night Roll's live boards into Pin (app "Night Roll"), page by page, with flows from Boards.swift's links.

Run after build.sh. Safe to run again: new boards are added, existing ones get a fresh picture under a new file name
(Pin caches pictures by name), positions and flows are rewritten for these boards only. Other boards in the file
(chapter C's Launch page) and their live.json "web" entries are kept as they are.
Usage: setup-pin.py [--home PIN_HOME]
"""
import json, os, shutil, subprocess, sys, tempfile, time

here = os.path.dirname(os.path.abspath(__file__))
home = sys.argv[sys.argv.index("--home") + 1] if "--home" in sys.argv else os.path.expanduser("~/Library/Application Support/Pin")
app = "Night Roll"
folder = os.path.join(home, app)
probe = os.path.join(here, ".build/debug/NightRollProbe")
library = os.path.join(here, ".build/debug/libNightRollBoards.dylib")
env = dict(os.environ, PIN_HOME=home)

data = json.loads(subprocess.check_output([probe, "json"]))
boards, links = data["boards"], data["links"]
shots = tempfile.mkdtemp(prefix="nr-pin-shots-")
subprocess.check_call([probe, "render", os.path.join(shots, "x3"), "3"], stdout=subprocess.DEVNULL)
subprocess.check_call([probe, "render", os.path.join(shots, "x2"), "2"], stdout=subprocess.DEVNULL)

def wide(b): return b["width"] > 500
stamp = time.strftime("%H%M%S")
positions_path = os.path.join(folder, "positions.json")

for order, b in enumerate(boards):
    picture = os.path.join(shots, "x2" if wide(b) else "x3", b["id"] + ".png")
    screen_dir = os.path.join(folder, b["id"])
    source = "App/UI (~/tools/nightroll, main), board \"%s\" in Live/NightRoll/Boards.swift" % b["name"]
    if not os.path.isdir(screen_dir):
        subprocess.check_call(["pin", "add", app, b["name"], picture, "--kind", "mac" if wide(b) else "iphone",
                               "--page", b["page"], "--source", source], env=env, stdout=subprocess.DEVNULL)
    else:
        meta_path = os.path.join(screen_dir, "screen.json")
        meta = json.load(open(meta_path))
        old = meta["versions"][0]["file"]
        new = "shot-%s.png" % stamp
        shutil.copy(picture, os.path.join(screen_dir, new))
        meta["versions"][0]["file"] = new
        json.dump(meta, open(meta_path, "w"), indent=2, sort_keys=True)
        if old != new and old.startswith("shot-"): os.remove(os.path.join(screen_dir, old))
    # The app's pages come before the Launch page: whole negative numbers keep them first.
    meta_path = os.path.join(screen_dir, "screen.json")
    meta = json.load(open(meta_path))
    meta["order"] = order - len(boards)
    meta["page"] = b["page"]
    json.dump(meta, open(meta_path, "w"), indent=2, sort_keys=True)

# Each page from 0,0: columns left to right, branch rows below, with room for the flow arrows between boards.
x_by_page = {}
for page in {b["page"] for b in boards}:
    on_page = [b for b in boards if b["page"] == page]
    col_w = max(b["width"] for b in on_page) + 160
    rows = sorted({b["row"] for b in on_page})
    row_y, y = {}, 0
    for r in rows:
        row_y[r] = y
        y += max(b["height"] for b in on_page if b["row"] == r) + 200
    for b in on_page:
        subprocess.check_call(["pin", "place", app, b["id"], str(b["col"] * col_w), str(row_y[b["row"]])], env=env)
    x_by_page[page] = len(on_page)

# Flows: the links of Boards.swift, replacing older ones between these boards.
ids = {b["id"] for b in boards}
flows_path = os.path.join(folder, "flows.json")
flows = json.load(open(flows_path)) if os.path.exists(flows_path) else []
flows = [f for f in flows if not (f["from"] in ids and f["to"] in ids)]
json.dump(flows, open(flows_path, "w"), indent=2)
for l in links:
    subprocess.check_call(["pin", "flow", app, l["from"], l["to"], "--label", l["label"]], env=env)

# live.json: read again right before writing so chapter C's "web" boards are kept.
live_path = os.path.join(folder, "live.json")
live = json.load(open(live_path)) if os.path.exists(live_path) else {}
live["library"] = library
live["size"] = {"width": 393, "height": 852}
live["boards"] = {b["id"]: b["name"] for b in boards}
live["sizes"] = {b["id"]: {"width": b["width"], "height": b["height"]} for b in boards if (b["width"], b["height"]) != (393, 852)}
tmp = live_path + ".tmp"
json.dump(live, open(tmp, "w"), indent=1)
os.replace(tmp, live_path)
shutil.rmtree(shots)
print("boards %d, links %d, pages %s, web kept %d" % (len(boards), len(links), sorted(x_by_page), len(live.get("web", {}))))
