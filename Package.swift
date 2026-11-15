// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Sumi",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "Sumi", targets: ["Sumi"]),
        .executable(name: "sumi", targets: ["SumiCLI"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-cmark.git", from: "0.8.0"),
        .package(path: "ThirdParty/libjpeg-turbo"),
        .package(path: "ThirdParty/libspng"),
        .package(path: "ThirdParty/libwebp")
    ],
    targets: [
        .target(name: "SumiLanguage"),
        .target(
            name: "Sumi",
            dependencies: [
                "SumiLanguage",
                .product(name: "cmark-gfm", package: "swift-cmark"),
                .product(name: "cmark-gfm-extensions", package: "swift-cmark"),
                .product(name: "JPEGTurbo", package: "libjpeg-turbo"),
                .product(name: "PNGCodec", package: "libspng"),
                .product(name: "WebP", package: "libwebp")
            ],
            exclude: [
                "Templates/DefaultTheme"
            ],
            plugins: [
                .plugin(name: "SumiAssetsPlugin")
            ]
        ),
        .executableTarget(name: "SumiCLI", dependencies: [
            "Sumi",
            "SumiLanguage"
        ]),
        .executableTarget(name: "SumiAssets"),
        .plugin(
            name: "SumiAssetsPlugin",
            capability: .buildTool(),
            dependencies: ["SumiAssets"]
        ),
        .testTarget(name: "SumiTests", dependencies: [
            "Sumi",
            "SumiLanguage",
            .product(name: "JPEGTurbo", package: "libjpeg-turbo"),
            .product(name: "PNGCodec", package: "libspng"),
            .product(name: "WebP", package: "libwebp")
        ], exclude: ["Fixtures"]),
        .testTarget(name: "SumiLanguageTests", dependencies: ["SumiLanguage"])
    ]
)
