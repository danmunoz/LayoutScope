import SwiftUI

#if DEBUG
    struct LayoutScopeRegion: Equatable {
        let frame: CGRect
        let margins: EdgeInsets
        let isActive: Bool
        let isDivision: Bool
        var id: AnyHashable?

        var color: Color {
            isDivision ? .orange : .pink
        }

        var name: String {
            isDivision ? "division" : "occlusion"
        }

        func occupiedFrame(layoutDirection: LayoutDirection) -> CGRect {
            let left = layoutDirection == .leftToRight ? margins.leading : margins.trailing
            let right = layoutDirection == .leftToRight ? margins.trailing : margins.leading
            return CGRect(
                x: frame.minX + min(frame.width, max(0, left)),
                y: frame.minY + min(frame.height, max(0, margins.top)),
                width: max(0, frame.width - max(0, left) - max(0, right)),
                height: max(0, frame.height - max(0, margins.top) - max(0, margins.bottom))
            )
        }
    }

    struct LayoutScopeReadoutRow: Identifiable {
        enum ID: Hashable {
            case field(String)
            case region(kind: String, identity: AnyHashable, field: String)
        }

        let id: ID
        let text: String
        let color: Color
    }

    struct LayoutScopeGuide {
        let fill: CGRect
        let outline: Path
        let color: Color
        var opacity: Double = 1
        var fillOpacity: Double = 0.12
        var lineWidth: CGFloat = 1
        var dash: [CGFloat] = [5, 3]
    }

    enum LayoutScopeGeometry {
        static func insetGuides(_ insets: EdgeInsets, size: CGSize, layoutDirection: LayoutDirection, color: Color) -> [LayoutScopeGuide] {
            guard size.width > 0, size.height > 0 else { return [] }
            let left = layoutDirection == .leftToRight ? insets.leading : insets.trailing
            let right = layoutDirection == .leftToRight ? insets.trailing : insets.leading
            let top = min(size.height, max(0, insets.top))
            let bottom = min(size.height, max(0, insets.bottom))
            let leading = min(size.width, max(0, left))
            let trailing = min(size.width, max(0, right))
            let candidates: [(CGFloat, CGRect, CGPoint, CGPoint)] = [
                (top, CGRect(x: 0, y: 0, width: size.width, height: top), CGPoint(x: 0, y: top), CGPoint(x: size.width, y: top)),
                (bottom, CGRect(x: 0, y: size.height - bottom, width: size.width, height: bottom), CGPoint(x: 0, y: size.height - bottom), CGPoint(x: size.width, y: size.height - bottom)),
                (leading, CGRect(x: 0, y: 0, width: leading, height: size.height), CGPoint(x: leading, y: 0), CGPoint(x: leading, y: size.height)),
                (trailing, CGRect(x: size.width - trailing, y: 0, width: trailing, height: size.height), CGPoint(x: size.width - trailing, y: 0), CGPoint(x: size.width - trailing, y: size.height)),
            ]
            return candidates.compactMap { inset, band, start, end in
                guard inset > 0 else { return nil }
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                return LayoutScopeGuide(fill: band, outline: path, color: color)
            }
        }

        static func intersects(_ frame: CGRect, bounds: CGRect) -> Bool {
            guard !frame.isNull, !frame.isInfinite, bounds.width > 0, bounds.height > 0,
                  frame.width > 0 || frame.height > 0 else { return false }
            // Keep division lines, but exclude area regions that only touch an
            // edge. Otherwise an occlusion outside a respected safe area leaks
            // a border and readout into the local overlay.
            if frame.width == 0 {
                return frame.minX >= bounds.minX && frame.minX <= bounds.maxX
                    && frame.maxY > bounds.minY && frame.minY < bounds.maxY
            }
            if frame.height == 0 {
                return frame.minY >= bounds.minY && frame.minY <= bounds.maxY
                    && frame.maxX > bounds.minX && frame.minX < bounds.maxX
            }
            return frame.maxX > bounds.minX && frame.minX < bounds.maxX
                && frame.maxY > bounds.minY && frame.minY < bounds.maxY
        }

        static func regions(onEitherSideOf division: CGRect, in bounds: CGRect) -> [CGRect] {
            let divider = division.intersection(bounds)
            guard !divider.isNull else { return [] }

            let candidates: [CGRect]
            if divider.height >= divider.width {
                candidates = [
                    CGRect(x: bounds.minX, y: bounds.minY, width: max(0, divider.minX - bounds.minX), height: bounds.height),
                    CGRect(x: divider.maxX, y: bounds.minY, width: max(0, bounds.maxX - divider.maxX), height: bounds.height),
                ]
            } else {
                candidates = [
                    CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: max(0, divider.minY - bounds.minY)),
                    CGRect(x: bounds.minX, y: divider.maxY, width: bounds.width, height: max(0, bounds.maxY - divider.maxY)),
                ]
            }
            return candidates.filter { !$0.isEmpty }
        }
    }

    struct LayoutScopeSnapshot: Equatable {
        let size: CGSize
        let safeAreaInsets: EdgeInsets
        let contentMargins: EdgeInsets?
        let regions: [LayoutScopeRegion]?
        var isWindow = false
        var includeInactiveRegions = false
        var layoutDirection: LayoutDirection = .leftToRight
        var hinge: LayoutScopeHingeState = .initial
        var horizontalSizeClass: UserInterfaceSizeClass?
        var verticalSizeClass: UserInterfaceSizeClass?

        var visibleRegions: [LayoutScopeRegion] {
            let bounds = CGRect(origin: .zero, size: size)
            return (regions ?? []).filter { LayoutScopeGeometry.intersects($0.frame, bounds: bounds) }
        }

        var guides: [LayoutScopeGuide] {
            guides(visibility: LayoutScopeVisibility())
        }

        func guides(visibility: LayoutScopeVisibility) -> [LayoutScopeGuide] {
            var result = visibility.safeArea
                ? LayoutScopeGeometry.insetGuides(safeAreaInsets, size: size, layoutDirection: layoutDirection, color: .cyan)
                : []
            if let contentMargins {
                result += LayoutScopeGeometry.insetGuides(contentMargins, size: size, layoutDirection: layoutDirection, color: .green)
            }
            for region in visibleRegions.filter(visibility.shows) {
                let opacity = region.isActive ? 1.0 : 0.45
                let occupied = region.occupiedFrame(layoutDirection: layoutDirection)
                result.append(LayoutScopeGuide(fill: occupied, outline: Path(occupied), color: region.color, opacity: opacity, fillOpacity: 0.2, lineWidth: 2, dash: region.isActive ? [] : [4, 3]))
                if region.margins != EdgeInsets() {
                    result.append(LayoutScopeGuide(fill: region.frame, outline: Path(region.frame), color: region.color, opacity: opacity, fillOpacity: 0, dash: [2, 3]))
                }
            }
            return result
        }

        var readoutInsets: EdgeInsets {
            guard isWindow else { return EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8) }
            let left = layoutDirection == .leftToRight ? safeAreaInsets.leading : safeAreaInsets.trailing
            let right = layoutDirection == .leftToRight ? safeAreaInsets.trailing : safeAreaInsets.leading
            return EdgeInsets(top: max(0, safeAreaInsets.top) + 8, leading: max(0, left) + 8, bottom: max(0, safeAreaInsets.bottom) + 8, trailing: max(0, right) + 8)
        }

        func readout(divisionRegions: [LayoutScopeRegion]? = nil, visibility: LayoutScopeVisibility = LayoutScopeVisibility()) -> [LayoutScopeReadoutRow] {
            guard visibility.readout else { return [] }
            var rows = [
                row("edgeOrder", "top / lead / bottom / trail", color: .white),
                row("sizeClasses", "size classes · h: \(sizeClassName(horizontalSizeClass)), v: \(sizeClassName(verticalSizeClass))", color: .white),
            ]
            if visibility.safeArea {
                rows.append(row("safeInsets", "safe area insets · \(insets(safeAreaInsets))", color: .cyan))
            }
            if !isWindow, let contentMargins, contentMargins != EdgeInsets() {
                rows.append(row("contentMargins", "content margins · \(insets(contentMargins))", color: .green))
            }
            rows.append(row("hinge", hinge.readout, color: .yellow))
            guard regions != nil else {
                rows.append(row("reservedUnavailable", "reserved · requires iOS 27.1", color: .white))
                return rows
            }
            let divisions = (divisionRegions ?? visibleRegions.filter(\.isDivision))
                .filter { LayoutScopeGeometry.intersects($0.frame, bounds: CGRect(origin: .zero, size: size)) }
            let occlusions = visibleRegions.filter { !$0.isDivision }
            for group in [divisions, occlusions] {
                for (index, region) in group.filter(visibility.shows).enumerated() {
                    let identity = region.id ?? AnyHashable(index)
                    var details: [(String, String, Color)] = [
                        ("status", "\(region.name) #\(index + 1) · \(region.isActive ? "active" : "inactive")", region.color),
                        ("origin", "  origin (x,y) · \(points(region.frame.minX)), \(points(region.frame.minY))", .white),
                        ("size", "  size (w,h) · \(points(region.frame.width)), \(points(region.frame.height))", .white),
                    ]
                    if region.isDivision {
                        let bounds = CGRect(origin: .zero, size: size)
                        let contentRegions = LayoutScopeGeometry.regions(onEitherSideOf: region.frame, in: bounds)
                        for (regionIndex, frame) in contentRegions.enumerated() {
                            details.append((
                                "divisionRegion\(regionIndex).title",
                                "  region #\(regionIndex + 1)",
                                .white
                            ))
                            details.append((
                                "divisionRegion\(regionIndex).origin",
                                "    origin (x,y) · \(points(frame.minX)), \(points(frame.minY))",
                                .white
                            ))
                            details.append((
                                "divisionRegion\(regionIndex).size",
                                "    size (w,h) · \(points(frame.width)), \(points(frame.height))",
                                .white
                            ))
                        }
                    }
                    if region.margins != EdgeInsets() {
                        details.append(("margins", "  included margins · \(insets(region.margins))", .white))
                    }
                    rows += details.map { field, text, color in
                        LayoutScopeReadoutRow(id: .region(kind: region.name, identity: identity, field: field), text: text, color: color)
                    }
                }
            }
            return rows
        }

        private func row(_ id: String, _ text: String, color: Color) -> LayoutScopeReadoutRow {
            LayoutScopeReadoutRow(id: .field(id), text: text, color: color)
        }

        private func insets(_ insets: EdgeInsets) -> String {
            guard insets != EdgeInsets() else { return "none" }
            return [insets.top, insets.leading, insets.bottom, insets.trailing].map(points).joined(separator: " / ")
        }

        private func sizeClassName(_ sizeClass: UserInterfaceSizeClass?) -> String {
            switch sizeClass {
            case .compact: "compact"
            case .regular: "regular"
            case nil: "unspecified"
            @unknown default: "unknown"
            }
        }

        private func points(_ value: CGFloat) -> String {
            String(format: "%.1f", Double(value))
        }
    }
#endif
