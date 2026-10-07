import SwiftUI
import UIKit

public extension View {
    /// Attach once to the root view inside each WindowGroup.
    /// Draws window diagnostics without affecting content layout; a no-op in release builds.
    func windowLayoutDebugOverlay(includeInactiveRegions: Bool = true) -> some View {
        #if DEBUG
            modifier(WindowLayoutDebugModifier(includeInactiveRegions: includeInactiveRegions))
        #else
            self
        #endif
    }
}

#if DEBUG
    private struct WindowLayoutDebugModifier: ViewModifier {
        let includeInactiveRegions: Bool
        @State private var hinge: LayoutDebugHingeState = .initial
        @State private var cornerRadii = RectangleCornerRadii()

        func body(content: Content) -> some View {
            content.frame(maxWidth: .infinity, maxHeight: .infinity).overlay {
                WindowLayoutDebugBridge(includeInactiveRegions: includeInactiveRegions, hinge: hinge, cornerRadii: cornerRadii)
                    .ignoresSafeArea()
                    .onGeometryChange(for: RectangleCornerRadii.self) { proxy in
                        proxy.concentricCornerRadii ?? RectangleCornerRadii()
                    } action: { cornerRadii = $0 }
            }
            .modifier(LayoutDebugHingeObserver { hinge = $0 })
        }
    }

    private struct WindowLayoutDebugBridge: UIViewRepresentable {
        let includeInactiveRegions: Bool
        let hinge: LayoutDebugHingeState
        let cornerRadii: RectangleCornerRadii

        func makeUIView(context _: Context) -> WindowLayoutDebugProbe {
            WindowLayoutDebugProbe()
        }

        func updateUIView(_ probe: WindowLayoutDebugProbe, context _: Context) {
            probe.overlay.includeInactiveRegions = includeInactiveRegions
            probe.overlay.hinge = hinge
            probe.overlay.model.cornerRadii = cornerRadii
            probe.updateAttachment()
        }

        static func dismantleUIView(_ probe: WindowLayoutDebugProbe, coordinator _: ()) {
            probe.detach()
        }
    }

    /// Uses its own window, never process-wide scene or screen discovery.
    final class WindowLayoutDebugProbe: UIView {
        let overlay = WindowLayoutDebugView()
        private weak var attachedWindow: UIWindow?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            updateAttachment()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            overlay.refresh()
        }

        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            overlay.hitTest(convert(point, to: overlay), with: event)
        }

        func updateAttachment() {
            if attachedWindow !== window {
                detach()
                attachedWindow = window
                // SwiftUI owns this bridge's placement in the controller hierarchy.
                if window != nil { addSubview(overlay) }
            }
            overlay.refresh()
        }

        func detach() {
            overlay.removeFromSuperview()
            attachedWindow = nil
        }
    }

    #Preview("Window diagnostics") {
        NavigationStack {
            Color.gray.opacity(0.2)
                .navigationTitle(Text(verbatim: "Window diagnostics"))
        }
        .windowLayoutDebugOverlay()
    }
#endif
