// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "SleightCut", platforms: [.macOS(.v13)], products: [.executable(name: "SleightCut", targets: ["SleightCut"])], targets: [.executableTarget(name: "SleightCut")])
