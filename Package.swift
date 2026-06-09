// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Xvideo",
    platforms: [
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
                .linkedFramework("UIKit")
            ]
        )
    ]
)
