import SwiftUI

extension View {
    /// Visualizes this view's safe area, container content margins, and reserved regions.
    /// Apply inside the container being inspected; already-consumed insets can be zero.
    /// Debug only. Content margins and reserved regions require iOS 27.1.
    func layoutDebugOverlay(includeInactiveRegions: Bool = false) -> some View {
        #if DEBUG
            modifier(LayoutDebugOverlayModifier(includeInactiveRegions: includeInactiveRegions))
        #else
            self
        #endif
    }
}

#if DEBUG
    private struct LayoutDebugOverlayModifier: ViewModifier {
        let includeInactiveRegions: Bool
        @State private var hinge: LayoutDebugHingeState = .initial

        func body(content: Content) -> some View {
            content.overlay {
                GeometryReader { proxy in
                    LayoutDebugLocalOverlay(
                        size: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        contentMargins: layoutDebugContentMargins(proxy),
                        regions: layoutDebugReservedRegions(proxy, includeInactive: includeInactiveRegions),
                        hinge: hinge
                    )
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .modifier(LayoutDebugHingeObserver { hinge = $0 })
        }
    }

    private func layoutDebugContentMargins(_ proxy: GeometryProxy) -> EdgeInsets? {
        if #available(iOS 27.1, *) {
            proxy.contentMargins(for: .container)
        } else {
            nil
        }
    }

    private func layoutDebugReservedRegions(_ proxy: GeometryProxy, includeInactive: Bool) -> [LayoutDebugRegion]? {
        guard #available(iOS 27.1, *) else { return nil }
        let options: ReservedRegion.QueryOptions = includeInactive ? .includeInactive : []
        // Canvas draws physical coordinates, so ask SwiftUI not to mirror region frames.
        return [ReservedRegion.Kind.division, .occlusion].flatMap { kind in
            proxy.reservedRegions(kind: kind, options: options, layoutDirectionBehavior: .fixed).map {
                LayoutDebugRegion(
                    frame: $0.frame,
                    margins: $0.margins,
                    isActive: $0.isActive,
                    isDivision: kind == .division,
                    id: AnyHashable($0.id)
                )
            }
        }
    }

    private struct LayoutDebugLocalOverlay: View {
        let size: CGSize
        let safeAreaInsets: EdgeInsets
        let contentMargins: EdgeInsets?
        let regions: [LayoutDebugRegion]?
        var hinge: LayoutDebugHingeState = .initial

        @Environment(\.layoutDirection) private var layoutDirection
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass

        private var snapshot: LayoutDebugSnapshot {
            LayoutDebugSnapshot(size: size, safeAreaInsets: safeAreaInsets, contentMargins: contentMargins, regions: regions, layoutDirection: layoutDirection, hinge: hinge, horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass)
        }

        var body: some View {
            LayoutDebugOverlay(snapshot: snapshot)
        }
    }

    #Preview("Live container geometry") {
        NavigationStack {
            Color.gray.opacity(0.2)
                .layoutDebugOverlay()
                .navigationTitle(Text(verbatim: "Layout diagnostics"))
        }
    }

    #Preview("Division and occlusion fixtures") {
        LayoutDebugLocalOverlay(
            size: CGSize(width: 360, height: 540),
            safeAreaInsets: EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0),
            contentMargins: EdgeInsets(top: 60, leading: 20, bottom: 50, trailing: 20),
            regions: [
                LayoutDebugRegion(frame: CGRect(x: 168, y: 0, width: 24, height: 540), margins: EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8), isActive: true, isDivision: true),
                LayoutDebugRegion(frame: CGRect(x: 276, y: 16, width: 48, height: 32), margins: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4), isActive: false, isDivision: false),
            ]
        )
    }

    #Preview("No local guides") {
        LayoutDebugLocalOverlay(size: CGSize(width: 360, height: 540), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [])
    }

    #Preview("Partially open hinge") {
        LayoutDebugLocalOverlay(size: CGSize(width: 360, height: 540), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [], hinge: .reading(status: "partially open", angleDegrees: 90))
    }

    #Preview("Hinge unavailable") {
        LayoutDebugLocalOverlay(size: CGSize(width: 360, height: 540), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [], hinge: .unavailable)
    }

    #Preview("RTL asymmetric margins") {
        LayoutDebugLocalOverlay(
            size: CGSize(width: 360, height: 540),
            safeAreaInsets: EdgeInsets(top: 44, leading: 12, bottom: 34, trailing: 0),
            contentMargins: EdgeInsets(top: 60, leading: 40, bottom: 50, trailing: 16),
            regions: []
        )
        .environment(\.layoutDirection, .rightToLeft)
    }
#endif
