import SwiftUI

#if DEBUG
    struct LayoutScopeReadout: View {
        let data: LayoutScopeReadoutData
        let visibility: LayoutScopeVisibility
        let panelWidth: CGFloat
        let maximumHeight: CGFloat
        let reportFrame: (CGRect) -> Void

        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        @State private var isExpanded = true
        @State private var expandedDivisions: Set<LayoutScopeReadoutRegion.ID>
        @State private var bodyContentHeight: CGFloat = 0

        init(
            data: LayoutScopeReadoutData,
            visibility: LayoutScopeVisibility,
            panelWidth: CGFloat,
            maximumHeight: CGFloat,
            initiallyExpandedDivisions: Set<LayoutScopeReadoutRegion.ID> = [],
            reportFrame: @escaping (CGRect) -> Void,
        ) {
            self.data = data
            self.visibility = visibility
            self.panelWidth = panelWidth
            self.maximumHeight = maximumHeight
            self.reportFrame = reportFrame
            _expandedDivisions = State(initialValue: initiallyExpandedDivisions)
        }

        var body: some View {
            Group {
                if visibility.readout {
                    panel
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named("layoutScope"))
                        } action: { reportFrame($0) }
                        .onDisappear { reportFrame(.zero) }
                }
            }
        }

        private var panel: some View {
            VStack(spacing: 0) {
                Button {
                    togglePanel()
                } label: {
                    HStack(spacing: 8) {
                        Text(verbatim: "LayoutScope")
                            .fontWeight(.medium)
                        Spacer(minLength: 4)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .frame(minHeight: 36)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("layoutScope.readout.header")
                .accessibilityLabel("LayoutScope, window readout")
                .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                .accessibilityHint("Shows or hides the window measurements")

                if isExpanded {
                    Rectangle()
                        .fill(.quaternary)
                        .frame(height: 1)

                    ScrollView(.vertical) {
                        VStack(spacing: 0) {
                            LayoutScopeReadoutContextRow(context: data.context)
                            if let safeAreaInsets = data.safeAreaInsets {
                                LayoutScopeReadoutInsetsRow(
                                    title: "Safe area",
                                    insets: safeAreaInsets,
                                    identifier: "layoutScope.readout.safeArea",
                                    color: .cyan,
                                )
                            }
                            if !data.regionsAvailable {
                                Text(verbatim: "Reserved regions require iOS 27.1")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .accessibilityIdentifier("layoutScope.readout.regionsUnavailable")
                            } else if !data.regions.isEmpty {
                                LayoutScopeReadoutRegionTable(
                                    regions: data.regions,
                                    width: max(0, panelWidth - 20),
                                    expandedDivisions: $expandedDivisions,
                                    reduceMotion: reduceMotion,
                                )
                            }
                        }
                        .padding(.bottom, 6)
                        .onGeometryChange(for: CGFloat.self) { proxy in
                            proxy.size.height
                        } action: { bodyContentHeight = $0 }
                    }
                    .frame(height: min(bodyContentHeight, max(0, maximumHeight - 37)))
                    .padding(.horizontal, 10)
                    .accessibilityIdentifier("layoutScope.readout.body")
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(.primary)
            .frame(width: panelWidth, alignment: .topLeading)
            .containerCornerOffset([.top, .leading], sizeToFit: true)
            .padding(6)
            .background(.regularMaterial, in: ConcentricRectangle(corners: .concentric(minimum: .fixed(8))))
        }

        private func togglePanel() {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.16)) {
                isExpanded.toggle()
            }
        }
    }

    private struct LayoutScopeReadoutContextRow: View {
        let context: String

        var body: some View {
            Text(verbatim: context)
                .font(.system(size: 10.5))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .accessibilityIdentifier("layoutScope.readout.context")
                .accessibilityLabel(context
                    .replacingOccurrences(of: "H:", with: "Horizontal size class:")
                    .replacingOccurrences(of: "V:", with: "Vertical size class:"))
        }
    }

    private struct LayoutScopeReadoutInsetsRow: View {
        let title: String
        let insets: EdgeInsets
        let identifier: String
        var color: Color = .primary

        var body: some View {
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .accessibilityHidden(true)
                Text(verbatim: title)
                    .lineLimit(1)
                Spacer(minLength: 4)
                LayoutScopeInsetValue(label: "Top", abbreviation: "T", value: insets.top)
                LayoutScopeInsetValue(label: "Leading", abbreviation: "L", value: insets.leading)
                LayoutScopeInsetValue(label: "Bottom", abbreviation: "B", value: insets.bottom)
                LayoutScopeInsetValue(label: "Trailing", abbreviation: "Tr", value: insets.trailing)
            }
            .font(.system(size: 10.5))
            .padding(.vertical, 6)
            .overlay(alignment: .top) { Rectangle().fill(.quaternary).frame(height: 1) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(identifier)
        }
    }

    private struct LayoutScopeInsetValue: View {
        let label: String
        let abbreviation: String
        let value: CGFloat

        var body: some View {
            HStack(spacing: 3) {
                Text(verbatim: abbreviation)
                    .foregroundStyle(.secondary)
                Text(verbatim: LayoutScopeNumberFormatter.points(value))
                    .font(.system(size: 10, design: .monospaced))
                    .monospacedDigit()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(label) \(LayoutScopeNumberFormatter.points(value)) points")
        }
    }

    private struct LayoutScopeReadoutRegionTable: View {
        let regions: [LayoutScopeReadoutRegion]
        let width: CGFloat
        @Binding var expandedDivisions: Set<LayoutScopeReadoutRegion.ID>
        let reduceMotion: Bool

        var body: some View {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    header("Region / state", width: width * 0.36, alignment: .leading)
                    header("Origin · x, y", width: width * 0.31, alignment: .trailing)
                    header("Size · w × h", width: width * 0.33, alignment: .trailing)
                }
                .frame(width: width)
                .padding(.vertical, 5)
                .overlay(alignment: .top) { Rectangle().fill(.quaternary).frame(height: 1) }

                ForEach(regions) { region in
                    LayoutScopeReadoutRegionRow(
                        region: region,
                        width: width,
                        isExpanded: expandedDivisions.contains(region.id),
                        onToggle: { toggle(region.id) },
                    )
                    if region.kind == .division, expandedDivisions.contains(region.id) {
                        LayoutScopeReadoutDivisionDetails(region: region)
                    }
                }
            }
            .font(.system(size: 10.5))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("layoutScope.readout.regions")
        }

        private func header(_ text: String, width: CGFloat, alignment: Alignment) -> some View {
            Text(verbatim: text)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: width, alignment: alignment)
        }

        private func toggle(_ id: LayoutScopeReadoutRegion.ID) {
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.16)) {
                if expandedDivisions.contains(id) {
                    expandedDivisions.remove(id)
                } else {
                    expandedDivisions.insert(id)
                }
            }
        }
    }

    private struct LayoutScopeReadoutRegionRow: View {
        let region: LayoutScopeReadoutRegion
        let width: CGFloat
        let isExpanded: Bool
        let onToggle: () -> Void

        var body: some View {
            HStack(spacing: 0) {
                Group {
                    if region.kind == .division {
                        Button(action: onToggle) {
                            name
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("layoutScope.readout.division.\(region.number).toggle")
                        .accessibilityLabel("Division \(region.number), \(region.state.lowercased()), additional details")
                        .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
                        .accessibilityHint("Shows the content areas and included margins")
                    } else {
                        name
                    }
                }
                .frame(width: width * 0.36, alignment: .leading)

                geometryValue(
                    "\(coordinate(region.frame.minX)), \(coordinate(region.frame.minY))",
                    identifier: "layoutScope.readout.region.\(region.kind.rawValue).\(region.number).origin",
                    accessibilityLabel: "\(region.kind.rawValue.capitalized) \(region.number) origin, x \(coordinate(region.frame.minX)), y \(coordinate(region.frame.minY)) points",
                )
                .frame(width: width * 0.31)
                geometryValue(
                    "\(coordinate(region.frame.width)) × \(coordinate(region.frame.height))",
                    identifier: "layoutScope.readout.region.\(region.kind.rawValue).\(region.number).size",
                    accessibilityLabel: "\(region.kind.rawValue.capitalized) \(region.number) size, width \(coordinate(region.frame.width)), height \(coordinate(region.frame.height)) points",
                )
                .frame(width: width * 0.33)
            }
            .frame(width: width, alignment: .leading)
            .padding(.vertical, 4)
            .overlay(alignment: .top) { Rectangle().fill(.quaternary).frame(height: 1) }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("layoutScope.readout.region.\(region.kind.rawValue).\(region.number)")
        }

        private var name: some View {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if region.kind == .division {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                    } else {
                        Circle()
                            .fill(.pink)
                            .frame(width: 5, height: 5)
                            .accessibilityHidden(true)
                    }
                    Text(verbatim: "\(region.kind.rawValue.capitalized) \(region.number)")
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Text(verbatim: region.state)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
                    .padding(.leading, region.kind == .division ? 12 : 9)
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
            .contentShape(Rectangle())
        }

        private func geometryValue(_ value: String, identifier: String, accessibilityLabel: String) -> some View {
            Text(verbatim: value)
                .font(.system(size: 10, design: .monospaced))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(accessibilityLabel)
        }

        private func coordinate(_ value: CGFloat) -> String {
            LayoutScopeNumberFormatter.points(value)
        }
    }

    private struct LayoutScopeReadoutDivisionDetails: View {
        let region: LayoutScopeReadoutRegion

        var body: some View {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(region.contentAreas.enumerated()), id: \.offset) { index, frame in
                        HStack(spacing: 6) {
                            Text(verbatim: "Side \(index + 1)")
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 2)
                            Text(verbatim: "\(coordinate(frame.minX)), \(coordinate(frame.minY))")
                            Text(verbatim: "·")
                                .foregroundStyle(.tertiary)
                            Text(verbatim: "\(coordinate(frame.width)) × \(coordinate(frame.height))")
                        }
                        .font(.system(size: 9.5, design: .monospaced))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("layoutScope.readout.division.\(region.number).side.\(index + 1)")
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Content areas")

                if region.margins != EdgeInsets() {
                    LayoutScopeReadoutInsetsRow(
                        title: "Included margins",
                        insets: region.margins,
                        identifier: "layoutScope.readout.division.\(region.number).margins",
                    )
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.quaternary.opacity(0.22), in: Rectangle())
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("layoutScope.readout.division.\(region.number).details")
        }

        private func coordinate(_ value: CGFloat) -> String {
            LayoutScopeNumberFormatter.points(value)
        }
    }

    #Preview("Window readout · full Duo") {
        LayoutScopeReadoutPreview(snapshot: .preview)
            .frame(width: 600, height: 400, alignment: .topLeading)
            .containerShape(.rect(cornerRadius: 80))
            .background(Color.gray.opacity(0.16))
    }

    #Preview("Window readout · no regions") {
        LayoutScopeReadoutPreview(snapshot: LayoutScopeSnapshot(
            size: CGSize(width: 360, height: 540),
            safeAreaInsets: EdgeInsets(),
            contentMargins: nil,
            regions: [],
            isWindow: true,
            hinge: .unavailable,
        ))
        .frame(width: 360, height: 540, alignment: .topLeading)
    }

    #Preview("Window readout · unsupported regions") {
        LayoutScopeReadoutPreview(snapshot: LayoutScopeSnapshot(
            size: CGSize(width: 360, height: 540),
            safeAreaInsets: EdgeInsets(top: 48, leading: 0, bottom: 34, trailing: 0),
            contentMargins: nil,
            regions: nil,
            isWindow: true,
            hinge: .unsupported,
        ))
        .frame(width: 360, height: 540, alignment: .topLeading)
    }

    #Preview("Window readout · expanded division") {
        LayoutScopeReadoutPreview(snapshot: .preview, expandsDivision: true)
            .frame(width: 600, height: 400, alignment: .topLeading)
            .containerShape(.rect(cornerRadius: 80))
            .background(Color.gray.opacity(0.16))
    }

    private extension LayoutScopeSnapshot {
        static var preview: Self {
            LayoutScopeSnapshot(
                size: CGSize(width: 960, height: 700),
                safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84),
                contentMargins: nil,
                regions: [
                    LayoutScopeRegion(frame: CGRect(x: 455.5, y: 0, width: 40, height: 669), margins: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20), isActive: false, isDivision: true, id: AnyHashable("division-1")),
                    LayoutScopeRegion(frame: CGRect(x: 677.3, y: 21, width: 58, height: 37), margins: EdgeInsets(), isActive: false, isDivision: false, id: AnyHashable("occlusion-1")),
                    LayoutScopeRegion(frame: CGRect(x: 867, y: 0, width: 84, height: 120), margins: EdgeInsets(), isActive: true, isDivision: false, id: AnyHashable("occlusion-2")),
                ],
                isWindow: true,
                hinge: .reading(status: "Fully open", angleDegrees: 180),
                horizontalSizeClass: .regular,
                verticalSizeClass: .regular,
            )
        }
    }

    private struct LayoutScopeReadoutPreview: View {
        let snapshot: LayoutScopeSnapshot
        var expandsDivision = false
        private let visibility = LayoutScopeVisibility()

        var body: some View {
            let expandedIDs = expandsDivision
                ? Set(snapshot.readoutData().regions.filter { $0.kind == .division }.map(\.id))
                : []
            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    LayoutScopeReadout(
                        data: snapshot.readoutData(),
                        visibility: visibility,
                        panelWidth: min(300, max(0, proxy.size.width - snapshot.readoutInsets.leading - snapshot.readoutInsets.trailing)),
                        maximumHeight: max(0, proxy.size.height - snapshot.readoutInsets.top - snapshot.readoutInsets.bottom),
                        initiallyExpandedDivisions: expandedIDs,
                        reportFrame: { _ in },
                    )
                    .padding(snapshot.readoutInsets)
                }
                .frame(width: snapshot.size.width, height: snapshot.size.height, alignment: .topLeading)
                .coordinateSpace(name: "layoutScope")
            }
        }
    }
#endif
