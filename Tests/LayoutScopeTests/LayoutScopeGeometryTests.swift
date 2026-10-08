@testable import LayoutScope
import SwiftUI
import Testing

#if DEBUG
    @MainActor
    struct LayoutScopeGeometryTests {
        private let bounds = CGRect(x: 0, y: 0, width: 600, height: 400)

        @Test func verticalDivisionProducesBothContentRegions() {
            #expect(LayoutScopeGeometry.regions(onEitherSideOf: CGRect(x: 288, y: 0, width: 24, height: 400), in: bounds) == [
                CGRect(x: 0, y: 0, width: 288, height: 400),
                CGRect(x: 312, y: 0, width: 288, height: 400),
            ])
        }

        @Test func horizontalDivisionProducesBothContentRegions() {
            #expect(LayoutScopeGeometry.regions(onEitherSideOf: CGRect(x: 0, y: 190, width: 600, height: 20), in: bounds) == [
                CGRect(x: 0, y: 0, width: 600, height: 190),
                CGRect(x: 0, y: 210, width: 600, height: 190),
            ])
        }

        @Test func zeroWidthAndOutsideDivisionsAreHandled() {
            #expect(LayoutScopeGeometry.regions(onEitherSideOf: CGRect(x: 300, y: 0, width: 0, height: 400), in: bounds) == [
                CGRect(x: 0, y: 0, width: 300, height: 400),
                CGRect(x: 300, y: 0, width: 300, height: 400),
            ])
            #expect(LayoutScopeGeometry.regions(onEitherSideOf: CGRect(x: 700, y: 0, width: 20, height: 400), in: bounds).isEmpty)
        }

        @Test func inactiveDivisionReadoutIncludesBothRegions() {
            let division = LayoutScopeRegion(frame: CGRect(x: 288, y: 0, width: 24, height: 400), margins: EdgeInsets(), isActive: false, isDivision: true)
            let snapshot = LayoutScopeSnapshot(size: bounds.size, safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [], isWindow: true, includeInactiveRegions: true)
            let labels = snapshot.readout(divisionRegions: [division]).map(\.text)
            #expect(labels.contains("division #1 · inactive"))
            #expect(labels.contains("  region #1"))
            #expect(labels.contains("  region #2"))
            #expect(labels.contains("    origin (x,y) · 312.0, 0.0"))
        }

        @Test func touchingOcclusionsAreOutsideButDivisionLinesRemainVisible() {
            let outside = LayoutScopeRegion(frame: CGRect(x: 600, y: 0, width: 84, height: 120), margins: EdgeInsets(), isActive: true, isDivision: false)
            let partial = LayoutScopeRegion(frame: CGRect(x: 590, y: 0, width: 84, height: 120), margins: EdgeInsets(), isActive: true, isDivision: false)
            let line = LayoutScopeRegion(frame: CGRect(x: 600, y: 0, width: 0, height: 400), margins: EdgeInsets(), isActive: false, isDivision: true)
            let snapshot = LayoutScopeSnapshot(size: bounds.size, safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [outside, partial, line])
            #expect(snapshot.visibleRegions == [partial, line])
            #expect(!LayoutScopeGeometry.intersects(CGRect(x: 0, y: 400, width: 84, height: 120), bounds: bounds))
            #expect(!LayoutScopeGeometry.intersects(CGRect(x: 10, y: 10, width: 0, height: 0), bounds: bounds))
        }
    }
#endif
