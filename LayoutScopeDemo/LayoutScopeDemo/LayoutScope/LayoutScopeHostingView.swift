import Observation
import SwiftUI
import UIKit

#if DEBUG
    @Observable
    final class LayoutScopeModel {
        var snapshot: LayoutScopeSnapshot?
        var visibility = LayoutScopeVisibility()
        var cornerRadii = RectangleCornerRadii()
        @ObservationIgnored var controlsFrame = CGRect.zero
    }

    struct LayoutScopeContent: View {
        @Bindable var model: LayoutScopeModel

        var body: some View {
            if let snapshot = model.snapshot {
                ZStack(alignment: .bottomLeading) {
                    LayoutScopeOverlay(snapshot: snapshot, visibility: model.visibility)
                    LayoutScopeControls(visibility: $model.visibility)
                        .onGeometryChange(for: CGRect.self) { proxy in
                            proxy.frame(in: .named("layoutScope"))
                        } action: { model.controlsFrame = $0 }
                        .padding(snapshot.readoutInsets)
                }
                .frame(width: snapshot.size.width, height: snapshot.size.height)
                .coordinateSpace(name: "layoutScope")
                .environment(\.layoutDirection, .leftToRight)
                // UIKit hosting boundaries do not forward SwiftUI container shapes.
                .containerShape(UnevenRoundedRectangle(cornerRadii: model.cornerRadii))
            }
        }
    }

    /// Hosts one renderer for the lifetime of a root attachment.
    final class LayoutScopeHostingView: UIView {
        var includeInactiveRegions = true {
            didSet {
                if oldValue != includeInactiveRegions { model.visibility.includeInactive = includeInactiveRegions }
            }
        }

        var hinge: LayoutScopeHingeState = .initial
        let model = LayoutScopeModel()
        private(set) var hostingController: UIHostingController<LayoutScopeContent>?
        private var displayLink: CADisplayLink?
        var snapshot: LayoutScopeSnapshot? {
            model.snapshot
        }

        deinit {
            displayLink?.invalidate()
        }

        override init(frame: CGRect) {
            super.init(frame: frame)
            isOpaque = false
            backgroundColor = .clear
            isUserInteractionEnabled = true
            clipsToBounds = true
            autoresizingMask = [.flexibleWidth, .flexibleHeight]
            registerForTraitChanges([UITraitHorizontalSizeClass.self, UITraitVerticalSizeClass.self]) { (view: LayoutScopeHostingView, _: UITraitCollection) in
                view.refresh()
            }
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            displayLink?.invalidate()
            displayLink = nil
            updateHostingParent()
            guard window != nil else { return }
            // Reserved-region activity can change without a layout callback.
            let link = CADisplayLink(target: LayoutScopeDisplayLinkTarget(overlay: self), selector: #selector(LayoutScopeDisplayLinkTarget.tick))
            link.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 10, preferred: 10)
            link.add(to: .main, forMode: .common)
            displayLink = link
            refresh()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            hostingController?.view.frame = bounds
            refresh()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            refresh()
        }

        func refresh() {
            guard let window, !window.isHidden else { return }
            let windowFrame = superview?.convert(window.bounds, from: window) ?? window.bounds
            if frame != windowFrame { frame = windowFrame }
            if superview?.subviews.last !== self { superview?.bringSubviewToFront(self) }
            let direction: LayoutDirection = window.effectiveUserInterfaceLayoutDirection == .rightToLeft ? .rightToLeft : .leftToRight
            display(LayoutScopeSnapshot(
                size: bounds.size,
                safeAreaInsets: directional(window.safeAreaInsets, direction: direction),
                contentMargins: nil,
                regions: reservedRegions(in: window, direction: direction),
                isWindow: true,
                includeInactiveRegions: model.visibility.includeInactive,
                layoutDirection: direction,
                hinge: hinge,
                horizontalSizeClass: sizeClass(window.traitCollection.horizontalSizeClass),
                verticalSizeClass: sizeClass(window.traitCollection.verticalSizeClass)
            ))
        }

        func display(_ snapshot: LayoutScopeSnapshot) {
            guard snapshot != model.snapshot else { return }
            model.snapshot = snapshot
            if hostingController == nil {
                let controller = UIHostingController(rootView: LayoutScopeContent(model: model))
                // Explicit window measurements already account for safe areas.
                controller.safeAreaRegions = []
                controller.view.isOpaque = false
                controller.view.backgroundColor = .clear
                controller.view.isUserInteractionEnabled = true
                controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                hostingController = controller
                addSubview(controller.view)
            }
            hostingController?.view.frame = bounds
            updateHostingParent()
        }

        private func updateHostingParent() {
            guard let controller = hostingController else { return }
            let parent = window?.rootViewController
            guard controller.parent !== parent else { return }
            if controller.parent != nil {
                controller.willMove(toParent: nil)
                controller.removeFromParent()
            }
            if let parent {
                parent.addChild(controller)
                controller.didMove(toParent: parent)
            }
        }

        private func reservedRegions(in window: UIWindow, direction: LayoutDirection) -> [LayoutScopeRegion]? {
            guard #available(iOS 27.1, *) else { return nil }
            let options: UIView.ReservedRegion.QueryOptions = model.visibility.includeInactive ? .includeInactive : []
            return [UIView.ReservedRegion.Kind.division, .occlusion].flatMap { kind in
                window.reservedRegions(kind: kind, options: options).map {
                    LayoutScopeRegion(frame: $0.frame, margins: directional($0.margins, direction: direction), isActive: $0.isActive, isDivision: kind == .division, id: AnyHashable($0.id))
                }
            }
        }

        /// Only the controls intercept touches. Canvas and readout remain passthrough.
        override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
            guard model.controlsFrame.contains(point) else { return nil }
            return super.hitTest(point, with: event)
        }

        private func sizeClass(_ sizeClass: UIUserInterfaceSizeClass) -> UserInterfaceSizeClass? {
            switch sizeClass {
            case .compact: .compact
            case .regular: .regular
            default: nil
            }
        }

        private func directional(_ insets: UIEdgeInsets, direction: LayoutDirection) -> EdgeInsets {
            EdgeInsets(top: insets.top, leading: direction == .leftToRight ? insets.left : insets.right, bottom: insets.bottom, trailing: direction == .leftToRight ? insets.right : insets.left)
        }
    }

    private final class LayoutScopeDisplayLinkTarget: NSObject {
        private weak var overlay: LayoutScopeHostingView?

        init(overlay: LayoutScopeHostingView) {
            self.overlay = overlay
        }

        @objc func tick() {
            overlay?.refresh()
        }
    }
#endif
