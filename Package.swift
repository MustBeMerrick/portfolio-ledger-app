// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "PortfolioLedger",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "PortfolioLedger",
            targets: ["PortfolioLedger"]
        )
    ],
    targets: [
        .target(
            name: "PortfolioLedger",
            path: "PortfolioLedger",
            sources: ["Engine", "Models", "Services"]
        ),
        .testTarget(
            name: "PortfolioLedgerTests",
            dependencies: ["PortfolioLedger"]
        )
    ]
)
