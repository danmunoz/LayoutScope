// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LayoutScope",
    platforms: [.iOS("26.0")],
    products: [
        .library(name: "LayoutScope", targets: ["LayoutScope"]),
    ],
    targets: [
        .target(
            name: "LayoutScope",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "LayoutScopeTests",
            dependencies: ["LayoutScope"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
