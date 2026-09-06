import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        applyDockIcon()
    }

    private func applyDockIcon() {
        guard let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
              let icon = NSImage(contentsOf: iconURL)
        else {
            print("FinanceTracker: AppIcon.icns could not be loaded from the app bundle")
            return
        }

        icon.isTemplate = false
        NSApplication.shared.applicationIconImage = icon
        NSApplication.shared.dockTile.display()
    }
}

@main
struct FinanceTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = FinanceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1080, minHeight: 720)
        }
        .defaultSize(width: 1280, height: 820)
        .windowStyle(.automatic)
    }
}
