// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "avif",
    platforms: [.iOS(.v13), .macOS(.v12), .macCatalyst(.v14), .watchOS(.v6), .tvOS(.v13)],
    products: [
        .library(
            name: "avif",
            targets: ["avif", "avifpixart"]),
        .library(
            name: "avifnuke",
            targets: ["avifnuke"]),
    ],
    dependencies: [
        .package(url: "https://github.com/awxkee/libaom.swift.git", "1.1.0"..<"1.2.0"),
        .package(url: "https://github.com/awxkee/libdav1d.swift.git", "1.3.0"..<"1.4.0"),
        .package(url: "https://github.com/kean/Nuke.git", "12.0.0"..<"13.0.0"),
        .package(url: "https://github.com/awxkee/libsvtav1enc.swift", "1.1.0"..<"1.2.0")
    ],
    targets: [
        .binaryTarget(name: "avifpixart", path: "Sources/AvifPixart/AvifPixart.xcframework"),
        .target(
            name: "avifnuke",
            dependencies: ["avif", .product(name: "Nuke", package: "Nuke"), "avifc"]),
        .target(
            name: "avif",
            dependencies: ["avifc", .target(name: "avifpixart")]),
        .target(name: "avifc",
                dependencies: [.target(name: "libavif")],
                cxxSettings: [.headerSearchPath(".")],
                linkerSettings: [
                    .linkedFramework("Accelerate")
                ]),
        .target(name: "libavif",
                dependencies: [
                    .product(name: "libaom", package: "libaom.swift"),
                    .product(name: "libdav1d", package: "libdav1d.swift"),
                    .product(name: "libSvtAv1Enc", package: "libsvtav1enc.swift"),
                    .target(name: "avifpixart")],
                publicHeadersPath: "include",
                cSettings: [
                    .define("AVIF_CODEC_AOM_ENCODE", to: "1"),
                    .define("AVIF_CODEC_AOM", to: "1"),
                    .define("AVIF_CODEC_DAV1D", to: "1"),
                    .define("AVIF_ENABLE_EXPERIMENTAL_GAIN_MAP", to: "1"),
                    .define("AVIF_CODEC_SVT", to: "1")
                ],
                cxxSettings: [
                    .define("AVIF_CODEC_AOM_ENCODE", to: "1"),
                    .define("AVIF_CODEC_AOM", to: "1"),
                    .define("AVIF_CODEC_DAV1D", to: "1"),
                    .define("AVIF_CODEC_SVT", to: "1"),
                    .define("AVIF_ENABLE_EXPERIMENTAL_GAIN_MAP", to: "1")
                ])
    ],
    cxxLanguageStandard: .cxx20
)
