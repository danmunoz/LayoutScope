@testable import LayoutScope
import SwiftUI
import Testing
import UIKit

#if DEBUG
    @MainActor
    @Suite(.serialized)
    struct LayoutScopeLocalOverlayTests {
        @Test func ignoredSafeAreasDrawAtActualEdges() async throws {
            try await withWindow(name: "ignored") {
                Color.white.localLayoutScopeOverlay().ignoresSafeArea()
            } verify: { (window: UIWindow, image: CGImage) throws in
                let size = window.bounds.size
                let insets = window.safeAreaInsets
                try #require(insets.right > 20 && insets.bottom > 20)
                let y = size.height * 0.75
                #expect(try isCyan(image, at: CGPoint(x: size.width - 10, y: y)))
                #expect(try !isCyan(image, at: CGPoint(x: size.width - insets.right - 10, y: y)))
                #expect(try isCyan(image, at: CGPoint(x: size.width / 4, y: size.height - 10)))
                // The full clock occlusion must render, beyond the old clipped canvas.
                let pixel = try rgba(image, at: CGPoint(x: size.width - 10, y: 80))
                #expect(Int(pixel[0]) > Int(pixel[1]) + 5)
            }
        }

        @Test func respectedSafeAreasDoNotDrawConsumedInsets() async throws {
            try await withWindow(name: "respected") {
                Color.white.localLayoutScopeOverlay()
            } verify: { (window: UIWindow, image: CGImage) throws in
                let size = window.bounds.size
                let safe = window.safeAreaLayoutGuide.layoutFrame
                #expect(try !isCyan(image, at: CGPoint(x: safe.maxX - 10, y: size.height * 0.75)))
                #expect(try !isCyan(image, at: CGPoint(x: size.width / 4, y: safe.maxY - 10)))
                // Available container margins still render even when safe areas are consumed.
                let margin = try rgba(image, at: CGPoint(x: safe.minX + 10, y: size.height * 0.8))
                #expect(Int(margin[1]) > Int(margin[0]) + 5)
            }
        }

        @Test func ignoringOnlyBottomDoesNotDrawTrailingSafeArea() async throws {
            try await withWindow(name: "bottom-only") {
                Color.white.localLayoutScopeOverlay().ignoresSafeArea(edges: .bottom)
            } verify: { (window: UIWindow, image: CGImage) throws in
                let size = window.bounds.size
                let safe = window.safeAreaLayoutGuide.layoutFrame
                #expect(try isCyan(image, at: CGPoint(x: size.width / 4, y: size.height - 10)))
                #expect(try !isCyan(image, at: CGPoint(x: safe.maxX - 10, y: size.height * 0.75)))
            }
        }

        @Test func localProbeTracksNestedBoundsAndRTL() async throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            let root = UIViewController()
            window.rootViewController = root
            window.isHidden = false
            defer { window.isHidden = true }
            let probe = LayoutScopeLocalSafeAreaProbe.ProbeView()
            var readings: [EdgeInsets] = []
            probe.onChange = { readings.append($0) }
            root.view.addSubview(probe)
            window.layoutIfNeeded()
            let safe = window.safeAreaLayoutGuide.layoutFrame
            probe.frame = safe.insetBy(dx: 30, dy: 30)
            probe.layoutIfNeeded()
            probe.refresh()
            try await Task.sleep(for: .milliseconds(30))
            #expect(readings.last == EdgeInsets())
            probe.layoutDirection = .rightToLeft
            probe.frame = root.view.bounds
            probe.layoutIfNeeded()
            probe.refresh()
            try await Task.sleep(for: .milliseconds(30))
            #expect(readings.last?.leading == window.safeAreaInsets.right)
            #expect(readings.last?.trailing == window.safeAreaInsets.left)
            #expect(readings.last?.bottom == window.safeAreaInsets.bottom)
            #expect(!probe.isUserInteractionEnabled)
        }

        private func withWindow<V: View>(
            name: String,
            @ViewBuilder content: () -> V,
            verify: (UIWindow, CGImage) throws -> Void
        ) async throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            let controller = UIHostingController(rootView: content())
            controller.view.backgroundColor = .white
            window.rootViewController = controller
            window.isHidden = false
            defer { window.isHidden = true }
            window.layoutIfNeeded()
            controller.view.layoutIfNeeded()
            // Let the local UIKit measurement feed back into SwiftUI and render.
            try await Task.sleep(for: .milliseconds(250))
            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: window.bounds.size, format: format).image { _ in
                controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
            }
            let path = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("layoutscope-local-\(name).png")
            try image.pngData()?.write(to: path)
            try verify(window, #require(image.cgImage))
        }

        private func isCyan(_ image: CGImage, at point: CGPoint) throws -> Bool {
            let pixel = try rgba(image, at: point)
            return Int(pixel[1]) > Int(pixel[0]) + 5 && Int(pixel[2]) > Int(pixel[0]) + 5
        }

        private func rgba(_ image: CGImage, at point: CGPoint) throws -> [UInt8] {
            let pixel = try #require(image.cropping(to: CGRect(origin: point, size: CGSize(width: 1, height: 1))))
            var result = [UInt8](repeating: 0, count: 4)
            try result.withUnsafeMutableBytes { bytes in
                let context = try #require(CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue))
                context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            return result
        }
    }
#endif
