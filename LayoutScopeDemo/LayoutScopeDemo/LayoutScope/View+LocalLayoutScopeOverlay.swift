import SwiftUI

extension View {
    /// Visualizes this view's safe area, container content margins, and reserved regions.
    /// Apply inside the container being inspected; already-consumed insets can be zero.
    /// Debug only. Content margins and reserved regions require iOS 27.1.
    func localLayoutScopeOverlay(includeInactiveRegions: Bool = false) -> some View {
        #if DEBUG
            modifier(LocalLayoutScopeOverlayModifier(includeInactiveRegions: includeInactiveRegions))
        #else
            self
        #endif
    }
}

#if DEBUG
    private struct LocalLayoutScopeOverlayModifier: ViewModifier {
        let includeInactiveRegions: Bool
        @State private var hinge: LayoutScopeHingeState = .initial

        func body(content: Content) -> some View {
            content.overlay {
                GeometryReader { proxy in
                    LayoutScopeLocalOverlay(
                        size: proxy.size,
                        safeAreaInsets: proxy.safeAreaInsets,
                        contentMargins: layoutScopeContentMargins(proxy),
                        regions: layoutScopeReservedRegions(proxy, includeInactive: includeInactiveRegions),
                        hinge: hinge
                    )
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .modifier(LayoutScopeHingeObserver { hinge = $0 })
        }
    }

    private func layoutScopeContentMargins(_ proxy: GeometryProxy) -> EdgeInsets? {
        if #available(iOS 27.1, *) {
            proxy.contentMargins(for: .container)
        } else {
            nil
        }
    }

    private func layoutScopeReservedRegions(_ proxy: GeometryProxy, includeInactive: Bool) -> [LayoutScopeRegion]? {
        guard #available(iOS 27.1, *) else { return nil }
        let options: ReservedRegion.QueryOptions = includeInactive ? .includeInactive : []
        // Canvas draws physical coordinates, so ask SwiftUI not to mirror region frames.
        return [ReservedRegion.Kind.division, .occlusion].flatMap { kind in
            proxy.reservedRegions(kind: kind, options: options, layoutDirectionBehavior: .fixed).map {
                LayoutScopeRegion(
                    frame: $0.frame,
                    margins: $0.margins,
                    isActive: $0.isActive,
                    isDivision: kind == .division,
                    id: AnyHashable($0.id)
                )
            }
        }
    }

    private struct LayoutScopeLocalOverlay: View {
        let size: CGSize
        let safeAreaInsets: EdgeInsets
        let contentMargins: EdgeInsets?
        let regions: [LayoutScopeRegion]?
        var hinge: LayoutScopeHingeState = .initial

        @Environment(\.layoutDirection) private var layoutDirection
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass

        private var snapshot: LayoutScopeSnapshot {
            LayoutScopeSnapshot(size: size, safeAreaInsets: safeAreaInsets, contentMargins: contentMargins, regions: regions, layoutDirection: layoutDirection, hinge: hinge, horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass)
        }

        var body: some View {
            LayoutScopeOverlay(snapshot: snapshot)
        }
    }

    #Preview("Live container geometry") {
        NavigationStack {
            Color.gray.opacity(0.2)
                .localLayoutScopeOverlay()
                .navigationTitle(Text(verbatim: "Layout diagnostics"))
        }
    }

    #Preview("Division and occlusion fixtures") {
        LayoutScopeLocalOverlay(
            size: CGSize(width: 360, height: 540),
            safeAreaInsets: EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0),
            contentMargins: EdgeInsets(top: 60, leading: 20, bottom: 50, trailing: 20),
            regions: [
                LayoutScopeRegion(frame: CGRect(x: 168, y: 0, width: 24, height: 540), margins: EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8), isActive: true, isDivision: true),
                LayoutScopeRegion(frame: CGRect(x: 276, y: 16, width: 48, height: 32), margins: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4), isActive: false, isDivision: false),
            ]
        )
    }

    #Preview("No local guides") {
        LayoutScopeLocalOverlay(size: CGSize(width: 360, height: 540), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [])
    }

    #Preview("Partially open hinge") {
        LayoutScopeLocalOverlay(size: CGSize(width: 360, height: 540), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [], hinge: .reading(status: "partially open", angleDegrees: 90))
    }

    #Preview("Hinge unavailable") {
        LayoutScopeLocalOverlay(size: CGSize(width: 360, height: 540), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [], hinge: .unavailable)
    }

    #Preview("RTL asymmetric margins") {
        LayoutScopeLocalOverlay(
            size: CGSize(width: 360, height: 540),
            safeAreaInsets: EdgeInsets(top: 44, leading: 12, bottom: 34, trailing: 0),
            contentMargins: EdgeInsets(top: 60, leading: 40, bottom: 50, trailing: 16),
            regions: []
        )
        .environment(\.layoutDirection, .rightToLeft)
    }
#endif
