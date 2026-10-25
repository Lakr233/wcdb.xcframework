// swift-tools-version:6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "wcdb.xcframework",
    platforms: [
        .iOS(.v12),
        .watchOS(.v6),
        .tvOS("12.4"),
        .visionOS(.v1),
        .macOS(.v10_13),
        .macCatalyst(.v13),
    ],
    products: [
        .library(name: "WCDBSwift", targets: ["WCDBSwift"]),
        .library(name: "WCDBObjc", targets: ["WCDBObjc"]),
    ],
    targets: [
        .binaryTarget(
            name: "WCDBSwift",
            url: "https://github.com/Lakr233/wcdb.xcframework/releases/download/storage.2.1.16/WCDBSwift.xcframework.zip",
            checksum: "f4e04613a772ba8e4511374d1b8c866962be9c1acf923c300c23d711374cb4a0"
        ),
        .binaryTarget(
            name: "WCDBObjc",
            url: "https://github.com/Lakr233/wcdb.xcframework/releases/download/storage.2.1.16/WCDBObjc.xcframework.zip",
            checksum: "1eda40c3b8e4e306bfd240e67b2c9ccefea7bddfea3429177ad795a4adee5d9a"
        ),
    ]
)