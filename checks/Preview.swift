import SwiftUI
import AVKit

@main struct PreviewCheck {
    @MainActor static func main() {
        let application = NSApplication.shared
        application.setActivationPolicy(.accessory)
        let player = AVPlayer()
        let host = NSHostingView(rootView: NativeVideoPreview(player: player))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = host
        window.orderFrontRegardless()
        host.layoutSubtreeIfNeeded()
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        print("PASS: preview mounted and laid out")
        window.orderOut(nil)
    }
}
