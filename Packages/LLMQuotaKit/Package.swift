// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "LLMQuotaKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LLMQuotaKit", targets: ["LLMQuotaKit"])
    ],
    targets: [
        .target(
            name: "LLMQuotaKit",
            path: "Sources/LLMQuotaKit"
        )
    ]
)
