import SwiftUI

@main
struct TidyUpApp: App {
    init() {
        // Google Mobile Ads (test IDs in DEBUG; real IDs are TODOs for release).
        // Safe to call before the UI appears; no-ops gracefully offline.
        AdsManager.shared.configure()
        // Warms the StoreKit product cache and current entitlements.
        _ = StoreManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
