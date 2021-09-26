// swift-tools-version:5.3

import PackageDescription

let package = Package(
    name: "ExpandableLabel",
    
    platforms: [.iOS(.v10)],
    
    products: [
        .library(
            name: "ExpandableLabel",
            targets: ["ExpandableLabel"]),
    ],
    
//    dependencies: [
//        .package(url: "https://github.com/davedelong/time", from: "0.9.1"),
//    ],

    targets: [
        .target(
            name: "ExpandableLabel",
            dependencies: []),
    ]
)
