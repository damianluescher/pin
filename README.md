# Pin

A Mac app for designing and reviewing apps on a canvas. Boards are not pictures: each one runs the app's real code (SwiftUI views or a web page), so what you see is what ships. You pin comments on a board, an AI agent changes the code, and the board refreshes by itself.

## What it does

- **Live boards.** A board shows a real screen of your app in a chosen state, built from the app's own source with made-up data (`Live/<App>`).
- **Comments.** Click a spot, write what should change. Comments are stored as plain files an agent can read and answer.
- **Run panel.** The real app (iOS simulator) or website (dev server, phone/tablet/desktop widths) runs beside the canvas.
- **Auto refresh.** Rebuild a board library and the open canvas picks it up within about two seconds.

## Layout

- `Sources/Pin` – the Mac app (SwiftUI)
- `Sources/PinCore` – the shared file store
- `Sources/pincli` – the `pin` command for agents
- `Live/` – board libraries for individual apps (examples)
- `scripts/install.sh` – build and install `Pin.app`

## Build

Needs macOS 14+ and Xcode / Swift 5.9.

```sh
swift build -c release
./scripts/install.sh
```
