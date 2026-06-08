// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Xvideo",
    platforms: [
        .macOS(.v14),
        .iOS(.v17)
    ],
    products: [
        .executable(name: "Xvideo", targets: ["Xvideo"])
    ],
    targets: [
        .executableTarget(
            name: "Xvideo",
            path: "Sources/Xvideo",
            resources: [
                .copy("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AVKit"),
                .linkedFramework("WebKit"),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ]
        )
    ]
)
