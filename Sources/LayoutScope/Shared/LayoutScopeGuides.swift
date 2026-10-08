import SwiftUI

#if DEBUG
    struct LayoutScopeGuides: View {
        let guides: [LayoutScopeGuide]

        var body: some View {
            Canvas { context, _ in
                for guide in guides {
                    context.fill(Path(guide.fill), with: .color(guide.color.opacity(guide.fillOpacity * guide.opacity)))
                    context.stroke(guide.outline, with: .color(guide.color.opacity(guide.opacity)), style: StrokeStyle(lineWidth: guide.lineWidth, dash: guide.dash))
                }
            }
        }
    }
#endif
