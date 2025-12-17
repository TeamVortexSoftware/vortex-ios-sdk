// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VortexSDK",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "VortexSDK",
            targets: ["VortexSDK"]
        )
    ],
    dependencies: [
        // OpenAPI runtime for generated API client
        .package(url: "https://github.com/apple/swift-openapi-runtime.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "VortexSDK",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession")
            ],
            path: "Sources/VortexSDK"
        ),
        .testTarget(
            name: "VortexSDKTests",
            dependencies: ["VortexSDK"],
            path: "Tests/VortexSDKTests"
        )
    ]
)
