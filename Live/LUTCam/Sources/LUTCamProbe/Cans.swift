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
        // Print grain: fine light and dark specks over the whole label, like ink on tin (Damian, Pin 23 Nov: "looks cheap
        // maybe add grain texture so it feels a bit more realistic").
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<(w * h / 9) {
            let x = CGFloat(Int.random(in: 0..<w, using: &rng)), y = CGFloat(Int.random(in: 0..<h, using: &rng))
            ctx.setFillColor(CGColor(gray: Bool.random(using: &rng) ? 1 : 0, alpha: CGFloat.random(in: 0.04...0.1, using: &rng)))
            ctx.fill(CGRect(x: x, y: y, width: 2, height: 2))
        }
        return ctx.makeImage()
    }

    /// Brushed metal: fine horizontal streaks (rims and knob) in the roughness, so the light breaks like on a real can.
    static func brushed(_ size: Int = 512) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue) else { return nil }
        ctx.setFillColor(CGColor(gray: 0.3, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        for y in 0..<size {
            ctx.setFillColor(CGColor(gray: CGFloat.random(in: 0.12...0.5), alpha: 1))
            ctx.fill(CGRect(x: 0, y: y, width: size, height: 1))
        }
        return ctx.makeImage()
    }

    static func render(label: CGImage) -> CGImage? {
        let scene = SCNScene()
        scene.background.contents = NSColor.clear
        scene.lightingEnvironment.contents = studio()
        scene.lightingEnvironment.intensity = 0.7
        let radius: CGFloat = 1, height: CGFloat = 3.3
        let body = SCNCylinder(radius: radius, height: height)
        let side = SCNMaterial()
        side.lightingModel = .physicallyBased
        side.diffuse.contents = label
        // Printed tin under a gloss coat: the soft window and the edge strips run down it like on a real can.
        side.roughness.contents = 0.5
        side.metalness.contents = 0.0
        side.clearCoat.contents = 0.1
        side.clearCoatRoughness.contents = 0.45
        let cap = metal()
        body.materials = [side, cap, cap]
        let can = SCNNode(geometry: body)
        // Turn the label's front half towards the camera.
        can.eulerAngles.y = CGFloat(Double(ProcessInfo.processInfo.environment["CAN_TURN"] ?? "") ?? 0.3)
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

        // Product light (Damian, 23 Nov: "redesign of each film stock with better lighting"): a big soft key from the
        // front left shapes the cylinder (bright left, falling off to the right), a cool rim from behind on the right
        // draws the right edge out of the dark, a low warm fill keeps the shadow side readable; soft shadows.
        let key = SCNNode(); key.light = SCNLight(); key.light!.type = .spot
        key.light!.intensity = 1700; key.light!.spotOuterAngle = 70; key.light!.spotInnerAngle = 20
        key.light!.color = NSColor(red: 1, green: 0.97, blue: 0.92, alpha: 1)
        key.position = SCNVector3(-6, 4, 7); key.look(at: SCNVector3(0, 0, 0)); scene.rootNode.addChildNode(key)
        let rim = SCNNode(); rim.light = SCNLight(); rim.light!.type = .directional; rim.light!.intensity = 1400
        rim.light!.color = NSColor(red: 0.85, green: 0.92, blue: 1, alpha: 1)
        rim.position = SCNVector3(6, 2, -5); rim.look(at: SCNVector3(0, 0, 0)); scene.rootNode.addChildNode(rim)
        let fill = SCNNode(); fill.light = SCNLight(); fill.light!.type = .omni; fill.light!.intensity = 160
        fill.light!.color = NSColor(red: 1, green: 0.93, blue: 0.85, alpha: 1)
        fill.position = SCNVector3(5, -1, 8); scene.rootNode.addChildNode(fill)
        let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient; amb.light!.intensity = 15
        scene.rootNode.addChildNode(amb)

        let camera = SCNNode(); camera.camera = SCNCamera(); camera.camera!.fieldOfView = 14
        camera.camera!.wantsHDR = false
        camera.camera!.wantsExposureAdaptation = false
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
        m.roughness.contents = brushed() ?? (dark ? 0.45 : 0.22)
        m.roughness.intensity = dark ? 1.4 : 1.0
        return m
    }

    /// A dark studio with one big soft window above-left and a thin strip on the right (the reflections on metal).
    static func studio() -> NSImage {
        let size = NSSize(width: 1024, height: 512)
        return NSImage(size: size, flipped: false) { rect in
            NSColor(white: 0.03, alpha: 1).setFill(); rect.fill()
            // A tall softbox front left (the long highlight down the can and on the rims), a thin strip back right
            // (the rim's edge glint), a faint floor bounce.
            // The softbox sits behind the camera's left shoulder: it lights the metal rims, not the printed label.
            NSGradient(colors: [NSColor(white: 0.03, alpha: 1), NSColor(white: 0.9, alpha: 1), NSColor(white: 0.03, alpha: 1)])?
                .draw(in: NSRect(x: 560, y: 300, width: 160, height: 200), angle: 0)
            NSColor(white: 0.8, alpha: 1).setFill(); NSRect(x: 820, y: 110, width: 18, height: 320).fill()
            NSColor(white: 0.12, alpha: 1).setFill(); NSRect(x: 0, y: 0, width: 1024, height: 60).fill()
            return true
        }
    }
}
