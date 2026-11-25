import PinKit

// Pin as a separate app. Its canvas lives in PinKit, which Wink shows in its side panel too.
MainActor.assumeIsolated { PinKit.runApp() }
