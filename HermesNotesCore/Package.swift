// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "HermesNotesCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "HermesNotesCore", targets: ["HermesNotesCore"])
    ],
    targets: [
        .target(name: "HermesNotesCore"),
        .testTarget(
            name: "HermesNotesCoreTests",
            dependencies: ["HermesNotesCore"]
        ),
    ]
)
