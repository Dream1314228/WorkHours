// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "GSJilu",
    defaultLocalization: "zh-Hans",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .executable(name: "GSJilu", targets: ["GSJilu"])
    ],
    targets: [
        .executableTarget(
            name: "GSJilu",
            path: "Sources/GSJilu"
        )
    ]
)
