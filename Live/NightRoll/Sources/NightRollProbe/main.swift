import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import NightRollBoards

// NightRollProbe render FOLDER [SCALE]  - writes every board as FOLDER/<board id>.png (Pin's v1.png when zoomed out)
// NightRollProbe json                   - prints the boards (id, name, page, size) and links as JSON for setup
//
// Renders with SwiftUI's ImageRenderer: no window, nothing shown on screen, nothing started.

let args = CommandLine.arguments.dropFirst()

MainActor.assumeIsolated {
    switch args.first {
    case "render":
        guard let folder = args.dropFirst().first else { fatalError("render FOLDER [SCALE]") }
        let scale = args.dropFirst(2).first.flatMap(Double.init) ?? 2
        let out = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for board in NightRollBoards.boards {
            let size = NightRollBoards.size(board.name)
            let renderer = ImageRenderer(content: NightRollBoards.board(board.name, still: true).frame(width: size.width, height: size.height))
            renderer.scale = scale
            renderer.proposedSize = ProposedViewSize(size)
            guard let image = renderer.cgImage else { print("FAILED \(board.id)"); continue }
            let url = out.appendingPathComponent("\(board.id).png")
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, image, nil)
            print(CGImageDestinationFinalize(dest) ? "ok \(board.id) \(image.width)x\(image.height)" : "FAILED \(board.id)")
        }
    case "json":
        let boards = NightRollBoards.boards.map { board -> [String: Any] in
            let size = NightRollBoards.size(board.name)
            return ["id": board.id, "name": board.name, "page": board.page, "width": size.width, "height": size.height, "col": board.col, "row": board.row]
        }
        let links = NightRollBoards.links.filter(\.drawn).map { ["from": $0.from, "label": $0.label, "to": $0.to] }
        let data = try! JSONSerialization.data(withJSONObject: ["boards": boards, "links": links], options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    default:
        print("NightRollProbe render FOLDER [SCALE] | json")
    }
}
