import SwiftUI

@main
struct PosterFrameDemoApp: App {
    @NSApplicationDelegateAdaptor(DemoApplicationDelegate.self)
    private var applicationDelegate

    var body: some Scene {
        WindowGroup("PosterFrameKit") {
            DemoContentView()
        }
        .defaultSize(width: 1_100, height: 780)
    }
}
