#!/usr/bin/env python3
"""Writes <Pin home>/Ten/live.json from the board table in Boards.swift. Guidelines boards are not in it: they stay pictures."""
import json, pathlib, re, sys
here = pathlib.Path(__file__).parent
home = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path.home() / "Library/Application Support/Pin"
ids = re.findall(r'"([a-z0-9-]+)"', " ".join(re.findall(r'^\s*case ("[a-z].*?):', (here / "Sources/TenOldBoards/Shim/Boards.swift").read_text(), re.M)))
config = {"library": str(here / ".build/debug/libTenOldBoards.dylib"), "size": {"width": 402, "height": 874}, "boards": {b: b for b in ids}}
(home / "Ten/live.json").write_text(json.dumps(config, indent=1))
print(len(ids), "live boards")
