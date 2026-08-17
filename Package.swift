// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "persnickety",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(url: "https://github.com/dduan/TOMLDecoder", from: "0.4.5")
    ],
    targets: [
        .executableTarget(name: "persnickety", dependencies: ["TOMLDecoder"])
    ]
)
