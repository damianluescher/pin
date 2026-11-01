#!/usr/bin/env python3
"""Writes <Pin home>/Wink/live.json from the board table in Boards.swift, with each board's size from its picture."""
import json, os, pathlib, re, struct, sys
here = pathlib.Path(__file__).parent
home = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path.home() / "Library/Application Support/Pin"
ids = re.findall(r'"([a-z0-9-]+)"', " ".join(re.findall(r'^\s*case ("[a-z].*?):', (here / "Sources/WinkBoards/Shim/Boards.swift").read_text(), re.M)))
sizes = {}
for b in ids:
    with open(home / "Wink" / b / "v1.png", "rb") as f:
        f.read(16); w, h = struct.unpack(">II", f.read(8))
    scale = 3 if b.startswith(("iphone", "new-iphone")) else 2
    sizes[b] = {"width": w / scale, "height": h / scale}
config = {"library": str(here / ".build/debug/libWinkBoards.dylib"), "size": {"width": 1280, "height": 820},
          "sizes": {b: s for b, s in sizes.items() if s != {"width": 1280, "height": 820}}, "boards": {b: b for b in ids}}
(home / "Wink/live.json").write_text(json.dumps(config, indent=1))
print(len(ids), "live boards")
