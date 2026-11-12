import Flutter
import UIKit
import SwiftUI
import CoreText
@_spi(EImzoTesting) import EimzoSDK

/// Flutter ↔ EimzoSDK bridge. Mirrors the Android `EimzoFlutterPlugin`.
///
/// Method channel (`uz.peachdev/eimzo_flutter`):
///   - `init(config)`        → Bool  (license verdict — iOS always returns
///                              `true`; the actual license check runs
///                              inside `EImzoView` when `openSignUi` fires)
///   - `openSignUi(deepLink)` → void (presents `EImzoView` over Flutter UI)
///   - `getKeys`             → String (`EImzoAPI.getKeys`'s JSON, as it is)
///   - `sign(keyId, deepLink)` → String (`EImzoAPI.sign`'s JSON, as it is)
///   - `addPfxKey`, `addQrKey`, `addIdCardKey`, `addTokenKey` → String
///                              (`EImzoAPI`'s add methods' JSON, as it is)
///   - `cancelAddKey`        → void (nothing to do on iOS: the system's NFC
///                              sheet has its own Cancel)
///
/// The plugin does not listen for URLs. `eimzo://` is the E-IMZO app's
/// scheme, and a host that takes it from outside would open its SDK for any
/// page or app that sends one. A sign request reaches the SDK only as
/// `openSignUi`'s `deepLink`, which the app makes itself (Dart
/// `EimzoSignLink.create`).
public class EimzoFlutterPlugin: NSObject, FlutterPlugin {

    private var methodChannel: FlutterMethodChannel?

    /// Current EImzoView host so we can dismiss it after a sign completes.
    private weak var presentedHost: UIViewController?

