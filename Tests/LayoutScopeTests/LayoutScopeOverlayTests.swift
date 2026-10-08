@testable import LayoutScope
import SwiftUI
import Testing
import UIKit

#if DEBUG
    @MainActor
    @Suite(.serialized)
    struct LayoutScopeOverlayTests {
        @Test func consumedInsetsProduceNoGuidesButRemainAvailableForReadout() {
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [])
            #expect(snapshot.guides.isEmpty)
            #expect(snapshot.readoutData().safeAreaInsets == EdgeInsets())
            #expect(snapshot.readoutData().regionsAvailable)
        }

        @available(iOS 27.1, *)
        @Test func sdkHingeStatusesMapToHumanReadableLabels() {
            let cases: [(DeviceHinge.Status, Angle, String, Double)] = [
                (.closed, .degrees(0), "Closed", 0),
                (.partiallyOpen, .radians(.pi / 2), "Partially open", 90),
                (.fullyOpen, .degrees(180), "Fully open", 180),
            ]
            for (status, angle, expected, degrees) in cases {
                let state = LayoutScopeHingeState(status: status, angle: angle)
                guard case let .reading(label, actualDegrees) = state else {
                    Issue.record("Expected a live hinge reading")
                    continue
                }
                #expect(label == expected)
                #expect(actualDegrees == degrees)
            }
        }

        @Test func contextPreservesWaitingUnsupportedAndUnavailableStates() {
            func context(for state: LayoutScopeHingeState) -> String {
                LayoutScopeSnapshot(size: .zero, safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [], hinge: state).readoutData().context
            }
            #expect(context(for: .awaitingUpdate).contains("Awaiting hinge update"))
            #expect(context(for: .unsupported).contains("Hinge unavailable on this OS"))
            #expect(context(for: .unavailable).contains("Hinge unavailable"))
        }

        @Test func onlyPresentEdgesProduceGuides() throws {
            let guides = LayoutScopeGeometry.insetGuides(EdgeInsets(top: 20, leading: 0, bottom: 0, trailing: 0), size: CGSize(width: 300, height: 400), layoutDirection: .leftToRight, color: .cyan)
            let guide = try #require(guides.first)
            #expect(guides.count == 1)
            #expect(guide.fill == CGRect(x: 0, y: 0, width: 300, height: 20))
            #expect(guide.outline.boundingRect == CGRect(x: 0, y: 20, width: 300, height: 0))
        }

        @Test func leadingMarginMovesToRightInRTL() throws {
            let guides = LayoutScopeGeometry.insetGuides(EdgeInsets(top: 0, leading: 18, bottom: 0, trailing: 0), size: CGSize(width: 300, height: 400), layoutDirection: .rightToLeft, color: .green)
            let guide = try #require(guides.first)
            #expect(guides.count == 1)
            #expect(guide.fill == CGRect(x: 282, y: 0, width: 18, height: 400))
        }

        @Test func negativeAndOversizedInsetsStayWithinViewport() {
            let size = CGSize(width: 300, height: 400)
            let guides = LayoutScopeGeometry.insetGuides(EdgeInsets(top: 500, leading: -10, bottom: -20, trailing: 600), size: size, layoutDirection: .leftToRight, color: .cyan)
            #expect(guides.count == 2)
            #expect(guides.allSatisfy { CGRect(origin: .zero, size: size).contains($0.fill) })
        }

        @Test func zeroSizedViewportHasNoGuidesOrVisibleRegions() {
            let snapshot = LayoutScopeSnapshot(size: .zero, safeAreaInsets: EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 0), contentMargins: nil, regions: [region(CGRect(x: 0, y: 0, width: 20, height: 400))])
            #expect(snapshot.visibleRegions.isEmpty)
            #expect(snapshot.guides.isEmpty)
        }

        @Test func inactiveRegionsKeepTheirDashedFaintGuideStyle() throws {
            let inactive = LayoutScopeRegion(frame: CGRect(x: 20, y: 20, width: 40, height: 60), margins: EdgeInsets(), isActive: false, isDivision: false)
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [inactive])
            let guide = try #require(snapshot.guides.first)
            #expect(guide.opacity < 1)
            #expect(!guide.dash.isEmpty)
            #expect(guide.fill == inactive.frame)
        }

        @Test func windowReadoutOmitsViewMarginsAndNonintersectingRegions() {
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20), regions: [region(CGRect(x: 400, y: 0, width: 20, height: 400))], isWindow: true)
            #expect(snapshot.readoutData().regions.isEmpty)
        }

        @Test func readoutInsetsKeepWindowSafeAreaAndViewPlacements() {
            let window = LayoutScopeSnapshot(
                size: CGSize(width: 600, height: 400),
                safeAreaInsets: EdgeInsets(top: 20, leading: 84, bottom: 34, trailing: 12),
                contentMargins: nil,
                regions: [],
                isWindow: true,
                layoutDirection: .rightToLeft,
            )
            #expect(window.readoutInsets == EdgeInsets(top: 28, leading: 20, bottom: 42, trailing: 92))

            let view = LayoutScopeSnapshot(size: window.size, safeAreaInsets: window.safeAreaInsets, contentMargins: nil, regions: [])
            #expect(view.readoutInsets == EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }

        @Test func readoutIdentitySurvivesFrameReorderAndHingeUpdates() {
            var first = region(CGRect(x: 100, y: 0, width: 20, height: 400))
            first.id = AnyHashable("first")
            var second = region(CGRect(x: 200, y: 0, width: 20, height: 400))
            second.id = AnyHashable("second")
            let before = LayoutScopeSnapshot(size: CGSize(width: 600, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [first, second], hinge: .unavailable)
            first = LayoutScopeRegion(frame: CGRect(x: 120, y: 0, width: 30, height: 400), margins: EdgeInsets(), isActive: true, isDivision: true, id: AnyHashable("first"))
            let after = LayoutScopeSnapshot(size: before.size, safeAreaInsets: before.safeAreaInsets, contentMargins: nil, regions: [second, first], hinge: .reading(status: "Fully open", angleDegrees: 180))
            let oldIDs = Set(before.readoutData().regions.map(\.id))
            let newIDs = Set(after.readoutData().regions.map(\.id))
            #expect(oldIDs == newIDs)
            #expect(newIDs.count == after.readoutData().regions.count)
            #expect(newIDs.allSatisfy { $0.kind == .division })
        }

        @MainActor @Test func swiftUIHostingReusesContentAndKeepsFullWindowBounds() throws {
            let size = CGSize(width: 600, height: 400)
            let overlay = LayoutScopeHostingView(frame: CGRect(origin: .zero, size: size))
            var snapshot = LayoutScopeSnapshot(size: size, safeAreaInsets: EdgeInsets(top: 44, leading: 0, bottom: 34, trailing: 84), contentMargins: nil, regions: [], isWindow: true)
            overlay.display(snapshot)
            let content = try #require(overlay.subviews.first)
            #expect(overlay.hostingController?.safeAreaRegions == [])
            #expect(content.frame == overlay.bounds)
            #expect(overlay.isUserInteractionEnabled)
            #expect(content.isUserInteractionEnabled)
            #expect(!content.isOpaque)
            #expect(!overlay.accessibilityElementsHidden)
            snapshot.hinge = .reading(status: "Partially open", angleDegrees: 90)
            overlay.display(snapshot)
            #expect(overlay.subviews.count == 1)
            #expect(overlay.subviews.first === content)
            #expect(overlay.snapshot == snapshot)
        }

        @MainActor @Test func rendererKeepsWindowSizedGuidesAndLargeCornerAccommodation() throws {
            let size = CGSize(width: 600, height: 400)
            let snapshot = LayoutScopeSnapshot(size: size, safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84), contentMargins: nil, regions: [], isWindow: true)
            let renderer = ImageRenderer(content: LayoutScopeOverlay(snapshot: snapshot).frame(width: size.width, height: size.height).containerShape(.rect(cornerRadius: 80)))
            renderer.scale = 1
            let bitmap = try #require(renderer.uiImage?.cgImage)
            #expect(try alpha(in: bitmap, at: CGPoint(x: 16, y: 16)) == 0)
            #expect(try alpha(in: bitmap, at: CGPoint(x: 90, y: 16)) > 0)
            #expect(try alpha(in: bitmap, at: CGPoint(x: 300, y: 200)) == 0)
            let bandAlpha = try alpha(in: bitmap, at: CGPoint(x: 580, y: 200))
            #expect(bandAlpha > 0 && bandAlpha < 255)
        }

        @Test func reservedFrameAlreadyIncludesMargins() {
            let region = LayoutScopeRegion(frame: CGRect(x: 100, y: 20, width: 40, height: 60), margins: EdgeInsets(top: 3, leading: 5, bottom: 7, trailing: 9), isActive: true, isDivision: true)
            #expect(region.occupiedFrame(layoutDirection: .leftToRight) == CGRect(x: 105, y: 23, width: 26, height: 50))
            #expect(region.occupiedFrame(layoutDirection: .rightToLeft) == CGRect(x: 109, y: 23, width: 26, height: 50))
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [region])
            #expect(snapshot.guides.last?.outline.boundingRect == region.frame)
            #expect(snapshot.readoutData().regions.first?.frame == region.frame)
        }

        private func region(_ frame: CGRect) -> LayoutScopeRegion {
            LayoutScopeRegion(frame: frame, margins: EdgeInsets(), isActive: true, isDivision: true)
        }

        private func alpha(in image: CGImage, at point: CGPoint) throws -> UInt8 {
            try rgba(in: image, at: point)[3]
        }

        private func rgba(in image: CGImage, at point: CGPoint) throws -> [UInt8] {
            let pixel = try #require(image.cropping(to: CGRect(origin: point, size: CGSize(width: 1, height: 1))))
            var rgba = [UInt8](repeating: 0, count: 4)
            try rgba.withUnsafeMutableBytes { bytes in
                let context = try #require(CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            return rgba
        }
    }
#endif
