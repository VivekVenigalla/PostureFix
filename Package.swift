// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "PostureFix",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PostureFix",
            path: "Sources/PostureFix",
            linkerSettings: [
                .unsafeFlags([
                    "-Xlinker", "-sectcreate",
                    "-Xlinker", "__TEXT",
                    "-Xlinker", "__info_plist",
                    "-Xlinker", "Sources/PostureFix/Resources/Info.plist",
                ])
            ]
        )
    ]
)
