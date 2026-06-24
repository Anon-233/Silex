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
        .executable(name: "SilexSMARTService", targets: ["SilexSMARTService"])
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
            name: "SilexSMARTService",
            dependencies: ["SilexCore"],
            path: "Sources/SilexSMARTService"
        ),
        .testTarget(
            name: "SilexCoreTests",
            dependencies: ["SilexCore"],
            path: "Tests/SilexCoreTests",
            resources: [.copy("Fixtures")],
            swiftSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks"
                ])
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-F",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/Frameworks",
                    "-Xlinker",
                    "-rpath",
                    "-Xlinker",
                    "/Library/Developer/CommandLineTools/Library/Developer/usr/lib"
                ])
            ]
        )
    ],
    swiftLanguageModes: [.v5]
)
