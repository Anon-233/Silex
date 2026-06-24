// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "Silex",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "SilexCore", targets: ["SilexCore"]),
        .executable(name: "Silex", targets: ["SilexApp"]),
        .executable(name: "SilexDaemon", targets: ["SilexDaemon"]),
        .executable(name: "SilexTestRunner", targets: ["SilexTestRunner"])
    ],
    targets: [
        .systemLibrary(
            name: "CSQLite",
            path: "Sources/CSQLite"
        ),
        .target(
            name: "SilexCore",
            dependencies: ["CSQLite"],
            path: "Sources/SilexCore"
        ),
        .executableTarget(
            name: "SilexApp",
            dependencies: ["SilexCore"],
            path: "Sources/SilexApp",
            resources: [.process("Resources")]
        ),
        .executableTarget(
            name: "SilexDaemon",
            dependencies: ["SilexCore"],
            path: "Sources/SilexDaemon"
        ),
        .executableTarget(
            name: "SilexTestRunner",
            dependencies: ["SilexCore"],
            path: "Tests/SilexTestRunner",
            resources: [.copy("Fixtures")]
        )
    ],
    swiftLanguageModes: [.v5]
)
