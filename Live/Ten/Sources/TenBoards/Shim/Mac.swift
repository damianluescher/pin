import SwiftUI
import AVKit
import AVFoundation
@_exported import UserNotifications
@_exported import AppKit
import AppKit

// iPhone-only calls in 10's screens, given a Mac meaning so the same code compiles unchanged.
typealias UIImage = NSImage

extension Image {
    init(uiImage: NSImage) { self.init(nsImage: uiImage) }
}

extension ToolbarPlacement {
    static var navigationBar: ToolbarPlacement { .automatic }
}

enum TenDebug {
    static func start(model: AppModel, repo: Repository) {}
    static func armAlarmSoon(_ alarm: TenAlarm) {}
}

final class UIApplication {
    static let shared = UIApplication()
    static let openSettingsURLString = "x-apple.systempreferences:"
    var isIdleTimerDisabled = false
    func open(_ url: URL) {}
}

final class UIImpactFeedbackGenerator {
    enum Style { case light, medium, heavy }
    init(style: Style) {}
    func impactOccurred() {}
    func prepare() {}
}

final class UINotificationFeedbackGenerator {
    enum FeedbackType { case success, warning, error }
    func notificationOccurred(_ type: FeedbackType) {}
    func prepare() {}
}

/// Exercise clips and pictures come straight from the app's folder.
enum VideoCatalog {
    private static let folder = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("tools/noop2/StrandiOS/Ten/Clips")
    static func clipURL(_ exerciseID: String) -> URL? { existing(exerciseID, "mp4") }
    static func posterURL(_ exerciseID: String) -> URL? { existing(exerciseID, "jpg") }
    private static func existing(_ id: String, _ ext: String) -> URL? {
        let url = folder.appendingPathComponent(id).appendingPathExtension(ext)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}

/// The exercise clip, on a Mac layer, same behaviour as the app's.
struct TenDemoClip: NSViewRepresentable {
    let exerciseID: String
    var isPaused = false
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        return view
    }
    func updateNSView(_ view: AVPlayerView, context: Context) {
        if context.coordinator.current != exerciseID, let url = VideoCatalog.clipURL(exerciseID) {
            context.coordinator.current = exerciseID
            let item = AVPlayerItem(url: url)
            let player = AVQueuePlayer(playerItem: item)
            player.isMuted = true
            context.coordinator.looper = AVPlayerLooper(player: player, templateItem: item)
            view.player = player
        }
        if isPaused { view.player?.pause() } else { view.player?.play() }
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    final class Coordinator {
        var current: String?
        var looper: AVPlayerLooper?
    }
}

extension View {
    /// The Mac has no full-screen cover: on a board it simply fills the board.
    func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View {
        overlay { if isPresented.wrappedValue { content() } }
    }
}
