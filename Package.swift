// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "Pomodoro", platforms: [.macOS(.v14)],
    products: [.library(name: "PomodoroCore", targets: ["PomodoroCore"]), .executable(name: "Pomodoro", targets: ["PomodoroApp"])],
    dependencies: [.package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.10.0")],
    targets: [
        .target(name: "PomodoroCore"),
        .executableTarget(name: "PomodoroApp", dependencies: ["PomodoroCore", .product(name: "Sparkle", package: "Sparkle")], resources: [.process("Resources")], linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"])]),
        .testTarget(name: "PomodoroCoreTests", dependencies: ["PomodoroCore"])
    ]
)
