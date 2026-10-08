import SwiftUI
import Playgrounds
import LayoutScope

struct ContentView: View {
    @Binding var windowOverlayHidden: Bool
    
    var body: some View {
        TabView {
            Tab("Window", systemImage: "square") {
                Toggle("Show overlay", isOn: $windowOverlayHidden)
                    .frame(width: 150)
            }

            Tab("View", systemImage: "inset.left.half.square.dashed.micro") {
                ViewOverlayTestView()
            }
        }
    }
}

struct ViewOverlayTestView: View {
    var body: some View {
        ZStack {
            Color.yellow.opacity(0.3)
                .viewLayoutScopeOverlay()
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 20)
                .fill(Color.red.opacity(0.3))
                .frame(width: 300, height: 300)
                .viewLayoutScopeOverlay()

        }
    }
}

#Preview {
    ContentView(windowOverlayHidden: .constant(true))
}

#Playground {
    _ = 1 + 2
}
