import SwiftUI

@main
struct FinanceTrackerApp: App {
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
