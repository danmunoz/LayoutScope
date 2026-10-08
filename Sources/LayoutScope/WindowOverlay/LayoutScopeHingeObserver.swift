import SwiftUI

#if DEBUG
    enum LayoutScopeHingeState: Equatable {
        case unsupported
        case awaitingUpdate
        case unavailable
        case reading(status: String, angleDegrees: Double)

        static var initial: Self {
            if #available(iOS 27.1, *) { return .awaitingUpdate }
            return .unsupported
        }

        @available(iOS 27.1, *)
        init(hinge: DeviceHinge?) {
            guard let hinge else {
                self = .unavailable
                return
            }
            self.init(status: hinge.status, angle: hinge.angle)
        }

        @available(iOS 27.1, *)
        init(status: DeviceHinge.Status, angle: Angle) {
            let label: String
            if status == .closed {
                label = ".closed"
            } else if status == .partiallyOpen {
                label = ".partiallyOpen"
            } else if status == .fullyOpen {
                label = ".fullyOpen"
            } else {
                label = "unknown"
            }
            self = .reading(status: label, angleDegrees: angle.degrees)
        }

        var readout: String {
            switch self {
            case .unsupported: "hinge · requires iOS 27.1"
            case .awaitingUpdate: "hinge · awaiting update"
            case .unavailable: "hinge · unavailable"
            case let .reading(status, angleDegrees):
                "hinge · \(String(format: "%.1f", angleDegrees))° | status: \(status)"
            }
        }
    }

    struct LayoutScopeHingeObserver: ViewModifier {
        let update: (LayoutScopeHingeState) -> Void

        func body(content: Content) -> some View {
            if #available(iOS 27.1, *) {
                content.onHingeChange { _, context in
                    update(LayoutScopeHingeState(hinge: context.hinge))
                }
            } else {
                content
            }
        }
    }
#endif
