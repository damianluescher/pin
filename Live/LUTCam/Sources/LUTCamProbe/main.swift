import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import LUTCamBoards

// LUTCamProbe render FOLDER [SCALE]: writes every board as FOLDER/<board id>.png. No window, nothing started.
let args = CommandLine.arguments.dropFirst()
MainActor.assumeIsolated {
    guard args.first == "render", let folder = args.dropFirst().first else { print("LUTCamProbe render FOLDER [SCALE]"); return }
    let scale = args.dropFirst(2).first.flatMap(Double.init) ?? 2
    let out = URL(fileURLWithPath: folder, isDirectory: true)
    try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
    for board in LUTCamBoards.boards {
        let size = LUTCamBoards.size(board.name)
        let renderer = ImageRenderer(content: LUTCamBoards.board(board.name).frame(width: size.width, height: size.height))
        renderer.scale = scale
        renderer.proposedSize = ProposedViewSize(size)
        guard let image = renderer.cgImage else { print("FAILED \(board.id)"); continue }
        let url = out.appendingPathComponent("\(board.id).png")
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
        CGImageDestinationAddImage(dest, image, nil)
        print(CGImageDestinationFinalize(dest) ? "ok \(board.id) \(image.width)x\(image.height)" : "FAILED \(board.id)")
    }
}
