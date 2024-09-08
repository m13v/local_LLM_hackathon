// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "localLLMhackathon",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/pvieito/PythonKit.git", from: "0.0.3")
    ],
    targets: [
        .target(
            name: "localLLMhackathon",
            dependencies: ["PythonKit"],
            path: "Sources"
        ),
    ]
)