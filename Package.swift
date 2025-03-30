// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "FixMeGrammar",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        .executable(name: "FixMeGrammar", targets: ["FixMeGrammar"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "FixMeGrammar",
            dependencies: [],
            path: "Sources"
        ),
    ]
) 