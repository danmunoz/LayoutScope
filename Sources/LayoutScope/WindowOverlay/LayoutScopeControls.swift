import SwiftUI

#if DEBUG
    struct LayoutScopeControls: View {
        @Binding var visibility: LayoutScopeVisibility

        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Toggle(isOn: $visibility.safeArea) { Text(verbatim: "Safe areas") }
                Toggle(isOn: $visibility.occlusions) { Text(verbatim: "Occlusions") }
                Toggle(isOn: $visibility.divisions) { Text(verbatim: "Divisions") }
                Toggle(isOn: $visibility.includeInactive) { Text(verbatim: "Include inactive") }
                Toggle(isOn: $visibility.readout) { Text(verbatim: "Readout") }
            }
            .toggleStyle(.switch)
            .font(.footnote)
            .frame(width: 180)
            .padding()
            .background(.thinMaterial, in: .rect(cornerRadius: 12))
        }
    }

    #Preview("All layers") {
        @Previewable @State var visibility = LayoutScopeVisibility()
        LayoutScopeControls(visibility: $visibility)
    }

    #Preview("Readout and inactive regions hidden") {
        @Previewable @State var visibility = LayoutScopeVisibility(includeInactive: false, readout: false)
        LayoutScopeControls(visibility: $visibility)
    }
#endif
