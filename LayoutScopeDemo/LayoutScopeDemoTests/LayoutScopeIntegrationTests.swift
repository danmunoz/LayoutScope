@testable import LayoutScope
import SwiftUI
import Testing
import UIKit

#if DEBUG
    @MainActor
    @Suite(.serialized)
    struct LayoutScopeIntegrationTests {
        @MainActor @Test func attachedHostingKeepsGuidesAtWindowEdges() async throws {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.rootViewController = UIViewController()
            window.rootViewController?.view.backgroundColor = .white
            window.isHidden = false
            let overlay = LayoutScopeHostingView(frame: window.bounds)
            let root = try #require(window.rootViewController)
            root.view.addSubview(overlay)
            defer {
                overlay.removeFromSuperview()
                window.isHidden = true
            }
            window.layoutIfNeeded()
            overlay.layoutIfNeeded()
            let size = window.bounds.size
            let insets = window.safeAreaInsets
            try #require(insets.right > 20)
            try #require(insets.bottom > 20)
            let y = size.height * 0.65
            let boundary = size.width - insets.right
            let clock = ContinuousClock()
            let deadline = clock.now.advanced(by: .seconds(3))
            var bitmap: CGImage?
            repeat {
                let image = UIGraphicsImageRenderer(size: size, format: {
                    let format = UIGraphicsImageRendererFormat()
                    format.scale = 1
                    format.opaque = false
                    return format
                }()).image { _ in
                    overlay.drawHierarchy(in: overlay.bounds, afterScreenUpdates: true)
                }
                bitmap = image.cgImage
                if let bitmap, try isCyan(in: bitmap, at: CGPoint(x: boundary + 5, y: y)) { break }
                try await Task.sleep(for: .milliseconds(16))
            } while clock.now < deadline
            let rendered = try #require(bitmap)
            #expect(overlay.hostingController?.parent === window.rootViewController)
            #expect(overlay.hostingController?.view.isDescendant(of: root.view) == true)
            #expect(overlay.hostingController?.safeAreaRegions == [])
            #expect(try isCyan(in: rendered, at: CGPoint(x: size.width - 10, y: y)))
            #expect(try !isCyan(in: rendered, at: CGPoint(x: boundary - 10, y: y)))
            #expect(try isCyan(in: rendered, at: CGPoint(x: size.width / 4, y: size.height - 10)))
            let occlusion = try #require(overlay.snapshot?.visibleRegions.first { !$0.isDivision && $0.isActive && $0.frame.maxX >= size.width - 1 })
            #expect(try isPink(in: rendered, at: CGPoint(x: size.width - 10, y: occlusion.frame.midY)))
            let previewURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("layout-scope-attached-preview.png")
            try #require(UIImage(cgImage: rendered).pngData()).write(to: previewURL)
            print("LayoutScopeAttachedPreview: \(previewURL.path)")
            let controller = try #require(overlay.hostingController)
            overlay.removeFromSuperview()
            #expect(controller.parent == nil)
        }

        @MainActor @Test func attachmentFollowsOwningWindowAndCleansUp() throws {
            let first = try makeWindow(size: CGSize(width: 300, height: 400))
            let second = try makeWindow(size: CGSize(width: 400, height: 300))
            defer {
                first.isHidden = true
                second.isHidden = true
            }
            let firstRoot = try #require(first.rootViewController)
            let secondRoot = try #require(second.rootViewController)
            let probe = LayoutScopeAttachmentView()
            firstRoot.view.addSubview(probe)
            let controller = try #require(probe.overlay.hostingController)
            #expect(probe.overlay.superview === probe)
            #expect(controller.parent === firstRoot)
            #expect(controller.view.isDescendant(of: firstRoot.view))
            // Refresh must keep the overlay frontmost within its parent, without
            // moving it back into the window as a sibling of the root view.
            probe.addSubview(UIView())
            probe.overlay.refresh()
            #expect(probe.subviews.last === probe.overlay)
            secondRoot.view.addSubview(probe)
            #expect(!controller.view.isDescendant(of: firstRoot.view))
            #expect(probe.overlay.superview === probe)
            #expect(probe.overlay.hostingController === controller)
            #expect(controller.parent === secondRoot)
            #expect(controller.view.isDescendant(of: secondRoot.view))
            probe.removeFromSuperview()
            #expect(probe.overlay.superview == nil)
            #expect(controller.parent == nil)
        }

        private func isCyan(in image: CGImage, at point: CGPoint) throws -> Bool {
            let pixel = try rgba(in: image, at: point)
            return Int(pixel[1]) > Int(pixel[0]) + 5 && Int(pixel[2]) > Int(pixel[0]) + 5
        }

        private func isPink(in image: CGImage, at point: CGPoint) throws -> Bool {
            let pixel = try rgba(in: image, at: point)
            return Int(pixel[0]) > Int(pixel[1]) + 5
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

        @MainActor private func makeWindow(size: CGSize) throws -> UIWindow {
            let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
            let window = UIWindow(windowScene: scene)
            window.frame = CGRect(origin: .zero, size: size)
            window.rootViewController = UIViewController()
            window.isHidden = false
            return window
        }
    }
#endif
