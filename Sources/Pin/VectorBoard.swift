import AppKit
import SwiftUI

/// Sharp text and shapes on boards copied from a design file: the part in view is drawn fresh from the board's vector
/// file (a PDF beside its picture) at the current zoom, with some spare around it so moving stays sharp.
struct VectorBoard: View {
    let file: URL
    /// Where the board sits on screen right now.
    let rect: CGRect
    /// The board's own size, in its points.
    let design: CGSize
    /// The canvas on screen.
    let frame: CGRect
    let zoom: CGFloat

    private struct Shot { let image: CGImage; let region: CGRect; let zoom: CGFloat }
    @State private var shot: Shot?
    @Environment(\.displayScale) private var backing

    var body: some View {
        let visible = visiblePart
        let ready = shot.map { $0.zoom == zoom && $0.region.contains(visible) } ?? false
        ZStack(alignment: .topLeading) {
            if let shot {
                Image(decorative: shot.image, scale: 1).resizable().interpolation(.high)
                    .frame(width: shot.region.width * zoom, height: shot.region.height * zoom)
                    .position(x: (shot.region.midX) * zoom, y: (shot.region.midY) * zoom)
            }
        }
        .frame(width: rect.width, height: rect.height, alignment: .topLeading)
        .clipped()
        .position(x: rect.midX, y: rect.midY)
        .allowsHitTesting(false)
        .task(id: ready ? "ready" : "\(zoom) \(visible)") {
            guard !ready else { return }
            try? await Task.sleep(for: .milliseconds(90))
            guard !Task.isCancelled else { return }
            let spare = visible.insetBy(dx: -frame.width / zoom / 2, dy: -frame.height / zoom / 2)
                .intersection(CGRect(origin: .zero, size: design))
            let file = file, design = design, zoom = zoom, density = zoom * backing
            let image = await Task.detached(priority: .userInitiated) { Self.draw(file, design: design, region: spare, density: density) }.value
            guard !Task.isCancelled, let image else { return }
            shot = Shot(image: image, region: spare, zoom: zoom)
        }
    }

    /// The part of the board on screen, in its own points.
    private var visiblePart: CGRect {
        let seen = rect.intersection(frame)
        guard !seen.isNull, zoom > 0 else { return .zero }
        return CGRect(x: (seen.minX - rect.minX) / zoom, y: (seen.minY - rect.minY) / zoom, width: seen.width / zoom, height: seen.height / zoom)
    }

    private nonisolated static func draw(_ file: URL, design: CGSize, region: CGRect, density: CGFloat) -> CGImage? {
        guard !region.isEmpty, let document = CGPDFDocument(file as CFURL), let page = document.page(at: 1),
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(data: nil, width: Int(region.width * density), height: Int(region.height * density), bitsPerComponent: 8, bytesPerRow: 0,
                                      space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let box = page.getBoxRect(.mediaBox)
        context.interpolationQuality = .high
        context.scaleBy(x: density, y: density)
        // PDF's origin is at the bottom: place the board so `region` fills the picture.
        context.translateBy(x: -region.minX, y: region.maxY - design.height)
        context.scaleBy(x: design.width / box.width, y: design.height / box.height)
        context.translateBy(x: -box.minX, y: -box.minY)
        context.drawPDFPage(page)
        return context.makeImage()
    }
}
