import SwiftUI

#if DEBUG
    struct LayoutScopeVisibility: Equatable {
        var safeArea = true
        var includeInactive = true
        var occlusions = true
        var divisions = true
        var readout = true

        func shows(_ region: LayoutScopeRegion) -> Bool {
            (region.isActive || includeInactive) && (region.isDivision ? divisions : occlusions)
        }
    }
#endif
