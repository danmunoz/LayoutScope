import SwiftUI

#if DEBUG
    /// Compact diagnostics for one view. Origin uses SwiftUI's global coordinate space.
    struct LayoutScopeViewReadout: View {
        let origin: CGPoint
        let snapshot: LayoutScopeSnapshot

        var body: some View {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "origin (x,y) · \(points(origin.x)), \(points(origin.y))")
                Text(verbatim: "size (w,h) · \(points(snapshot.size.width)), \(points(snapshot.size.height))")
                Text(verbatim: "size classes · h: \(sizeClass(snapshot.horizontalSizeClass)), v: \(sizeClass(snapshot.verticalSizeClass))")
                if snapshot.safeAreaInsets != EdgeInsets() {
                    Text(verbatim: "safe area (t/l/b/r)\n\(insets(snapshot.safeAreaInsets))")
                        .foregroundStyle(.cyan)
                }
                if let margins = snapshot.contentMargins, margins != EdgeInsets() {
                    Text(verbatim: "content margins (t/l/b/r)\n\(insets(margins))")
                        .foregroundStyle(.green)
                }
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .fixedSize(horizontal: false, vertical: true)
            .padding(16)
            .background(.black.opacity(0.78), in: ConcentricRectangle(corners: .concentric(minimum: .fixed(8))))
        }

        private func points(_ value: CGFloat) -> String {
            String(format: "%.1f", Double(value))
        }

        private func insets(_ value: EdgeInsets) -> String {
            [value.top, value.leading, value.bottom, value.trailing].map(points).joined(separator: " / ")
        }

        private func sizeClass(_ value: UserInterfaceSizeClass?) -> String {
            switch value {
            case .compact: "compact"
            case .regular: "regular"
            case nil: "unspecified"
            @unknown default: "unknown"
            }
        }
    }

    #Preview("Geometry only") {
        LayoutScopeViewReadout(origin: CGPoint(x: 24, y: 80), snapshot: LayoutScopeSnapshot(size: CGSize(width: 300, height: 200), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [], horizontalSizeClass: .compact, verticalSizeClass: .regular))
    }

    #Preview("Safe area and margins") {
        LayoutScopeViewReadout(origin: .zero, snapshot: LayoutScopeSnapshot(size: CGSize(width: 600, height: 400), safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84), contentMargins: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 0), regions: [], horizontalSizeClass: .regular, verticalSizeClass: .regular))
    }
#endif
