import SwiftUI

#if DEBUG
    struct LayoutScopeOverlay: View {
        let snapshot: LayoutScopeSnapshot
        var visibility = LayoutScopeVisibility()
        var reportReadoutFrame: (CGRect) -> Void = { _ in }

        var body: some View {
            GeometryReader { proxy in
                let divisions = divisionRegions(in: proxy)
                let data = snapshot.readoutData(divisionRegions: divisions, visibility: visibility)
                let insets = snapshot.readoutInsets
                let availableWidth = max(0, proxy.size.width - insets.leading - insets.trailing)
                let availableHeight = max(0, proxy.size.height - insets.top - insets.bottom)

                ZStack(alignment: .topLeading) {
                    LayoutScopeGuides(guides: snapshot.guides(visibility: visibility))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)

                    LayoutScopeReadout(
                        data: data,
                        visibility: visibility,
                        panelWidth: min(300, availableWidth),
                        maximumHeight: availableHeight,
                        reportFrame: reportReadoutFrame,
                    )
                    .padding(insets)
                }
                .frame(width: snapshot.size.width, height: snapshot.size.height, alignment: .topLeading)
                .coordinateSpace(name: "layoutScope")
            }
            .environment(\.layoutDirection, snapshot.isWindow ? .leftToRight : snapshot.layoutDirection)
            .clipped()
        }

        private func divisionRegions(in proxy: GeometryProxy) -> [LayoutScopeRegion]? {
            guard snapshot.isWindow, #available(iOS 27.1, *) else { return nil }
            let options: ReservedRegion.QueryOptions = visibility.includeInactive ? .includeInactive : []
            return proxy.reservedRegions(kind: .division, options: options, layoutDirectionBehavior: .fixed).map {
                LayoutScopeRegion(
                    frame: $0.frame,
                    margins: $0.margins,
                    isActive: $0.isActive,
                    isDivision: true,
                    id: AnyHashable($0.id),
                )
            }
        }
    }
#endif
