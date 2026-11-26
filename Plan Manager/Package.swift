// swift-tools-version: 6.0
import PackageDescription

// The app and command-line tests compile the same production files, without a simulator dependency.
let package = Package(
    name: "PlanManagerFitnessCore",
    platforms: [.macOS(.v14)],
    products: [.library(name: "FitnessCore", targets: ["FitnessCore"])],
    targets: [
        .target(name: "FitnessCore", path: "Plan Manager",
                exclude: ["Assets.xcassets", "Components", "Resources", "Views", "ViewModels",
                          "ContentView.swift", "Info.plist", "PlanManagerApp.swift",
                          "Models/Plan.swift", "Models/Expense.swift", "Models/WaterRecord.swift",
                          "Services/LocalStorage.swift", "Services/ThemeManager.swift", "Services/BackupDocument.swift"],
                sources: ["Models/FitnessModels.swift", "Services/FitnessPolicy.swift",
                          "Services/FitnessStore.swift", "Services/FitnessLLM.swift"]),
        .testTarget(name: "FitnessCoreTests", dependencies: ["FitnessCore"], path: "FitnessTests")
    ]
)
