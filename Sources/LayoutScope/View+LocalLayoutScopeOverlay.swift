import SwiftUI

public extension View {
    /// Visualizes this view's safe area, container content margins, and reserved regions.
    /// Apply inside layout modifiers such as `ignoresSafeArea` to inspect their expanded content.
    /// Debug only. Content margins and reserved regions require iOS 27.1.
    func localLayoutScopeOverlay(includeInactiveRegions: Bool = true) -> some View {
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
        @State private var safeAreaInsets = EdgeInsets()

        func body(content: Content) -> some View {
            content.overlay {
                GeometryReader { proxy in
                    LayoutScopeLocalOverlay(
                        origin: proxy.frame(in: .global).origin,
                        size: proxy.size,
                        safeAreaInsets: safeAreaInsets,
                        contentMargins: layoutScopeContentMargins(proxy),
                        regions: layoutScopeReservedRegions(proxy, includeInactive: includeInactiveRegions)
                    )
                    .overlay {
                        LayoutScopeLocalSafeAreaProbe { safeAreaInsets = $0 }
                    }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
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
        var origin: CGPoint = .zero
        let size: CGSize
        let safeAreaInsets: EdgeInsets
        let contentMargins: EdgeInsets?
        let regions: [LayoutScopeRegion]?

        @Environment(\.layoutDirection) private var layoutDirection
        @Environment(\.horizontalSizeClass) private var horizontalSizeClass
        @Environment(\.verticalSizeClass) private var verticalSizeClass

        private var snapshot: LayoutScopeSnapshot {
            LayoutScopeSnapshot(size: size, safeAreaInsets: safeAreaInsets, contentMargins: contentMargins, regions: regions, layoutDirection: layoutDirection, horizontalSizeClass: horizontalSizeClass, verticalSizeClass: verticalSizeClass)
        }

        var body: some View {
            ZStack(alignment: .bottom) {
                LayoutScopeGuides(guides: snapshot.guides)
                LayoutScopeLocalReadout(origin: origin, snapshot: snapshot)
                    .padding(8)
            }
            .frame(width: size.width, height: size.height)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    #Preview("Live container geometry") {
        NavigationStack {
            Color.gray.opacity(0.2)
                .localLayoutScopeOverlay()
                .navigationTitle(Text(verbatim: "Layout diagnostics"))
        }
    }

    #Preview("Expanded safe-area overlap") {
        Color.gray.opacity(0.2)
            .localLayoutScopeOverlay()
            .ignoresSafeArea()
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

    #Preview("Offset local view") {
        LayoutScopeLocalOverlay(origin: CGPoint(x: 24, y: 80), size: CGSize(width: 300, height: 200), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [])
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
