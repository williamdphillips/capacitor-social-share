// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "SoundsCapacitorSocialShare",
    platforms: [
        .iOS(.v11)
    ],
    products: [
        .library(
            name: "SoundsCapacitorSocialShare",
            targets: ["SocialShare"]
        ),
    ],
    dependencies: [
        .package(name: "Capacitor", url: "https://github.com/ionic-team/capacitor", .upToNextMajor(from: "6.0.0"))
    ],
    targets: [
        .target(
            name: "SocialShare",
            dependencies: ["Capacitor"],
            path: "ios/SocialShare"
        )
    ]
)