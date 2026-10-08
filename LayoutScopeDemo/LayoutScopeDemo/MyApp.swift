import LayoutScope
import SwiftUI

@main struct MyApp: App {
    @State var overlayHidden: Bool = false
    var body: some Scene {
        WindowGroup {
            ContentView(windowOverlayHidden: $overlayHidden)
                .layoutScopeOverlay(hidden: overlayHidden)
        }
    }
}
