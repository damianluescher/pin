#!/usr/bin/env python3
"""Makes Generated/ from wink2's own files. Each change is one that keeps a board from reaching outside itself."""
import pathlib, re
app = pathlib.Path.home() / "tools/wink2/App"
out = pathlib.Path(__file__).parent / "Sources/WinkBoards/Generated"
out.mkdir(exist_ok=True)

def cut(text, start, end):
    """Takes out everything from `start` up to, not including, `end`; a missing mark stops the build."""
    a = text.index(start)
    return text[:a] + text[text.index(end, a):]

def must(text, old, new):
    if old not in text: raise SystemExit(f"sync.py: wink2 changed, not found: {old}")
    return text.replace(old, new)

NO_MONITOR = ("NSEvent.addLocalMonitorForEvents(", "NoEvents.addLocalMonitorForEvents(")
files = {
    # No engine: the real connection is gone from the build, Shim/FakeEngine.swift has its name.
    "Model.swift": lambda t: cut(t, "struct API: Sendable {", "@MainActor @Observable final class AppModel"),
    # No app of its own, and settings that cannot be saved.
    "Wink2.swift": lambda t: cut(cut(t, "@main\nstruct Wink2App", "/// Snapshot runs can read"), "/// Snapshot runs can read", "enum Theme {"),
    # A key or mouse watcher would take Pin's Return, Escape and right click.
    "Design.swift": lambda t: must(t, *NO_MONITOR),
    "Reply.swift": lambda t: must(t, *NO_MONITOR),
    "Review.swift": lambda t: must(must(t, *NO_MONITOR), "NSApp.keyWindow?.makeFirstResponder(nil)", "_ = ()"),
    # A box that takes the keyboard would take it from Pin's comment box.
    "Composer.swift": lambda t: must(t, "focused = true", "_ = true"),
}
for name, change in files.items():
    (out / name).write_text(f"// Made by sync.py from wink2/App/{name}. Do not edit; edit the original.\n" + change((app / name).read_text()))
