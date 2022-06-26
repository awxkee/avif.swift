// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "avif",
    platforms: [.iOS(.v14), .macOS(.v12), .macCatalyst(.v14)],
    products: [
        .library(
            name: "avif",
            targets: ["avif"]),
        .library(
            name: "avifnuke",
            targets: ["avifnuke"]),
    ],
    dependencies: [
        .package(url: "https://github.com/awxkee/libsvtav1enc.swift.git", branch: "master"),
        .package(url: "https://github.com/awxkee/libdav1d.swift.git", branch: "master"),
        .package(url: "https://github.com/awxkee/libyuv.swift.git", branch: "master"),
        .package(url: "https://github.com/kean/Nuke.git", from: "10.0.0")
    ],
    targets: [
        .target(
            name: "avifnuke",
            dependencies: ["avif", .product(name: "Nuke", package: "Nuke"), "avifc"]),
        .target(
            name: "avif",
            dependencies: ["avifc"]),
        .target(name: "avifc",
                dependencies: [.target(name: "libavif")],
                linkerSettings: [
                    .linkedFramework("Accelerate")
                ]),
        .target(name: "libavif",
                dependencies: [
                    .product(name: "libSvtAv1Enc", package: "libsvtav1enc.swift"),
                               .product(name: "libdav1d", package: "libdav1d.swift"),
                               .product(name: "libyuv", package: "libyuv.swift")],
                publicHeadersPath: "include",
                cSettings: [
                    .define("AVIF_CODEC_AOM_ENCODE", to: "0"),
                    .define("AVIF_CODEC_DAV1D", to: "1"),
                    .define("AVIF_CODEC_SVT", to: "1"),
                    .define("AVIF_CODEC_AOM_DECODE", to: "0"),
                    .define("AVIF_LIBYUV_ENABLED", to: "1")
                ],
                cxxSettings: [
                    .define("AVIF_CODEC_AOM_ENCODE", to: "0"),
                    .define("AVIF_CODEC_DAV1D", to: "1"),
                    .define("AVIF_CODEC_SVT", to: "1"),
                    .define("AVIF_CODEC_AOM_DECODE", to: "0"),
                    .define("AVIF_LIBYUV_ENABLED", to: "1")
                ])
    ]
)
