// swift-tools-version: 5.9
import PackageDescription
let package = Package(
  name: "foldable_info",
  platforms: [.iOS("15.0")],
  products: [.library(name: "foldable-info", targets: ["foldable_info"])],
  dependencies: [.package(name: "FlutterFramework", path: "../FlutterFramework")],
  targets: [.target(name: "foldable_info", dependencies: [.product(name: "FlutterFramework", package: "FlutterFramework")], publicHeadersPath: "include")]
)
