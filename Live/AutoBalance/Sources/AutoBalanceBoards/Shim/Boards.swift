import SwiftUI
import AppKit

/// What stands in for the worker on a board.
enum BoardWorker {
    /// Read at run time so the compiler keeps the code after it; always true.
    static var never: Bool { ProcessInfo.processInfo.processIdentifier != 0 }
    static let finishedStays = 3600.0 * 24 * 365
}

private func still(_ name: String) -> String { "/Users/damian/tools/pin/Live/AutoBalance/Fixtures/\(name).jpg" }

/// A made-up shot. No clip, frame or grade of his is read: the pictures are drawn figures in Fixtures/.
private func shot(_ id: String, _ look: String, status: String = "Balanced", method: String = "Subject match", note: String = "", reference: Bool = false,
                  applied: Bool = false, failed: Bool = false, exposure: Double? = nil, group: String? = nil, wb: [Double]? = nil, why: String? = nil) -> Shot {
    var made = Shot(id: id, name: id + ".MP4", status: status, method: method, note: note, reference: reference, applied: applied, failed: failed, exposure: exposure)
    made.groupID = group
    made.thumbnailPath = still(look)
    made.whiteBalance = wb
    made.exposureNote = why
    if applied { made.previewBefore = still(look); made.previewAfter = still("balanced") }
    return made
}

/// Cuts of one camera sharing a result fold into one row, so a group gets that many shots.
private func cuts(_ count: Int, _ make: (String) -> Shot) -> [Shot] { (0..<count).map { make($0 == 0 ? "" : "-\($0)") } }

private func named(_ base: String, _ suffix: String) -> String { base + suffix }

private enum Run { case ready, measuring, stoppingEarly, results, all, stopped }

private let unreliable = "Couldn’t find a reliable colour reference. Review this shot in Resolve."
private let unconfirmed = "The correction could not be confirmed, so the grade was left alone."
private let stoppedNote = "Stopped before this shot was balanced."

private func timeline(_ run: Run) -> [Shot] {
    func row(_ base: String, _ look: String, cut: Int = 1, stops: Double, wb: [Double]?, why: String? = nil, fail: String? = nil) -> [Shot] {
        cuts(cut) { suffix in
            let id = named(base, suffix)
            switch run {
            case .ready:
                return shot(id, look, status: "Ready", reference: base == "C0012", group: "g" + base)
            case .measuring:
                return shot(id, look, status: "Waiting", group: "g" + base)
            case .stoppingEarly:
                return shot(id, look, status: "Analyzed", exposure: stops, group: "g" + base)
            case .stopped where fail != nil || ["C0047", "DJI_0051"].contains(base):
                return shot(id, look, status: "Stopped", note: stoppedNote, failed: true, group: "g" + base)
            case .results, .stopped:
                if let fail { return shot(id, look, status: "Not changed", method: "", note: fail, failed: true, group: "g" + base) }
                return shot(id, look, applied: true, exposure: stops, group: "g" + base, wb: wb, why: why)
            case .all:
                return shot(id, look, applied: true, exposure: fail == nil ? stops : (base == "C0045" ? 0.9 : -0.2), group: "g" + base, wb: wb ?? [-0.05, 0, 0.05], why: why)
            }
        }
    }
    return row("C0012", "warm", cut: 4, stops: -0.4, wb: [0.06, 0, -0.05], why: "Darkened 0.4 stops to match this person’s skin across 4 shots.")
        + row("C0031", "cool", cut: 3, stops: 0.7, wb: [-0.05, 0, 0.06], why: "Brightened 0.7 stops to match this person’s skin across 3 shots.")
        + row("DJI_0042", "bright", stops: -1.2, wb: [-0.03, 0.05, -0.03], why: "Darkened 1.2 stops to match the shots around it.")
        + row("C0045", "dark", stops: 0, wb: nil, fail: unreliable)
        + row("C0047", "plain", stops: 0, wb: nil, why: "Kept in step with its reference shot.")
        + row("DJI_0051", "green", stops: 0.3, wb: [-0.05, 0.03, 0.01], why: "Brightened 0.3 stops to match the shots around it.")
        + row("C0058", "pink", stops: 0, wb: nil, fail: unconfirmed)
        // Below the fold on the boards; it brings the tally to their 13 shots, 11 balanced.
        + row("C0061", "plain", stops: 0.1, wb: nil, why: "Kept in step with its reference shot.")
}

@MainActor
enum AutoBalanceBoards {
    private struct Spec {
        var dark = false
        var opened: String?
        /// The worker's "busy" flag and how far it says it is.
        var busy = false
        var quietFor: Double?
        var setup: (Model) -> Void = { _ in }
    }

