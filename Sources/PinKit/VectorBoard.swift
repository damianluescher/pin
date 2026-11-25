import AppKit

/// Sharp text and shapes on boards copied from a design file: the part in view is drawn fresh from the board's vector
/// file (a PDF beside its picture) at the current zoom, with some spare around it so moving stays sharp.
enum VectorBoard {
    nonisolated static func draw(_ file: URL, design: CGSize, region: CGRect, density: CGFloat) -> CGImage? {
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
