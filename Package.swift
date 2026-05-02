// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "DayflowCore",
    platforms: [
        .iOS(.v17),
        .macOS(.v13)
    ],
    products: [
        .library(name: "DayflowCore", targets: ["DayflowCore"])
    ],
    targets: [
        .target(
            name: "DayflowCore",
            path: "Dayflow",
            exclude: [
                "Assets.xcassets",
                "Fonts",
                "DayflowApp.swift",
                "DayflowCalendarView.swift",
                "Dayflow.entitlements",
                "DayflowHomeView.swift",
                "Info.plist",
                "LaunchScreen.storyboard",
                "PrivacyInfo.xcprivacy"
            ],
            sources: [
                "DayActivityModel.swift",
                "DayPlanStore.swift",
                "DayflowWidgetSnapshot.swift"
            ]
        ),
        .testTarget(
            name: "DayflowCoreTests",
            dependencies: ["DayflowCore"],
            path: "Tests/DayflowCoreTests"
        )
    ]
)