    // MARK: - FlutterPlugin

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = EimzoFlutterPlugin()
        instance.methodChannel = FlutterMethodChannel(
            name: "uz.peachdev/eimzo_flutter",
            binaryMessenger: registrar.messenger()
        )
        instance.methodChannel?.setMethodCallHandler(instance.onMethodCall(_:result:))
    }

    // MARK: - Method dispatch

    private func onMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            handleInit(call: call, result: result)
        case "openSignUi":
            handleOpenSignUi(call: call, result: result)
        case "getKeys":
            handleGetKeys(result: result)
        case "sign":
            handleSign(call: call, result: result)
        case "addPfxKey", "addQrKey", "addIdCardKey", "addTokenKey":
            handleAddKey(call: call, result: result)
        case "cancelAddKey":
            // The system's NFC sheet is the only wait on iOS, and its own
            // Cancel ends `addIdCardKey` as `cancelled`.
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// The configuration Dart handed us in `init`, kept for `openSignUi` and
    /// the Keys API. Nil until `init` has run: `openSignUi` then opens with
    /// the SDK's defaults, as it always has, while the Keys API answers
    /// `not_initialized` — it would otherwise ask the gateway on a config the
    /// app never chose, `prod` for a `dev` build.
    ///
    /// Until 2.1.2 this plugin dropped it on the floor: `init` returned true
    /// without reading its arguments and `openSignUi` built `EImzoView` with a
    /// default config. Everything the host configured — test mode, API URLs,
    /// the licence — stopped at the platform channel.
    private var config: EImzoConfig?

    /// On Android, `init` performs the license check up front so the host
    /// app can show a blocked banner if needed. On iOS, the SDK runs the
    /// license check inside `EImzoView.bootstrap()` and shows its own
    /// blocked screen if needed — we just return `true` here so the Dart
    /// API stays symmetrical.
    private func handleInit(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = (call.arguments as? [String: Any]) ?? [:]
        let defaults = EImzoConfig()
        config = EImzoConfig(
            environment: (args["environment"] as? String).flatMap(EImzoEnvironment.init(rawValue:))
                ?? defaults.environment,
            productionApiUrl: args["productionApiUrl"] as? String ?? defaults.productionApiUrl,
            testApiUrl: args["testApiUrl"] as? String ?? defaults.testApiUrl,
            license: args["license"] as? String,
            debugLogging: args["debugLogging"] as? Bool ?? defaults.debugLogging,
            appearance: (args["appearance"] as? [String: Any]).map(Self.appearance(from:)),
            language: (args["language"] as? String).flatMap(EImzoLanguage.init(rawValue:)),
            showsLanguagePicker: args["showLanguagePicker"] as? Bool ?? true,
            hashDisplay: args["hashDisplay"] as? String == "hidden" ? .hidden : .visible
        )
        // YT's own testing: --dart-define=EIMZO_GATEWAY_URL=…, which the SDK
        // takes in a development-signed build only.
        .withGatewayOverride(args["gatewayOverride"] as? String)
        result(true)
    }

    /// Presents `EImzoView` modally on the Flutter root view controller.
    /// `deepLink` (optional) is forwarded into the sign flow.
    private func handleOpenSignUi(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = (call.arguments as? [String: Any]) ?? [:]
        let deepLink = args["deepLink"] as? String

        guard let rootVC = UIApplication.shared.connectedScenes
            .compactMap({ ($0 as? UIWindowScene)?.keyWindow?.rootViewController })
            .first ?? UIApplication.shared.windows.first?.rootViewController
        else {
            result(FlutterError(code: "NO_VC",
                                message: "No root view controller to present from",
                                details: nil))
            return
        }

        // Walk up to the topmost presented controller — otherwise we'd
        // present under any other modal Flutter has open.
        var top = rootVC
        while let presented = top.presentedViewController {
            top = presented
        }

        let host = UIHostingController(
            rootView: EImzoView(
                config: config ?? EImzoConfig(),
                deepLink: deepLink,
                onSignComplete: { [weak self] _ in
                    DispatchQueue.main.async {
                        self?.presentedHost?.dismiss(animated: true)
                        self?.presentedHost = nil
                    }
                }
            )
        )
        host.modalPresentationStyle = .fullScreen
        presentedHost = host
        top.present(host, animated: true) {
            result(nil)
        }
    }

    // MARK: - Kalitlar API (2.4)

    /// The keys the user has added to the SDK, as `EImzoAPI.getKeys` gives
    /// them. The SDK runs the licence and gateway check itself, on the
    /// config `init` stored.
    private func handleGetKeys(result: @escaping FlutterResult) {
        guard let config else {
            result(Self.notInitialized())
            return
        }
        Task { @MainActor in
            result(await EImzoAPI.getKeys(config: config))
        }
    }

    /// Signs `deepLink` with the key `keyId` in the SDK's sheet, which
    /// `EImzoAPI.sign` presents over the top-most view controller; the JSON
    /// comes back once the sheet has closed.
    private func handleSign(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let config else {
            result(Self.notInitialized())
            return
        }
        let args = (call.arguments as? [String: Any]) ?? [:]
        let keyId = args["keyId"] as? String ?? ""
        let deepLink = args["deepLink"] as? String ?? ""
        Task { @MainActor in
            result(await EImzoAPI.sign(keyId: keyId, deepLink: deepLink, config: config))
        }
    }

    /// «Kalitlar API» (2.6): adds a key the app hands over — `EImzoAPI`'s
    /// add methods, their JSON as it is. Nothing of the SDK's is shown; an ID
    /// card brings up the system's NFC sheet.
    private func handleAddKey(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let config else {
            result(Self.notInitialized())
            return
        }
        let args = (call.arguments as? [String: Any]) ?? [:]
        let method = call.method
        let pfx = (args["pfx"] as? FlutterStandardTypedData)?.data ?? Data()
        let qrCode = args["qrCode"] as? String ?? ""
        let password = args["password"] as? String ?? ""
        let savePassword = args["savePassword"] as? Bool ?? false
        let pin = args["pin"] as? String ?? ""
        let savePin = args["savePin"] as? Bool ?? false
        Task { @MainActor in
            switch method {
            case "addPfxKey":
                result(await EImzoAPI.addPfxKey(pfx: pfx, password: password,
                                                savePassword: savePassword, config: config))
            case "addQrKey":
                result(await EImzoAPI.addQrKey(qrCode: qrCode, password: password,
                                               savePassword: savePassword, config: config))
            case "addIdCardKey":
                result(await EImzoAPI.addIdCardKey(pin: pin, savePin: savePin, config: config))
            default:
                result(await EImzoAPI.addTokenKey(pin: pin, savePin: savePin, config: config))
            }
        }
    }

    // MARK: - Appearance (2.5.0)

    /// The appearance Dart sent: colours as `0xAARRGGBB`, the theme mode by
    /// name, and the font as the app's own asset files, registered here for
    /// this process so the SDK can find the family by name.
    static func appearance(from map: [String: Any]) -> EImzoAppearance {
        let fonts = map["fonts"] as? [String: String]
        let registered = fonts.flatMap { registerFonts($0) }
        return EImzoAppearance(
            light: (map["light"] as? [String: Any]).map(palette(from:)),
            dark: (map["dark"] as? [String: Any]).map(palette(from:)),
            themeMode: themeMode(map["themeMode"] as? String),
            // The family the files declare: the pubspec may name it otherwise.
            fontFamily: registered ?? map["fontFamily"] as? String,
            cornerRadius: (map["cornerRadius"] as? NSNumber).map { CGFloat($0.doubleValue) }
        )
    }

    private static func palette(from map: [String: Any]) -> EImzoPalette {
        func color(_ key: String) -> Color? {
            guard let argb = (map[key] as? NSNumber)?.uint32Value else { return nil }
            return Color(.sRGB,
                         red: Double((argb >> 16) & 0xFF) / 255,
                         green: Double((argb >> 8) & 0xFF) / 255,
                         blue: Double(argb & 0xFF) / 255,
                         opacity: Double((argb >> 24) & 0xFF) / 255)
        }
        return EImzoPalette(primary: color("primary"), background: color("background"),
                            surface: color("surface"), text: color("text"),
                            textSecondary: color("textSecondary"), divider: color("divider"))
    }

    private static func themeMode(_ name: String?) -> EImzoThemeMode {
        switch name {
        case "light": return .light
        case "dark": return .dark
        default: return .system
        }
    }

    /// Registers the app's font files (`regular`, `medium`, `semibold`) with
    /// Core Text for this process and returns the family the regular face
    /// declares; nil when its file is not in the app.
    private static func registerFonts(_ files: [String: String]) -> String? {
        var family: String?
        for weight in ["regular", "medium", "semibold"] {
            guard let asset = files[weight],
                  let path = Bundle.main.path(forResource: FlutterDartProject.lookupKey(forAsset: asset), ofType: nil)
            else { continue }
            let url = URL(fileURLWithPath: path) as CFURL
            // A second init registers the same files again; Core Text says
            // they already are, and the family is still read below.
            CTFontManagerRegisterFontsForURL(url, .process, nil)
            if weight == "regular",
               let descriptor = (CTFontManagerCreateFontDescriptorsFromURL(url) as? [CTFontDescriptor])?.first {
                family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String
            }
        }
        return family
    }

    /// `init` has not run, so there is no config to call the SDK with. Dart
    /// turns this into the API's own `not_initialized` JSON.
    private static func notInitialized() -> FlutterError {
        FlutterError(code: "NOT_INITIALIZED",
                     message: "EimzoFlutter.instance.init has not been called yet.",
                     details: nil)
    }
}

