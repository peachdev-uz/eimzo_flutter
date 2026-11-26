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
        // Closed-source EimzoSDK binary, pulled from the public GitHub
        // release — the same artifact the podspec's prepare_command fetches.
        // SPM downloads and caches it at package-resolution time, so no
        // equivalent of prepare_command is needed here. Up to 2.7.0 Go's
        // Pfx2qr came with it; since 2.8.0 there is one binary.
        //
        // The checksum is computed with `swift package compute-checksum <zip>`.
        // When the native iOS SDK rolls, bump the version in the URL AND
        // recompute the checksum (also update EIMZO_SDK_VERSION in the podspec).
        .binaryTarget(
            name: "EimzoSDK",
            url: "https://github.com/peachdev-uz/eimzo-ios-sdk/releases/download/2.8.0/EimzoSDK.xcframework.zip",
            checksum: "781de40d7485fa7c18bd74a2456c033350c93da403e4af00e4571b262a513b7f"
        ),
        .target(
            name: "eimzo_flutter",
            dependencies: [
                "EimzoSDK",
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ]
        )
    ]
)