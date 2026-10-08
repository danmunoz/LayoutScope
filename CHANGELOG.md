# Changelog

## 1.2.0 — 2026-10-08

- Add `hidden` to `.layoutScopeOverlay()` to control the entire window overlay.
- Introduce `.viewLayoutScopeOverlay()` with a compact view readout showing origin,
  size, size classes, safe-area insets, and available content margins.
- Keep `.localLayoutScopeOverlay()` as a deprecated compatibility alias for 1.0.0 callers.
- Improve view safe-area measurement and clip region guides to the inspected view.
- Redesign the window panel with a collapsible header, compact geometry rows,
  expandable division content areas, and retained disclosure state.
- Update the demo, screenshots, and installation instructions.

## 1.0.0 — 2026-10-07

- Initial SwiftPM release with debug-only window and local view diagnostics for
  safe areas, reserved regions, size classes, and hinge state.
- Support iOS 26 app targets; hinge and reserved-region readings require iOS 27.1.
