#!/usr/bin/env python3
"""Makes Generated/ from AutoBalance's own files. The app's PythonWorker is what talks to DaVinci Resolve: it can never start here."""
import pathlib
native = pathlib.Path.home() / "Documents/ChatGPT/AutoBalance/tool/native"
out = pathlib.Path(__file__).parent / "Sources/AutoBalanceBoards/Generated"
out.mkdir(exist_ok=True)

def must(text, old, new):
    if old not in text: raise SystemExit(f"sync.py: AutoBalance changed, not found: {old}")
    return text.replace(old, new)

def model(t):
    # start() ends at its first guard, and with no worker every command stops at `let input`: nothing is run or written.
    t = must(t, "guard process?.isRunning != true else { return }", "if BoardWorker.never { return }")
    t = must(t, 'if command == "refresh", process?.isRunning != true { start(); return }', "")
    # The buttons look as they do with a worker connected.
    t = must(t, "process?.isRunning == true && !busy", "!busy")
    t = must(t, "    var shots: [Shot] = []\n", "    var shots: [Shot] = []\n    var boardOpened: String?\n")
    return t

def content(t):
    # A finished count stays on the board instead of stepping aside after six seconds.
    t = must(t, "try? await Task.sleep(for: .seconds(6))", "try? await Task.sleep(for: .seconds(BoardWorker.finishedStays))")
    # A row can start opened, per board.
    t = must(t, ".task { model.start() }", ".task { model.start(); if let row = model.boardOpened { expanded = row } }")
    return t

for name, change in {"Model.swift": model, "ContentView.swift": content}.items():
    (out / name).write_text(f"// Made by sync.py from AutoBalance/tool/native/{name}. Do not edit; edit the original.\n" + change((native / name).read_text()))
