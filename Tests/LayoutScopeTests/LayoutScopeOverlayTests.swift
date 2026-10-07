@testable import LayoutScope
import SwiftUI
import Testing
import UIKit

#if DEBUG
    @MainActor
    @Suite(.serialized)
    struct LayoutScopeOverlayTests {
        @Test func consumedInsetsProduceNoGuides() {
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [])
            #expect(snapshot.guides.isEmpty)
            #expect(snapshot.readout().contains { $0.text == "safe area insets · none" })
        }

        @Test func readoutOmitsCountsAndNumbersEachKind() {
            let frame = CGRect(x: 100, y: 20, width: 40, height: 60)
            let division = region(frame)
            let occlusion = LayoutScopeRegion(frame: frame, margins: EdgeInsets(), isActive: false, isDivision: false)
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [occlusion, division, occlusion])
            let labels = snapshot.readout().map(\.text)
            #expect(labels.first == "top / lead / bottom / trail")
            #expect(!labels.contains { $0.contains("count ·") })
            #expect(!labels.contains { $0.contains("included margins") })
            #expect(labels.contains("division #1 · active"))
            #expect(labels.contains("occlusion #1 · inactive"))
            #expect(labels.contains("occlusion #2 · inactive"))
            #expect(!labels.contains("occlusion #3 · inactive"))
        }

        @available(iOS 27.1, *)
        @Test func hingeStatusesAndAngleAreMappedFromSDKValues() {
            let cases: [(DeviceHinge.Status, Angle, String, Double)] = [
                (.closed, .degrees(0), ".closed", 0),
                (.partiallyOpen, .radians(.pi / 2), ".partiallyOpen", 90),
                (.fullyOpen, .degrees(180), ".fullyOpen", 180),
            ]
            for (status, angle, label, degrees) in cases {
                #expect(LayoutScopeHingeState(status: status, angle: angle) == .reading(status: label, angleDegrees: degrees))
            }
        }

        @available(iOS 27.1, *)
        @Test func nilHingeClearsStatusAndAngle() {
            let state = LayoutScopeHingeState(hinge: nil)
            #expect(state == .unavailable)
            #expect(state.readout == "hinge · unavailable")
        }

        @Test func hingeReadoutDistinguishesWaitingUnsupportedAndLiveValues() {
            #expect(LayoutScopeHingeState.awaitingUpdate.readout == "hinge · awaiting update")
            #expect(LayoutScopeHingeState.unsupported.readout == "hinge · requires iOS 27.1")
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [], hinge: .reading(status: "partially open", angleDegrees: 91.25))
            let labels = snapshot.readout().map(\.text)
            #expect(labels.filter { $0.hasPrefix("hinge") } == ["hinge · 91.2° | status: partially open"])
            #expect(!labels.contains { $0.contains("SDK id") })
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

        @Test func inactiveRegionsKeepTheirDashedFaintStyle() throws {
            let inactive = LayoutScopeRegion(frame: CGRect(x: 20, y: 20, width: 40, height: 60), margins: EdgeInsets(), isActive: false, isDivision: false)
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [inactive])
            let guide = try #require(snapshot.guides.first)
            #expect(guide.opacity < 1)
            #expect(!guide.dash.isEmpty)
            #expect(guide.fill == inactive.frame)
        }

        @Test func windowReadoutOmitsContentMarginsAndNonintersectingRegions() {
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [region(CGRect(x: 400, y: 0, width: 20, height: 400))], isWindow: true)
            let labels = snapshot.readout().map(\.text)
            #expect(!labels.contains { $0.hasPrefix("content margins") })
            #expect(!labels.contains { $0.contains("count ·") })
            #expect(!labels.contains { $0.hasPrefix("division #") })
        }

        @Test func onlyNonzeroLocalContentMarginsProduceReadoutRows() {
            var snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [])
            #expect(!snapshot.readout().contains { $0.text.hasPrefix("content margins") })
            snapshot = LayoutScopeSnapshot(size: snapshot.size, safeAreaInsets: snapshot.safeAreaInsets, contentMargins: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20), regions: [])
            #expect(snapshot.readout().contains { $0.text == "content margins · 0.0 / 20.0 / 0.0 / 20.0" })
            snapshot.isWindow = true
            #expect(!snapshot.readout().contains { $0.text.hasPrefix("content margins") })
        }

        @Test func regionReadoutIncludesOnlyNonzeroMargins() {
            let withMargins = LayoutScopeRegion(frame: CGRect(x: 100, y: 0, width: 40, height: 400), margins: EdgeInsets(top: 0, leading: 10, bottom: 0, trailing: 10), isActive: true, isDivision: true)
            let withoutMargins = region(CGRect(x: 200, y: 0, width: 20, height: 400))
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [withMargins, withoutMargins])
            #expect(snapshot.readout().filter { $0.text.contains("included margins") }.map(\.text) == ["  included margins · 0.0 / 10.0 / 0.0 / 10.0"])
        }

        @Test func windowReadoutUsesPhysicalSafeInsetsInRTL() {
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 600, height: 400), safeAreaInsets: EdgeInsets(top: 20, leading: 84, bottom: 34, trailing: 12), contentMargins: nil, regions: [], isWindow: true, layoutDirection: .rightToLeft)
            #expect(snapshot.readoutInsets == EdgeInsets(top: 28, leading: 20, bottom: 42, trailing: 92))
        }

        @Test func localReadoutDoesNotReapplySafeInsets() {
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 600, height: 400), safeAreaInsets: EdgeInsets(top: 44, leading: 84, bottom: 34, trailing: 12), contentMargins: nil, regions: [])
            #expect(snapshot.readoutInsets == EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
        }

        @Test func readoutIdentitySurvivesHingeChangesAndRegionReordering() {
            var first = region(CGRect(x: 100, y: 0, width: 20, height: 400))
            first.id = AnyHashable("first")
            var second = region(CGRect(x: 200, y: 0, width: 20, height: 400))
            second.id = AnyHashable("second")
            let before = LayoutScopeSnapshot(size: CGSize(width: 600, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [first, second], hinge: .unavailable)
            let after = LayoutScopeSnapshot(size: before.size, safeAreaInsets: before.safeAreaInsets, contentMargins: nil, regions: [second, first], hinge: .reading(status: "fully open", angleDegrees: 180))
            #expect(Set(before.readout().map(\.id)).isSubset(of: Set(after.readout().map(\.id))))
            #expect(Set(after.readout().map(\.id)).count == after.readout().count)
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
            snapshot.hinge = .reading(status: "partially open", angleDegrees: 90)
            overlay.display(snapshot)
            #expect(overlay.subviews.count == 1)
            #expect(overlay.subviews.first === content)
            #expect(overlay.snapshot == snapshot)
            let point = CGPoint(x: 20, y: 20)
            #expect(overlay.hitTest(point, with: nil) == nil)
        }

        @MainActor @Test func swiftUIRendererProducesWindowSizedPreview() throws {
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 600, height: 400), safeAreaInsets: EdgeInsets(top: 0, leading: 0, bottom: 34, trailing: 84), contentMargins: nil, regions: [], isWindow: true, hinge: .reading(status: "partially open", angleDegrees: 90))
            let renderer = ImageRenderer(content: LayoutScopeOverlay(snapshot: snapshot).frame(width: snapshot.size.width, height: snapshot.size.height))
            renderer.scale = 1
            let image = try #require(renderer.uiImage)
            #expect(image.size == snapshot.size)
            let bitmap = try #require(image.cgImage)
            #expect(try alpha(in: bitmap, at: CGPoint(x: 300, y: 200)) == 0)
            let bandAlpha = try alpha(in: bitmap, at: CGPoint(x: 580, y: 200))
            #expect(bandAlpha > 0 && bandAlpha < 255)
            let previewURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("layout-scope-preview.png")
            try #require(image.pngData()).write(to: previewURL)
            print("LayoutScopePreview: \(previewURL.path)")
        }

        @MainActor @Test func readoutBackgroundFollowsLargeContainerCorner() throws {
            let size = CGSize(width: 600, height: 400)
            let snapshot = LayoutScopeSnapshot(size: size, safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [], isWindow: true)
            // Leave the image unclipped: the panel itself must avoid the screen curve.
            let renderer = ImageRenderer(content: LayoutScopeOverlay(snapshot: snapshot)
                .frame(width: size.width, height: size.height)
                .containerShape(.rect(cornerRadius: 80)))
            renderer.scale = 1
            let bitmap = try #require(renderer.uiImage?.cgImage)
            #expect(try alpha(in: bitmap, at: CGPoint(x: 16, y: 16)) == 0)
            #expect(try alpha(in: bitmap, at: CGPoint(x: 90, y: 16)) > 0)
        }

        @Test func onlyIntersectingRegionsAppearIncludingDivisionLines() {
            let outside = region(CGRect(x: 400, y: 0, width: 20, height: 400))
            let partial = region(CGRect(x: 290, y: 20, width: 40, height: 50))
            let line = region(CGRect(x: 150, y: 0, width: 0, height: 400))
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: EdgeInsets(), regions: [outside, partial, line])
            #expect(snapshot.visibleRegions == [partial, line])
            #expect(snapshot.guides.count == 2)
        }

        @Test func reservedFrameAlreadyIncludesMargins() {
            let region = LayoutScopeRegion(frame: CGRect(x: 100, y: 20, width: 40, height: 60), margins: EdgeInsets(top: 3, leading: 5, bottom: 7, trailing: 9), isActive: true, isDivision: true)
            #expect(region.occupiedFrame(layoutDirection: .leftToRight) == CGRect(x: 105, y: 23, width: 26, height: 50))
            #expect(region.occupiedFrame(layoutDirection: .rightToLeft) == CGRect(x: 109, y: 23, width: 26, height: 50))
            let snapshot = LayoutScopeSnapshot(size: CGSize(width: 300, height: 400), safeAreaInsets: EdgeInsets(), contentMargins: nil, regions: [region])
            #expect(snapshot.guides.last?.outline.boundingRect == region.frame)
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
