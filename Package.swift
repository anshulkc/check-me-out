// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "CheckMeOut",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "CheckMeOut",
            targets: ["CheckMeOut"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/supabase/supabase-swift.git",
            from: "2.0.0"
        ),
    ],
    targets: [
        .target(
            name: "CheckMeOut",
            dependencies: [
                .product(
                    name: "Supabase",
                    package: "supabase-swift"
                ),
            ]),
        .testTarget(
            name: "CheckMeOutTests",
            dependencies: ["CheckMeOut"]),
    ]
)
