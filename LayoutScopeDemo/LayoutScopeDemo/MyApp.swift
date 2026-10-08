import LayoutScope
import SwiftUI

@main struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .layoutScopeOverlay(hidden: false)
        }
    }
}
