import AppKit

@MainActor
final class DemoApplicationDelegate: NSObject, NSApplicationDelegate {
    static var applicationIcon: NSImage? {
        guard let iconURL = Bundle.module.url(
            forResource: "PosterFrameDemoIcon",
            withExtension: "png"
        ) else {
            return nil
        }

        return NSImage(contentsOf: iconURL)
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.applicationIconImage = Self.applicationIcon
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            await Task.yield()

            let application = NSApplication.shared
            // A raw SwiftPM executable is not launched through Launch Services,
            // so cooperative activation alone cannot assume the current app
            // yielded focus to it.
            application.activate(ignoringOtherApps: true)
            application.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
