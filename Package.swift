// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "CombineCocoa",
  platforms: [.iOS(.v15), .macOS(.v12)],
  products: [
    .library(
      name: "CombineCocoa",
      targets: ["CombineCocoa"]
    )
  ],
  targets: [
    .target(
      name: "CombineCocoa",
      dependencies: [
        "Runtime",
        "COpenCombineHelpers",
      ],
    ),
    .target(name: "Runtime", dependencies: []),
    .target(name: "COpenCombineHelpers", dependencies: []),
    .testTarget(
      name: "CombineCocoaTests",
      dependencies: ["CombineCocoa"]
    ),
  ],
  cxxLanguageStandard: .cxx17
)
