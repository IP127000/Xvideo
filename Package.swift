// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "xvideo",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "xvideo", targets: ["xvideo"])
    ],
    targets: [
        .executableTarget(
            name: "xvideo",
            path: "Sources/xvideo",
            linkerSettings: [
                .linkedFramework("AVKit"),
                .linkedFramework("AppKit")
            ]
        )
    ]
)
