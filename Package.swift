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
        .package(url: "https://github.com/apple/swift-openapi-urlsession.git", from: "1.0.0"),
        // Google Sign-In for Google Contacts integration
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "VortexSDK",
            dependencies: [
                .product(name: "OpenAPIRuntime", package: "swift-openapi-runtime"),
                .product(name: "OpenAPIURLSession", package: "swift-openapi-urlsession"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "Sources/VortexSDK",
            resources: [
                .process("Resources/fa-solid-900.ttf"),
                .process("Resources/fa-brands-400.ttf"),
                .process("Resources/fa-regular-400.ttf")
            ]
        ),
        .testTarget(
            name: "VortexSDKTests",
            dependencies: ["VortexSDK"],
            path: "Tests/VortexSDKTests"
        )
    ]
)
