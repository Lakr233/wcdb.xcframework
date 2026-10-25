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
            url: "https://github.com/Lakr233/wcdb.xcframework/releases/download/storage.2.1.16.20261025150750/WCDBSwift.xcframework.zip",
            checksum: "279c200a159b90e357499af2a68c95388dd2ac699f0dc993a18030489bf71c69"
        ),
        .binaryTarget(
            name: "WCDBObjc",
            url: "https://github.com/Lakr233/wcdb.xcframework/releases/download/storage.2.1.16.20261025150750/WCDBObjc.xcframework.zip",
            checksum: "bd580a8a6eebff886d821a5fc8ab802b51728b559dfe66a893cfe3af9c92808e"
        ),
    ]
)