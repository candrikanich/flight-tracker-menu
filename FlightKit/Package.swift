// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlightKit",
    platforms: [.macOS(.v15), .iOS(.v18)],
    products: [.library(name: "FlightKit", targets: ["FlightKit"])],
    targets: [
        .target(name: "FlightKit"),
        .testTarget(
            name: "FlightKitTests",
            dependencies: ["FlightKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
