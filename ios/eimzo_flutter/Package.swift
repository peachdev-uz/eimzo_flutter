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
            url: "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/2.3.0-dev.11/EimzoSDK.xcframework.zip",
            checksum: "12437f0dd6191d4e397ee3db67a1b58f6853e217184364ada62a0efca45cba01"
        ),
        .binaryTarget(
            name: "Pfx2qr",
            url: "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/2.3.0-dev.11/Pfx2qr.xcframework.zip",
            checksum: "fcf5f154327c11f9ac49003e0a307fa695e80be43c2db297936c171337b391f6"
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