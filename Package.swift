// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Pomodoro", platforms: [.macOS(.v14)],
    products: [.library(name: "PomodoroCore", targets: ["PomodoroCore"]), .executable(name: "Pomodoro", targets: ["PomodoroApp"])],
    targets: [
        .target(name: "PomodoroCore"),
        .executableTarget(name: "PomodoroApp", dependencies: ["PomodoroCore"], resources: [.process("Resources")]),
        .testTarget(name: "PomodoroCoreTests", dependencies: ["PomodoroCore"])
    ]
)
