// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "CodexMacGUIUnlock", platforms: [.macOS(.v13)], products: [.executable(name: "GUIUnlock", targets: ["GUIUnlock"])], targets: [.target(name: "UnlockCore"), .executableTarget(name: "GUIUnlock", dependencies: ["UnlockCore"]), .testTarget(name: "UnlockCoreTests", dependencies: ["UnlockCore"])])
