import SwiftUI
import UIKit

#if DEBUG
    /// UIKit resolves the safe area against the probe's actual bounds. A SwiftUI
    /// GeometryProxy can instead report the container's already-consumed insets.
    struct LayoutScopeViewSafeAreaProbe: UIViewRepresentable {
        let onChange: (EdgeInsets) -> Void
        @Environment(\.layoutDirection) private var layoutDirection

        func makeUIView(context: Context) -> ProbeView {
            ProbeView()
        }

        func updateUIView(_ view: ProbeView, context: Context) {
            view.onChange = onChange
            view.layoutDirection = layoutDirection
            view.refresh()
        }

        final class ProbeView: UIView {
            var onChange: ((EdgeInsets) -> Void)?
            var layoutDirection: LayoutDirection = .leftToRight
            private var previousInsets: EdgeInsets?

            override init(frame: CGRect) {
                super.init(frame: frame)
                isUserInteractionEnabled = false
                isOpaque = false
                backgroundColor = .clear
            }

            @available(*, unavailable)
            required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

            override func layoutSubviews() {
                super.layoutSubviews()
                refresh()
            }

            override func safeAreaInsetsDidChange() {
                super.safeAreaInsetsDidChange()
                refresh()
            }

            override func didMoveToWindow() {
                super.didMoveToWindow()
                refresh()
            }

            func refresh() {
                guard window != nil else { return }
                let insets = safeAreaInsets
                let value = EdgeInsets(
                    top: insets.top,
                    leading: layoutDirection == .leftToRight ? insets.left : insets.right,
                    bottom: insets.bottom,
                    trailing: layoutDirection == .leftToRight ? insets.right : insets.left
                )
                guard previousInsets != value else { return }
                previousInsets = value
                // UIKit can refresh during a SwiftUI layout/update pass.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.window != nil, self.previousInsets == value else { return }
                    self.onChange?(value)
                }
            }
        }
    }
#endif
