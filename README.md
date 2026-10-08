# LayoutScope

A small SwiftUI debug overlay for inspecting window layout on iPhone Duo and other
iOS devices. It shows safe areas, reserved regions, size classes, and hinge state.
No external dependencies; both modifiers are no-ops in release builds.

Requires **Xcode 27.1+, Swift 6.2+, and iOS 26+**. Hinge and reserved-region
readings and view content-margin measurements require iOS 27.1; hinge data depends
on the device.

<p>
  <a href="Images/duo-closed.png"><img src="Images/duo-closed.png" alt="LayoutScopeDemo on iPhone Duo, closed" width="280"></a>
  <a href="Images/duo-open.png"><img src="Images/duo-open.png" alt="LayoutScopeDemo on iPhone Duo, fully open with division details expanded" width="480"></a>
</p>

Closed and fully open Duo layouts in the demo, with the compact window readout.
The open screenshot shows the division's content areas and included margins.

## Install in Xcode

1. Choose **File → Add Package Dependencies…** and enter:
   ```text
   https://github.com/danmunoz/LayoutScope.git
   ```
2. Select **Up to Next Major Version**, set the minimum version to **1.0.0**, then
   choose **Add Package**. The `1.0.0` release tag is published.
3. Add the **LayoutScope** library product to your app target.

This README describes the current checkout. The published **1.0.0** release has
the earlier readout, uses `.localLayoutScopeOverlay()` for view diagnostics, and
does not include the window modifier's `hidden` parameter. To use the APIs and
panel shown below before the next release, clone this repository and add its
folder as a local package dependency in Xcode.

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
The guide drawings pass touches through to your app. The readout panel and bottom-left
switches accept touches within their visible bounds; the rest of the overlay passes
touches through.

To inspect an individual view, apply `.viewLayoutScopeOverlay()` to the content
inside the layout modifiers you want to inspect:

```swift
Color.yellow.opacity(0.3)
    .viewLayoutScopeOverlay()
    .ignoresSafeArea()
```

Modifier order matters: `ignoresSafeArea` expands its inner content while its
outer frame can still be the safe-area-sized proposal. Putting the diagnostic
modifier after it inspects that outer frame instead of the expanded content.
Similarly, put the overlay inside `contentMargins` to read those margins.

The view overlay draws only safe-area overlap within the inspected bounds;
a view that fits inside the safe area has no cyan guides. It also shows available
content margins in green and intersecting occlusions/divisions, clipped to the
view. Inactive regions appear dashed by default; exclude them with
`.viewLayoutScopeOverlay(includeInactiveRegions: false)`. This helper has no switches
and passes all touches through to the inspected view.
Its compact readout is aligned to the bottom center of the inspected view. It shows
the view origin in SwiftUI's global coordinate space, size, size classes, and only
nonzero safe-area insets and content margins.
Each inset label sits above its values, in top / leading / bottom / trailing order.
Hinge and reserved-region details belong to the window readout; view region guides
still render.

## Readout

The window readout is a compact, theme-adaptive panel. It starts expanded; tap its
header to collapse or reopen it. Its context line combines hinge angle and status
with horizontal (`H`) and vertical (`V`) size classes. A single safe-area line uses
a cyan guide dot and labels top (`T`), leading (`L`), bottom (`B`), and trailing
(`Tr`) values, including zero insets.
The Safe areas switch hides that line and its guides.

The region table keeps each region's origin `(x, y)` and size `(w, h)` on its row. Pink
occlusions are informational. Tap an orange division to show the available content
areas on either side and one included-margins line when any margins are nonzero;
its geometry row remains visible while expanded. Divisions start collapsed.
Included margins are already part of the SDK region frame and are not applied a
second time. Disclosure state is retained when the readout is hidden and shown
again. The panel scrolls when its contents exceed the available height.
Older systems show that reserved-region data requires iOS 27.1; an available but
empty result omits the region table.

Dimensions are in points. The window readout uses top-left window coordinates
and up to one decimal place, omitting redundant `.0` values. The view readout's
origin uses SwiftUI's global coordinate space; its guide geometry is relative to
the inspected view.

To try it, open `LayoutScopeDemo/LayoutScopeDemo.xcodeproj` and run the
**LayoutScopeDemo** scheme in **Debug** on the Duo simulator. The screenshots
above are from this demo.

## Source organization

`Sources/LayoutScope` groups the package implementation by responsibility:

- `WindowOverlay`: window modifier, hosting, controls, readout, and hinge observation.
- `ViewOverlay`: view modifier, compact readout, and view safe-area measurement.
- `Shared`: geometry, snapshots, guide rendering, and guide visibility.

## License

[MIT](LICENSE).
