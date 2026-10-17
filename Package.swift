// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Lanyard",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Lanyard", targets: ["Lanyard"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .executableTarget(
            name: "Lanyard",
            dependencies: ["Yams"],
            path: "Sources/Lanyard"
        )
    ]
)
