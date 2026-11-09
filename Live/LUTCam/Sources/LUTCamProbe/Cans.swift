import AppKit
import SceneKit
import SwiftUI
import UniformTypeIdentifiers
import LUTCamBoards

/// LUTCamProbe cans FOLDER: one photo-real can per film stock (4Roll's cans are 3D renders). The 4Roll label art
/// (LUT Cam's Canister drawing) is flattened, wrapped round a SceneKit cylinder with metal rims and a knob, lit by a
/// soft studio light, and saved as can-<stock>.png (transparent, 600 × 1025 px).
@MainActor
enum CanRender {
    static func run(_ folder: String) {
        let out = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        for (id, flat) in LUTCamBoards.flatCans {
            guard let label = labelTexture(flat) else { print("FAILED label \(id)"); continue }
            let image = render(label: label)
            let url = out.appendingPathComponent("can-\(id).png")
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil), let image else { continue }
            CGImageDestinationAddImage(dest, image, nil)
            print(CGImageDestinationFinalize(dest) ? "ok can-\(id) \(image.width)x\(image.height)" : "FAILED \(id)")
        }
    }

    /// The flat label: the drawing's body (side strip, print band, label) cut out, placed on the front half of a
    /// texture whose back half is the dark side of the can.
    static func labelTexture(_ flat: AnyView) -> CGImage? {
        let r = ImageRenderer(content: flat.frame(width: 120, height: 205))
        r.scale = 8
        guard let full = r.cgImage else { return nil }
        let s = CGFloat(full.width) / 120
        guard let body = full.cropping(to: CGRect(x: 0, y: 28 * s, width: 117 * s, height: 166 * s)) else { return nil }
        let w = body.width * 3, h = body.height
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 0.06, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.draw(body, in: CGRect(x: body.width, y: 0, width: body.width, height: h))
        return ctx.makeImage()
    }

    static func render(label: CGImage) -> CGImage? {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = studio()
        scene.lightingEnvironment.intensity = 1.3
        let radius: CGFloat = 1, height: CGFloat = 3.3
        let body = SCNCylinder(radius: radius, height: height)
        let side = SCNMaterial()
        side.lightingModel = .physicallyBased
        side.diffuse.contents = label
        side.roughness.contents = 0.38
        side.metalness.contents = 0.0
        side.clearCoat.contents = 0.6
        let cap = metal()
        body.materials = [side, cap, cap]
        let can = SCNNode(geometry: body)
        // Turn the label's front half towards the camera.
        can.eulerAngles.y = CGFloat(Double(ProcessInfo.processInfo.environment["CAN_TURN"] ?? "") ?? 0.45)
        scene.rootNode.addChildNode(can)
        for y in [height / 2, -height / 2] {
            let rim = SCNNode(geometry: SCNCylinder(radius: radius * 1.07, height: 0.16))
            rim.geometry?.materials = [metal()]
            rim.position = SCNVector3(0, y + (y > 0 ? 0.06 : -0.06), 0)
            scene.rootNode.addChildNode(rim)
        }
        let knob = SCNNode(geometry: SCNCylinder(radius: radius * 0.42, height: 0.34))
        knob.geometry?.materials = [metal(dark: true)]
        knob.position = SCNVector3(0, height / 2 + 0.3, 0)
        scene.rootNode.addChildNode(knob)

        let key = SCNNode(); key.light = SCNLight(); key.light!.type = .directional; key.light!.intensity = 900
        key.eulerAngles = SCNVector3(-0.5, -0.7, 0); scene.rootNode.addChildNode(key)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light!.type = .ambient; fill.light!.intensity = 250
        scene.rootNode.addChildNode(fill)

        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera!.fieldOfView = 14
        camera.camera!.wantsHDR = false
        camera.position = SCNVector3(0, 1.6, 17.5)
        camera.look(at: SCNVector3(0, 0.1, 0))
        scene.rootNode.addChildNode(camera)

        let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
        renderer.scene = scene
        renderer.pointOfView = camera
        renderer.autoenablesDefaultLighting = false
        let img = renderer.snapshot(atTime: 0, with: CGSize(width: 600, height: 1025), antialiasingMode: .multisampling4X)
        return img.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }

    static func metal(dark: Bool = false) -> SCNMaterial {
        let m = SCNMaterial()
        m.lightingModel = .physicallyBased
        m.diffuse.contents = NSColor(white: dark ? 0.25 : 0.7, alpha: 1)
        m.metalness.contents = 1.0
        m.roughness.contents = dark ? 0.45 : 0.22
        return m
    }

    /// A dark studio with one big soft window above-left and a thin strip on the right (the reflections on metal).
    static func studio() -> NSImage {
        let size = NSSize(width: 1024, height: 512)
        return NSImage(size: size, flipped: false) { rect in
            NSColor(white: 0.05, alpha: 1).setFill(); rect.fill()
            NSGradient(colors: [NSColor(white: 0.95, alpha: 1), NSColor(white: 0.05, alpha: 1)])?
                .draw(in: NSRect(x: 180, y: 260, width: 300, height: 200), relativeCenterPosition: .zero)
            NSColor(white: 0.7, alpha: 1).setFill(); NSRect(x: 760, y: 120, width: 26, height: 300).fill()
            return true
        }
    }
}
