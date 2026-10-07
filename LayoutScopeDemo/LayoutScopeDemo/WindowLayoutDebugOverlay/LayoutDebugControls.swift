import SwiftUI

#if DEBUG
    struct LayoutDebugVisibility: Equatable {
        var safeArea = true
        var includeInactive = true
        var occlusions = true
        var divisions = true
        var readout = true

        func shows(_ region: LayoutDebugRegion) -> Bool {
            (region.isActive || includeInactive) && (region.isDivision ? divisions : occlusions)
        }
    }

    struct LayoutDebugControls: View {
        @Binding var visibility: LayoutDebugVisibility

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
        @Previewable @State var visibility = LayoutDebugVisibility()
        LayoutDebugControls(visibility: $visibility)
    }

    #Preview("Readout and inactive regions hidden") {
        @Previewable @State var visibility = LayoutDebugVisibility(includeInactive: false, readout: false)
        LayoutDebugControls(visibility: $visibility)
    }
#endif
