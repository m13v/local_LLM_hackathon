// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "localLLMhackathon",
    dependencies: [
        .package(url: "https://github.com/daltoniam/Starscream.git", from: "4.0.0")
    ],
    targets: [
        .target(
            name: "YourTargetName",
            dependencies: ["Starscream"],
            path: "Sources/YourTargetName"
        ),
        // ... other targets ...
    ]
)
