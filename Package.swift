// swift-tools-version: 5.9
import PackageDescription
let package = Package(name: "Pomodoro", platforms: [.macOS(.v14)], products: [.library(name: "PomodoroCore", targets: ["PomodoroCore"])], targets: [.target(name: "PomodoroCore"), .testTarget(name: "PomodoroCoreTests", dependencies: ["PomodoroCore"])])
