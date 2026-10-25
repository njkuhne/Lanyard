// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Dotlocal",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Dotlocal", targets: ["Dotlocal"])
    ],
    dependencies: [
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.1.0")
    ],
    targets: [
        .executableTarget(
            name: "Dotlocal",
            dependencies: ["Yams"],
            path: "Sources/Dotlocal"
        ),
        .testTarget(
            name: "DotlocalTests",
            dependencies: ["Dotlocal"],
            path: "Tests/DotlocalTests",
            exclude: ["__Snapshots__"]
        ),
    ]
)
