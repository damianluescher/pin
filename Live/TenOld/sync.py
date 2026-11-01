#!/usr/bin/env python3
"""Makes Generated/ from phone-renew's own files. Each change keeps a board inside itself on a Mac; no screen is redrawn."""
import pathlib
app = pathlib.Path.home() / "tools/phone-renew/src/Ten/App"
out = pathlib.Path(__file__).parent / "Sources/TenOldBoards/Generated"
out.mkdir(exist_ok=True)

def must(text, old, new):
    if old not in text: raise SystemExit(f"sync.py: phone-renew changed, not found: {old}")
    return text.replace(old, new)

def cut(text, start, end):
    a = text.index(start)
    return text[:a] + text[text.index(end, a):]

def bar(t, title):
    """A Mac toolbar would land on Pin's window: the same items are drawn inside the board."""
    t = must(t, ".navigationBarTitleDisplayMode(.inline)\n", "\n")
    t = must(t, f".navigationTitle({title})\n", "\n")
    t = must(t, ".toolbar {\n", f".boardToolbar(title: {title}) {{\n")
    return must(t, "ToolbarItem(placement:", "BoardToolbarItem(placement:")

def root(t):
    t = cut(t, "@main\nstruct TenApp", "struct RootView")  # no app of its own
    t = must(t, "TabView(selection: $tab)", "BoardTabView(selection: $tab)")  # a Mac TabView is tabs along the top
    t = must(t, ".tabItem {", ".boardTabItem {")
    return must(t, '.alert("Unfinished session"', '.boardAlertWithCancel("Unfinished session"')  # a Mac alert blocks Pin's window

def week(t):
    t = must(t, ".sheet(isPresented: $settingsOpen) { SettingsSheet() }", ".boardSheet(isPresented: $settingsOpen, top: 415) { SettingsSheet() }")
    return bar(t, '"Settings"')

def player(t):
    # The boards' pretend date must not reach the countdowns, which run on real time.
    t = must(t, "endsAt <= .now", "endsAt <= Date()")
    t = must(t, "phaseEndsAt = .now", "phaseEndsAt = Date()")
    return must(t, '.alert("End workout?"', '.boardAlert("End workout?"')

files = {
    "TenApp.swift": root,
    "WeekView.swift": week,
    "LibraryView.swift": lambda t: bar(t, "exercise.name"),
    "PlayerView.swift": player,
    # A share sheet could send something out of Pin: the button stays, it does nothing.
    "ProgressView.swift": lambda t: must(t, "ShareLink(item:", "BoardShareLink(item:"),
}
for name, change in files.items():
    (out / name).write_text(f"// Made by sync.py from phone-renew/src/Ten/App/{name}. Do not edit; edit the original.\n" + change((app / name).read_text()))
