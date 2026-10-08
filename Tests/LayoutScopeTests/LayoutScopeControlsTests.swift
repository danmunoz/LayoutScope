@testable import LayoutScope
import SwiftUI
import Testing
import UIKit

#if DEBUG
    @MainActor
    struct LayoutScopeControlsTests {
        private var snapshot: LayoutScopeSnapshot {
            makeSnapshot(regions: [
                LayoutScopeRegion(frame: CGRect(x: 288, y: 0, width: 24, height: 400), margins: EdgeInsets(), isActive: false, isDivision: true, id: AnyHashable("division")),
                LayoutScopeRegion(frame: CGRect(x: 516, y: 0, width: 84, height: 120), margins: EdgeInsets(), isActive: true, isDivision: false, id: AnyHashable("occlusion")),
            ])
        }

        private func makeSnapshot(regions: [LayoutScopeRegion]?) -> LayoutScopeSnapshot {
            LayoutScopeSnapshot(
                size: CGSize(width: 600, height: 400),
                safeAreaInsets: EdgeInsets(top: 20, leading: 0, bottom: 34, trailing: 0),
                contentMargins: nil,
                regions: regions,
                isWindow: true,
                hinge: .reading(status: "Fully open", angleDegrees: 180),
                horizontalSizeClass: .regular,
                verticalSizeClass: .compact,
            )
        }

        @Test func contextCombinesHingeAndBothSizeClasses() {
            #expect(snapshot.readoutData().context == "180° · Fully open   H: Regular · V: Compact")
            var unspecified = snapshot
            unspecified.horizontalSizeClass = nil
            unspecified.verticalSizeClass = nil
            #expect(unspecified.readoutData().context.contains("H: Unspecified · V: Unspecified"))
        }

        @Test func safeAreaVisibilityControlsTheSingleInsetRowAndGuideBands() {
            let visibility = LayoutScopeVisibility(safeArea: false)
            #expect(snapshot.guides(visibility: visibility).count == 2)
            #expect(snapshot.readoutData(visibility: visibility).safeAreaInsets == nil)
            #expect(snapshot.readoutData().safeAreaInsets == snapshot.safeAreaInsets)
        }

        @Test func inactiveAndKindFiltersApplyIndependentlyToRegionsAndGuides() {
            let inactiveHidden = LayoutScopeVisibility(includeInactive: false)
            #expect(snapshot.guides(visibility: inactiveHidden).count == 3)
            #expect(snapshot.readoutData(visibility: inactiveHidden).regions.map(\.kind) == [.occlusion])

            let noDivisions = LayoutScopeVisibility(divisions: false)
            #expect(snapshot.guides(visibility: noDivisions).count == 3)
            #expect(snapshot.readoutData(visibility: noDivisions).regions.map(\.kind) == [.occlusion])

            let noOcclusions = LayoutScopeVisibility(occlusions: false)
            #expect(snapshot.guides(visibility: noOcclusions).count == 3)
            #expect(snapshot.readoutData(visibility: noOcclusions).regions.map(\.kind) == [.division])
        }

        @Test func divisionNumbersAreIndependentFromOcclusionNumbers() {
            let value = makeSnapshot(regions: [
                LayoutScopeRegion(frame: CGRect(x: 288, y: 0, width: 24, height: 400), margins: EdgeInsets(), isActive: true, isDivision: true),
                LayoutScopeRegion(frame: CGRect(x: 516, y: 0, width: 20, height: 20), margins: EdgeInsets(), isActive: true, isDivision: false),
                LayoutScopeRegion(frame: CGRect(x: 536, y: 0, width: 20, height: 20), margins: EdgeInsets(), isActive: true, isDivision: false),
            ])
            let rows = value.readoutData().regions
            #expect(rows.map(\.number) == [1, 1, 2])
            #expect(rows.map(\.kind) == [.division, .occlusion, .occlusion])
        }

        @Test func swiftUIWindowDivisionQueryOverridesSnapshotDivisionValues() {
            let queried = LayoutScopeRegion(frame: CGRect(x: 280, y: 0, width: 30, height: 400), margins: EdgeInsets(), isActive: false, isDivision: true, id: AnyHashable("sdk-division"))
            let data = snapshot.readoutData(divisionRegions: [queried])
            #expect(data.regions.filter { $0.kind == .division }.map(\.id.identity) == [AnyHashable("sdk-division")])
            #expect(data.regions.first?.frame == queried.frame)
        }

        @Test func nilAndEmptyRegionResultsRemainDistinct() {
            let unavailable = makeSnapshot(regions: nil)
            #expect(!unavailable.readoutData().regionsAvailable)
            #expect(unavailable.readoutData().regions.isEmpty)

            let empty = makeSnapshot(regions: [])
            #expect(empty.readoutData().regionsAvailable)
            #expect(empty.readoutData().regions.isEmpty)
        }

        @Test func measurementAndHingeUpdatesPreserveToggleStateAndRouteOnlyPanelOrControls() throws {
            let view = LayoutScopeHostingView(frame: CGRect(origin: .zero, size: snapshot.size))
            view.model.visibility.readout = false
            view.model.visibility.includeInactive = false
            view.display(snapshot)
            let controller = try #require(view.hostingController)
            var next = snapshot
            next.hinge = .unavailable
            view.display(next)
            view.includeInactiveRegions = true
            #expect(!view.model.visibility.readout)
            #expect(!view.model.visibility.includeInactive)
            #expect(view.hostingController === controller)

            view.model.controlsFrame = CGRect(x: 8, y: 200, width: 204, height: 158)
            view.model.readoutFrame = CGRect(x: 8, y: 8, width: 300, height: 180)
            #expect(view.hitTest(CGPoint(x: 450, y: 200), with: nil) == nil)
            #expect(view.hitTest(CGPoint(x: 400, y: 20), with: nil) == nil)
            #expect(view.hitTest(CGPoint(x: 20, y: 220), with: nil) != nil)
            #expect(view.hitTest(CGPoint(x: 20, y: 20), with: nil) == nil)

            view.model.visibility.readout = true
            #expect(view.hitTest(CGPoint(x: 20, y: 20), with: nil) != nil)
            #expect(view.hitTest(CGPoint(x: 20, y: 100), with: nil) != nil)

            // A collapsed header reports only its current bounds. Hiding the
            // overlay preserves measured geometry for when it becomes visible again.
            view.model.readoutFrame = CGRect(x: 8, y: 8, width: 300, height: 36)
            #expect(view.hitTest(CGPoint(x: 20, y: 20), with: nil) != nil)
            #expect(view.hitTest(CGPoint(x: 20, y: 100), with: nil) == nil)
            view.model.visibility.readout = false
            #expect(view.hitTest(CGPoint(x: 20, y: 20), with: nil) == nil)
            view.model.visibility.readout = true
            #expect(view.hitTest(CGPoint(x: 20, y: 20), with: nil) != nil)

            view.isHidden = true
            #expect(view.hitTest(CGPoint(x: 20, y: 220), with: nil) == nil)
            view.isHidden = false
            #expect(view.hitTest(CGPoint(x: 20, y: 20), with: nil) != nil)
        }
    }
#endif
