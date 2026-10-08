# LayoutScope

A small SwiftUI debug overlay for inspecting window layout on iPhone Duo and other
iOS devices. It shows safe areas, reserved regions, size classes, and hinge state.
No external dependencies; both modifiers are no-ops in release builds.

Requires **Xcode 27.1+, Swift 6.2+, and iOS 26+**. Hinge and reserved-region
readings require iOS 27.1; hinge data depends on the device.

<p>
  <a href="Images/duo-closed.png"><img src="Images/duo-closed.png" alt="LayoutScopeDemo on iPhone Duo, closed" width="280"></a>
  <a href="Images/duo-open.png"><img src="Images/duo-open.png" alt="LayoutScopeDemo on iPhone Duo, fully open" width="480"></a>
</p>

## Install in Xcode

1. Choose **File → Add Package Dependencies…** and enter:
   ```text
   https://github.com/danmunoz/LayoutScope.git
   ```
2. Select **Up to Next Major Version**, set the minimum version to **1.0.0**, then
   choose **Add Package**. SwiftPM resolves this version range from the repository's
   release tags, so the `1.0.0` tag must be published before the dependency can resolve.
3. Add the **LayoutScope** library product to your app target.

## Use

Import `LayoutScope` and attach the modifier **once to the root view inside each
`WindowGroup`**, in your app's scene declaration:

```swift
import LayoutScope
import SwiftUI

@main
struct ExampleApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .layoutScopeOverlay()
        }
    }
}
```

The bottom-left switches show or hide safe areas, inactive regions, occlusions,
divisions, and the entire readout. Inactive regions are included by default;
start without them using `.layoutScopeOverlay(includeInactiveRegions: false)`. To
hide the entire LayoutScope overlay programmatically, use
`.layoutScopeOverlay(hidden: true)`; `hidden` defaults to `false`.
The guides and readout pass touches through to your app; only the switches intercept them.

To inspect an individual view, apply `.localLayoutScopeOverlay()` to the content
inside the layout modifiers you want to inspect:

```swift
Color.yellow.opacity(0.3)
    .localLayoutScopeOverlay()
    .ignoresSafeArea()
```

Modifier order matters: `ignoresSafeArea` expands its inner content while its
outer frame can still be the safe-area-sized proposal. Putting the diagnostic
modifier after it inspects that outer frame instead of the expanded content.
Similarly, put the overlay inside `contentMargins` to read those margins.

The local overlay draws only safe-area overlap within the inspected bounds;
a view that fits inside the safe area has no cyan guides. It also shows available
content margins in green and intersecting occlusions/divisions, clipped to the
view. Inactive regions appear dashed by default; exclude them with
`.localLayoutScopeOverlay(includeInactiveRegions: false)`. This helper has no switches.
Its compact readout is aligned to the bottom center of the inspected view. It shows
the view origin in SwiftUI's global coordinate space, size, size classes, and only
nonzero safe-area insets and content margins.
Each inset label sits above its values, in top / leading / bottom / trailing order.
Hinge and reserved-region details belong to the window readout; local region guides
still render.

## Readout

- **Size classes:** `h` is horizontal; `v` is vertical.
- **Safe area:** insets in top / leading / bottom / trailing order, shown in cyan.
- **Hinge:** angle in degrees and current status, or awaiting/unavailable readings.
- **Regions:** pink occlusions and orange divisions, with active/inactive state,
  origin `(x, y)`, and size `(w, h)`. Divisions also list the content areas on both
  sides. Any included margins are already part of the region frame.

Dimensions are in points. Window coordinates start at the top-left; local
coordinates are relative to the inspected view.

To try it, open `LayoutScopeDemo/LayoutScopeDemo.xcodeproj` and run the
**LayoutScopeDemo** scheme on the Duo simulator. The screenshots above are from this demo.

## License

[MIT](LICENSE).
