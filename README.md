# wcdb.xcframework

Use prebuilt [WCDB](https://github.com/Tencent/wcdb) XCFrameworks with Swift Package Manager.  
Use WCDB without compiling its C/C++ core. The binaries include prebuilt SQLCipher.

| Platform          | Architectures         | Minimum Deployment Target |
|------------------|----------------------|---------------------------|
| macOS             | x86_64 arm64        | 10.13                     |
| Mac Catalyst      | x86_64 arm64        | 13.0                      |
| iOS               | arm64               | 12.0                      |
| iOS Simulator     | x86_64 arm64        | 12.0                      |
| tvOS              | arm64               | 12.0                      |
| tvOS Simulator    | x86_64 arm64        | 12.0                      |
| watchOS           | arm64 arm64_32      | 5.0                       |
| watchOS Simulator | x86_64 arm64        | 5.0                       |

## Usage

Add this package to your `Package.swift` dependencies:

```swift
.package(
    url: "https://github.com/Lakr233/wcdb.xcframework",
    from: "2.1.16"
)
```

Then add `wcdb.xcframework` as a dependency for your target:
```swift
.target(
    name: "MyApp",
    dependencies: [
       .product(name: "WCDBSwift", package: "wcdb.xcframework"),
       // or
       .product(name: "WCDBObjc", package: "wcdb.xcframework"),
    ]
)
```

### License Notice

This repository provides only prebuilt WCDB binaries.

WCDB is an open-source project by Tencent:
https://github.com/Tencent/wcdb

Original WCDB license: see `WCDB-LICENSE`.

## Credits

- [https://github.com/Tencent/wcdb](https://github.com/Tencent/wcdb)
