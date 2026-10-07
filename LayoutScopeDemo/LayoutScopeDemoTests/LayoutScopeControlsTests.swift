@testable import LayoutScopeDemo
import SwiftUI
import Testing
import UIKit

#if DEBUG
    @MainActor
    @Suite(.serialized)
    struct LayoutScopeControlsTests {
        private var snapshot: LayoutScopeSnapshot {
            LayoutScopeSnapshot(
                size: CGSize(width: 600, height: 400),
                safeAreaInsets: EdgeInsets(top: 20, leading: 0, bottom: 34, trailing: 0),
                contentMargins: nil,
                regions: [
                    LayoutScopeRegion(frame: CGRect(x: 288, y: 0, width: 24, height: 400), margins: EdgeInsets(), isActive: false, isDivision: true),
                    LayoutScopeRegion(frame: CGRect(x: 516, y: 0, width: 84, height: 120), margins: EdgeInsets(), isActive: true, isDivision: false),
                ],
                isWindow: true,
                hinge: .reading(status: ".fullyOpen", angleDegrees: 180),
                horizontalSizeClass: .regular,
                verticalSizeClass: .compact
            )
        }

        @Test func readoutReportsBothCurrentSizeClasses() {
            #expect(snapshot.readout().contains { $0.text == "size classes · h: regular, v: compact" })
            var unspecified = snapshot
            unspecified.horizontalSizeClass = nil
            unspecified.verticalSizeClass = nil
            #expect(unspecified.readout().contains { $0.text == "size classes · h: unspecified, v: unspecified" })
        }

        @Test func safeAreaToggleHidesItsBandsAndReadout() {
            let visibility = LayoutScopeVisibility(safeArea: false)
            #expect(snapshot.guides(visibility: visibility).count == 2)
            #expect(!snapshot.readout(visibility: visibility).contains { $0.text.hasPrefix("safe area") })
        }

        @Test func inactiveTogglePreservesActiveOcclusions() {
            let visibility = LayoutScopeVisibility(includeInactive: false)
            #expect(snapshot.guides(visibility: visibility).count == 3)
            let text = snapshot.readout(visibility: visibility).map(\.text)
            #expect(!text.contains("division #1 · inactive"))
            #expect(text.contains("occlusion #1 · active"))
        }

        @Test func eachRegionKindCanBeHiddenIndependently() {
            let noDivisions = LayoutScopeVisibility(divisions: false)
            #expect(snapshot.guides(visibility: noDivisions).count == 3)
            #expect(!snapshot.readout(visibility: noDivisions).contains { $0.text.hasPrefix("division") })
            let noOcclusions = LayoutScopeVisibility(occlusions: false)
            #expect(snapshot.guides(visibility: noOcclusions).count == 3)
            #expect(!snapshot.readout(visibility: noOcclusions).contains { $0.text.hasPrefix("occlusion") })
        }

        @Test func hingeRemainsVisibleUntilEntireReadoutIsHidden() {
            let noGuides = LayoutScopeVisibility(safeArea: false, includeInactive: false, occlusions: false, divisions: false)
            #expect(snapshot.readout(visibility: noGuides).contains { $0.text == "hinge · 180.0° | status: .fullyOpen" })
            #expect(snapshot.readout(visibility: noGuides).contains { $0.text.hasPrefix("size classes") })
            #expect(snapshot.readout(visibility: LayoutScopeVisibility(readout: false)).isEmpty)
        }

        @Test func measurementAndHingeUpdatesPreserveToggleStateAndTouchPassthrough() throws {
            let view = LayoutScopeHostingView(frame: CGRect(origin: .zero, size: snapshot.size))
            view.model.visibility.readout = false
            view.model.visibility.includeInactive = false
            view.display(snapshot)
            let controller = try #require(view.hostingController)
            var next = snapshot
            next.hinge = .unavailable
            view.display(next)
            // Repeating the modifier's original option must not undo a user's toggle.
            view.includeInactiveRegions = true
            #expect(!view.model.visibility.readout)
            #expect(!view.model.visibility.includeInactive)
            #expect(view.hostingController === controller)
            view.model.controlsFrame = CGRect(x: 8, y: 200, width: 204, height: 158)
            #expect(view.hitTest(CGPoint(x: 300, y: 200), with: nil) == nil)
            #expect(view.hitTest(CGPoint(x: 8, y: 8), with: nil) == nil)
            #expect(view.hitTest(CGPoint(x: 20, y: 220), with: nil) != nil)
        }
    }
#endif