    private static func measuring(_ model: Model, active: String, measured: Int, stage: String, progress: Double) {
        var shots = timeline(.measuring)
        let rows = ["C0012", "C0031", "DJI_0042", "C0045", "C0047", "DJI_0051", "C0058"]
        for index in shots.indices {
            let base = shots[index].id.components(separatedBy: "-")[0]
            let place = rows.firstIndex(of: base) ?? 0
            if base == active {
                shots[index] = shot(shots[index].id, lookOf(base), status: "Matching", group: "g" + base)
            } else if place < measured {
                shots[index] = shot(shots[index].id, lookOf(base), status: "Analyzed", exposure: stopsOf(base), group: "g" + base)
            }
        }
        model.shots = shots
        model.selection = active
        model.stage = stage
        model.progress = progress
    }

    private static func lookOf(_ base: String) -> String { ["C0012": "warm", "C0031": "cool", "DJI_0042": "bright", "C0045": "dark", "C0047": "plain", "DJI_0051": "green", "C0058": "pink"][base] ?? "plain" }
    private static func stopsOf(_ base: String) -> Double { ["C0012": -0.4, "C0031": 0.7, "DJI_0042": -1.2, "DJI_0051": 0.3][base] ?? 0 }

    /// The rows balanced so far, the rest measured, as a run looks while it is writing to Resolve.
    private static func applying(_ model: Model, stage: String, progress: Double) {
        var shots = timeline(.results)
        let later = ["C0045", "C0047", "DJI_0051", "C0058", "C0061"]
        for index in shots.indices where later.contains(shots[index].id) {
            let base = shots[index].id
            shots[index] = shot(base, lookOf(base), status: "Analyzed", exposure: stopsOf(base), group: "g" + base)
        }
        model.shots = shots
        model.selection = "C0045"
        model.stage = stage
        model.progress = progress
    }

    private static func results(_ model: Model) { model.shots = timeline(.results); model.selection = "C0012" }

    private static let selectedRows: [Shot] = {
        cuts(2) { shot(named("C0012", $0), "warm", status: "Ready", reference: true, group: "gC0012") }
            + [shot("DJI_0042", "bright", status: "Ready"), shot("DJI_0051", "green", status: "Ready")]
    }()

    private static func spec(_ board: String) -> Spec {
        switch board {
        case "starting-reading-resolve":
            return Spec(busy: true, setup: { $0.stage = "Reading clip status"; $0.timeline = "Reading Resolve"; $0.progress = 0 })
        case "ready-timeline": return Spec(setup: { $0.shots = timeline(.ready) })
        case "ready-selected-shots": return Spec(setup: { $0.scope = "selected"; $0.shots = selectedRows })
        case "no-shots-timeline": return Spec()
        case "no-shots-selected-shots": return Spec(setup: { $0.scope = "selected" })

        case "measuring": return Spec(busy: true, setup: { measuring($0, active: "DJI_0042", measured: 2, stage: "Comparing camera colour", progress: 0.38) })
        case "measuring-dark": return Spec(dark: true, busy: true, setup: { measuring($0, active: "DJI_0042", measured: 2, stage: "Comparing camera colour", progress: 0.38) })
        case "applying": return Spec(busy: true, setup: { applying($0, stage: "Grade verified · 8 of 11", progress: 0.93) })
        case "no-answer-from-resolve": return Spec(busy: true, quietFor: 12, setup: { applying($0, stage: "Applying and verifying in Resolve", progress: 0.9) })
        case "stopping": return Spec(busy: true, setup: { applying($0, stage: "Stopping · finishing the current safe step", progress: 0.93); $0.stopping = true })
        case "stopped": return Spec(setup: { $0.shots = timeline(.stopped); $0.stage = "Stopped · review completed corrections in Resolve" })
        case "results": return Spec(setup: results)
        case "results-dark": return Spec(dark: true, setup: results)
        case "finished-11-of-13":
            return Spec(setup: { results($0); $0.scope = "selected"; $0.completion = BalanceResult(balanced: 11, total: 13, incomplete: 2, seconds: 68.6) })
        case "finished-all-balanced":
            return Spec(setup: { $0.shots = timeline(.all); $0.completion = BalanceResult(balanced: 13, total: 13, incomplete: 0, seconds: 41.2) })
        case "finished-nothing-balanced":
            return Spec(setup: {
                $0.scope = "selected"
                $0.shots = [shot("C0045", "dark", status: "Not changed", method: "", note: unreliable, failed: true),
                            shot("C0058", "pink", status: "Not changed", method: "", note: unconfirmed, failed: true)]
                $0.completion = BalanceResult(balanced: 0, total: 2, incomplete: 2, seconds: 9.8)
            })

        case "opened-balanced", "opened-before-and-after": return Spec(opened: "C0012", setup: results)
        case "opened-balanced-dark": return Spec(dark: true, opened: "C0012", setup: results)
        case "opened-exposure-only":
            return Spec(opened: "C0047", setup: { model in
                results(model)
                if let index = model.shots.firstIndex(where: { $0.id == "C0047" }) {
                    model.shots[index] = shot("C0047", "plain", method: "Scene estimate", applied: true, exposure: 0, group: "gC0047", why: "Kept in step with its reference shot.")
                }
            })
        case "opened-not-changed": return Spec(opened: "C0045", setup: results)

        case "resolve-is-not-running":
            return Spec(setup: { $0.scope = "selected"; $0.error = "DaVinci Resolve is not running. Start Resolve, then press Refresh shots."; $0.timeline = "Not connected to Resolve"; $0.stage = "Needs attention · Refresh to retry" })
        case "too-few-shots-selected":
            return Spec(setup: {
                $0.scope = "selected"
                $0.shots = [shot("C0012", "warm", status: "Ready", reference: true), shot("DJI_0042", "bright", status: "Ready")]
                $0.error = "Select at least two camera shots in Resolve, or choose Entire timeline."
            })
        case "worker-could-not-start":
            return Spec(setup: {
                $0.stage = "Worker could not start"; $0.timeline = "Not connected to Resolve"
                $0.error = "Could not launch PythonWorker: The file “PythonWorker” doesn’t exist. Click Refresh to retry. If this repeats, reinstall AutoBalance. Log: /Users/damian/Library/Application Support/AutoBalance/state/native.log"
            })
        case "worker-stopped":
            return Spec(setup: {
                results($0)
                $0.stage = "Stopped · Refresh to reconnect"
                $0.error = "Worker stopped (exit code 1). Last diagnostic: RuntimeError: Cannot seek Resolve preview at 01:00:12:04 Click Refresh to reconnect. Log: /Users/damian/Library/Application Support/AutoBalance/state/native.log"
            })
        default: return Spec()
        }
    }

