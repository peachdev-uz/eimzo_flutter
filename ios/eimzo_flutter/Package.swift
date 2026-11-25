// swift-tools-version: 5.9
// Swift Package Manager manifest for the eimzo_flutter plugin — companion to
// eimzo_flutter.podspec. Apps that opt into SPM
// (`flutter config --enable-swift-package-manager`) pick this up; CocoaPods
// apps keep using the podspec. Both share the same Swift sources under
// Sources/eimzo_flutter/.
import PackageDescription

let package = Package(
    name: "eimzo_flutter",
    platforms: [
        .iOS("16.0")
    ],
    products: [
        .library(name: "eimzo-flutter", targets: ["eimzo_flutter"])
    ],
    dependencies: [
        // Provided by Flutter's SPM integration — gives the target access to
        // the `Flutter` module (FlutterPlugin, FlutterMethodChannel, …). The
        // ../FlutterFramework path is resolved inside the app's generated
        // Flutter SPM workspace at build time.
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        // Closed-source EimzoSDK + Pfx2qr binaries, pulled from the public
        // GitHub release — the same artifacts the podspec's prepare_command
        // fetches. SPM downloads and caches them at package-resolution time, so
        // no equivalent of prepare_command is needed here.
        //
        // Checksums are computed with `swift package compute-checksum <zip>`.
        // When the native iOS SDK rolls, bump the version in BOTH URLs AND
        // recompute BOTH checksums (also update EIMZO_SDK_VERSION in the podspec).
        .binaryTarget(
            name: "EimzoSDK",
            url: "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/2.7.0/EimzoSDK.xcframework.zip",
            checksum: "25059be154e0090ecb63f04870becc05c50af4bcb5ea84a4bdabb5836bc40d10"
        ),
        .binaryTarget(
            name: "Pfx2qr",
            url: "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/2.7.0/Pfx2qr.xcframework.zip",
            checksum: "5aac9a7822a6c9431ba599b6bb11e371f8a46b32958735a17d9d8868eb8fb25c"
        ),
        .target(
            name: "eimzo_flutter",
            dependencies: [
                "EimzoSDK",
                "Pfx2qr",
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)