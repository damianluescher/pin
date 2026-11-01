import AppKit
// Pin's icon: one white pin on near black.
let out = CommandLine.arguments[1]
for (name, px) in [("16",16),("16@2x",32),("32",32),("32@2x",64),("128",128),("128@2x",256),("256",256),("256@2x",512),("512",512),("512@2x",1024)] {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let inset = s * 0.09
    NSColor(white: 0.07, alpha: 1).setFill()
    NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset), xRadius: s * 0.19, yRadius: s * 0.19).fill()
    let r = s * 0.17, cx = s * 0.5, cy = s * 0.57
    let pin = NSBezierPath()
    pin.appendArc(withCenter: NSPoint(x: cx, y: cy), radius: r, startAngle: -30, endAngle: 210)
    pin.line(to: NSPoint(x: cx, y: s * 0.26))
    pin.close()
    NSColor.white.setFill()
    pin.fill()
    NSColor(white: 0.07, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: cx - r * 0.38, y: cy - r * 0.38, width: r * 0.76, height: r * 0.76)).fill()
    NSGraphicsContext.current = nil
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name)x\(name.replacingOccurrences(of: "@2x", with: "")).png".replacingOccurrences(of: "@2xx", with: "x").replacingOccurrences(of: "x\(name.replacingOccurrences(of: "@2x", with: "")).png", with: "x\(name.replacingOccurrences(of: "@2x", with: ""))\(name.hasSuffix("@2x") ? "@2x" : "").png")))
}