    static func board(_ name: String) -> AnyView {
        let spec = spec(name)
        let model = Model()
        model.scope = "timeline"
        model.timeline = "Interview Edit v03"
        model.stage = "Ready"
        spec.setup(model)
        return AnyView(BoardScene(spec: (spec.dark, spec.opened, spec.busy, spec.quietFor), model: model))
    }

    /// Runs ContentView as the app does. A busy board turns busy just after it appears, the way a run starts, so its clock
    /// runs, and keeps "hearing" from the worker so it does not start saying Resolve is quiet.
    private struct BoardScene: NSViewRepresentable {
        let spec: (dark: Bool, opened: String?, busy: Bool, quiet: Double?)
        let model: Model

        final class Host: NSHostingView<AnyView> {
            override var acceptsFirstResponder: Bool { false }
            override func performKeyEquivalent(with event: NSEvent) -> Bool { false }
        }

        func makeNSView(context: Context) -> Host {
            model.boardOpened = spec.opened
            let screen = ContentView(model: model)
                .task {
                    guard spec.busy else { return }
                    model.busy = true
                    while !Task.isCancelled {
                        model.lastWorkerResponse = Date().addingTimeInterval(-(spec.quiet ?? 0))
                        try? await Task.sleep(for: .seconds(2))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(Tidal.canvas)
                .overlay(alignment: .topLeading) { WindowDots() }
                .environment(\.colorScheme, spec.dark ? .dark : .light)
            let host = Host(rootView: AnyView(EmptyView()))
            host.sizingOptions = []
            host.appearance = NSAppearance(named: spec.dark ? .darkAqua : .aqua)
            host.rootView = AnyView(screen)
            return host
        }

        func updateNSView(_ host: Host, context: Context) {}
    }

    private struct WindowDots: View {
        var body: some View {
            HStack(spacing: 8) {
                Circle().fill(Color(red: 1, green: 0.37, blue: 0.34))
                Circle().fill(Color(red: 1, green: 0.74, blue: 0.18))
                Circle().fill(Color(red: 0.16, green: 0.78, blue: 0.25))
            }
            .frame(width: 52, height: 12)
            .padding(.leading, 18).padding(.top, 20)
            .allowsHitTesting(false)
        }
    }
}

/// Pin's way in: a live board by name, as a pointer to its view. Pin owns the pointer afterwards.
@_cdecl("pin_board")
public func pinBoard(_ name: UnsafePointer<CChar>) -> UnsafeMutableRawPointer {
    MainActor.assumeIsolated {
        let view = UnsafeMutablePointer<AnyView>.allocate(capacity: 1)
        view.initialize(to: AutoBalanceBoards.board(String(cString: name)))
        return UnsafeMutableRawPointer(view)
    }
}
