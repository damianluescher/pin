#!/usr/bin/env python3
"""Writes <Pin home>/Wink/live.json from the board table in Boards.swift, with each board's size from its picture."""
import json, os, pathlib, re, struct, sys
here = pathlib.Path(__file__).parent
home = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path.home() / "Library/Application Support/Pin"
ids = re.findall(r'"([a-z0-9-]+)"', " ".join(re.findall(r'^\s*case ("[a-z].*?):', (here / "Sources/WinkBoards/Shim/Boards.swift").read_text(), re.M)))
# Adds to what live.json already says and never takes away: boards named by a prefix in the table (playbooks, clean), a
# size set by hand and a board whose first picture is not there yet all stay. A board in the table with no folder in Pin
# is left out.
target = home / "Wink/live.json"
before = json.loads(target.read_text()) if target.exists() else {}
boards, sizes = dict(before.get("boards", {})), dict(before.get("sizes", {}))
for b in ids:
    picture = home / "Wink" / b / "v1.png"
    if not picture.exists(): continue
    if b not in boards:
        with open(picture, "rb") as f:
            f.read(16); w, h = struct.unpack(">II", f.read(8))
        scale = 3 if b.startswith(("iphone", "new-iphone")) else 2
        if (w / scale, h / scale) != (1280, 820): sizes[b] = {"width": w / scale, "height": h / scale}
    boards[b] = b
config = {"library": str(here / ".build/debug/libWinkBoards.dylib"), "size": {"width": 1280, "height": 820},
          "sizes": sizes, "boards": dict(sorted(boards.items()))}
target.write_text(json.dumps(config, indent=1))
print(len(boards), "live boards")
