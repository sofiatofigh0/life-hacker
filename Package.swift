// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AureliaWellness",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "WellnessCore", targets: ["WellnessCore"])],
    targets: [
        .target(name: "WellnessCore"),
        .testTarget(name: "WellnessCoreTests", dependencies: ["WellnessCore"])
    ]
)
