// swift-tools-version:5.5

import PackageDescription

let package = Package(
    name: "ExpandableLabel",
    
    platforms: [.iOS(.v10)],
    
    products: [
        .library(
            name: "ExpandableLabel",
            targets: ["ExpandableLabel"]),
    ],

    targets: [
        .target(
            name: "ExpandableLabel",
            dependencies: []),
    ]
)
