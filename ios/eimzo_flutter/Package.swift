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
            url: "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/2.6.0/EimzoSDK.xcframework.zip",
            checksum: "d8926cc6c5f6f09ae4fe29f431327fd46e7ac0e1c779815d651afa2cf1ac7b54"
        ),
        .binaryTarget(
            name: "Pfx2qr",
            url: "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/2.6.0/Pfx2qr.xcframework.zip",
            checksum: "000e6b49ed3114ca999880aeae5dc39a93d78414df05b32088e94732fc183b28"
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