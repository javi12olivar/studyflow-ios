// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StudyFlow",
    defaultLocalization: "es",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "StudyFlow",
            targets: ["StudyFlow"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StudyFlow",
            path: ".",
            exclude: ["Package.swift"],
            sources: [
                "ContentView.swift",
                "Models",
                "Services",
                "Views"
            ],
            resources: [
                .process("Assets")
            ]
        )
    ]
)
