import SwiftUI

#if DEBUG
    struct LayoutDebugOverlay: View {
        let snapshot: LayoutDebugSnapshot
        var visibility = LayoutDebugVisibility()

        var body: some View {
            GeometryReader { proxy in
                let divisions = divisionRegions(in: proxy)
                ZStack(alignment: .topLeading) {
                    LayoutDebugGuides(guides: snapshot.guides(visibility: visibility))
                    if visibility.readout {
                        LayoutDebugReadout(rows: snapshot.readout(divisionRegions: divisions, visibility: visibility), spacing: snapshot.isWindow ? 0 : 3)
                            .padding(snapshot.readoutInsets)
                    }
                }
                .frame(width: snapshot.size.width, height: snapshot.size.height)
            }
            .environment(\.layoutDirection, snapshot.isWindow ? .leftToRight : snapshot.layoutDirection)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }

        private func divisionRegions(in proxy: GeometryProxy) -> [LayoutDebugRegion]? {
            guard snapshot.isWindow, #available(iOS 27.1, *) else { return nil }
            let options: ReservedRegion.QueryOptions = visibility.includeInactive ? .includeInactive : []
            return proxy.reservedRegions(kind: .division, options: options, layoutDirectionBehavior: .fixed).map {
                LayoutDebugRegion(
                    frame: $0.frame,
                    margins: $0.margins,
                    isActive: $0.isActive,
                    isDivision: true,
                    id: AnyHashable($0.id)
                )
            }
        }
    }

    private struct LayoutDebugGuides: View {
        let guides: [LayoutDebugGuide]

        var body: some View {
            Canvas { context, _ in
                for guide in guides {
                    context.fill(Path(guide.fill), with: .color(guide.color.opacity(guide.fillOpacity * guide.opacity)))
                    context.stroke(guide.outline, with: .color(guide.color.opacity(guide.opacity)), style: StrokeStyle(lineWidth: guide.lineWidth, dash: guide.dash))
                }
            }
        }
    }

    private struct LayoutDebugReadout: View {
        let rows: [LayoutDebugReadoutRow]
        let spacing: CGFloat

        var body: some View {
            VStack(alignment: .leading, spacing: spacing) {
                ForEach(rows) { row in
                    Text(verbatim: row.text)
                        .foregroundStyle(row.color)
                }
            }
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .fixedSize(horizontal: false, vertical: true)
            .padding()
            .containerCornerOffset([.top, .leading], sizeToFit: true)
            .background(.black.opacity(0.78), in: ConcentricRectangle(corners: .concentric(minimum: .fixed(8))))
        }
    }

    #Preview("Window: hinge and reserved regions") {
        LayoutDebugOverlay(snapshot: LayoutDebugSnapshot(
            size: CGSize(width: 600, height: 400),
            safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84),
            contentMargins: nil,
            regions: [
                LayoutDebugRegion(frame: CGRect(x: 288, y: 0, width: 24, height: 400), margins: EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 8), isActive: false, isDivision: true),
                LayoutDebugRegion(frame: CGRect(x: 516, y: 0, width: 84, height: 120), margins: EdgeInsets(), isActive: true, isDivision: false),
            ],
            isWindow: true,
            hinge: .reading(status: "fully open", angleDegrees: 180)
        ))
    }

    #Preview("Local: zero guides, unavailable hinge") {
        LayoutDebugOverlay(snapshot: LayoutDebugSnapshot(size: CGSize(width: 360, height: 540), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [], hinge: .unavailable))
    }

    #Preview("Window: large screen corners") {
        LayoutDebugOverlay(snapshot: LayoutDebugSnapshot(size: CGSize(width: 600, height: 400), safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84), contentMargins: nil, regions: [], isWindow: true))
            .frame(width: 600, height: 400)
            .containerShape(.rect(cornerRadius: 80))
            .background(.white)
            .clipShape(.rect(cornerRadius: 80))
    }

    #Preview("Window: asymmetric RTL insets") {
        LayoutDebugOverlay(snapshot: LayoutDebugSnapshot(size: CGSize(width: 600, height: 400), safeAreaInsets: EdgeInsets(top: 0, leading: 84, bottom: 34, trailing: 12), contentMargins: nil, regions: [], isWindow: true, layoutDirection: .rightToLeft))
    }
#endif
