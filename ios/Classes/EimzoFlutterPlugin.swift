import Flutter
import UIKit
import SwiftUI
import EimzoSDK

/// Flutter ↔ EimzoSDK bridge. Mirrors the Android `EimzoFlutterPlugin`
/// surface (method channel + event channel for deeplinks).
///
/// Method channel (`uz.peachdev/eimzo_flutter`):
///   - `init(config)`        → Bool  (license verdict — iOS always returns
///                              `true`; the actual license check runs
///                              inside `EImzoView` when `openSignUi` fires)
///   - `getInitialDeeplink()` → String?
///   - `launchDeeplink(url)`  → void (UIApplication.shared.open)
///   - `openSignUi(deepLink)` → void (presents `EImzoView` over Flutter UI)
///
/// Event channel (`uz.peachdev/eimzo_flutter/links`):
///   broadcasts `eimzo://…` URLs the app receives at runtime.
public class EimzoFlutterPlugin: NSObject, FlutterPlugin {

    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private let linkStreamHandler = LinkStreamHandler()

    /// Captured if the app was cold-launched via an `eimzo://` URL —
    /// `getInitialDeeplink()` from Dart drains it.
    private var pendingInitialLink: String?

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

        instance.eventChannel = FlutterEventChannel(
            name: "uz.peachdev/eimzo_flutter/links",
            binaryMessenger: registrar.messenger()
        )
        instance.eventChannel?.setStreamHandler(instance.linkStreamHandler)

        registrar.addApplicationDelegate(instance)
    }

    // MARK: - UIApplicationDelegate

    /// Cold-launch path: iOS hands the launch URL via the options dict.
    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if let url = launchOptions?[.url] as? URL, url.scheme == "eimzo" {
            pendingInitialLink = url.absoluteString
        }
        return true
    }

    /// Warm-launch path: app already running, a new `eimzo://` URL arrives.
    public func application(
        _ application: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        guard url.scheme == "eimzo" else { return false }
        let link = url.absoluteString
        pendingInitialLink = link
        linkStreamHandler.sink?(link)
        return true
    }

    /// Scene-based delegate fallback (iOS 13+, when the app uses
    /// UIScene). Flutter's UIApplicationDelegate route handles most apps.
    public func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        if let url = userActivity.webpageURL, url.scheme == "eimzo" {
            let link = url.absoluteString
            pendingInitialLink = link
            linkStreamHandler.sink?(link)
            return true
        }
        return false
    }

    // MARK: - Method dispatch

    private func onMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "init":
            handleInit(call: call, result: result)
        case "getInitialDeeplink":
            let link = pendingInitialLink
            pendingInitialLink = nil
            result(link)
        case "launchDeeplink":
            handleLaunchDeeplink(call: call, result: result)
        case "openSignUi":
            handleOpenSignUi(call: call, result: result)
        case "signWithUsbToken":
            // iOS has no public API for USB CCID smart-card readers —
            // CryptoTokenKit's TKSmartCard is macOS-only, iPad USB-C
            // doesn't expose CCID, and Lightning tokens need MFi vendor
            // SDKs. Surface UNSUPPORTED back to Dart so apps can branch
            // on it cleanly (and direct users to NFC or saved-key
            // signing instead).
            result(FlutterError(
                code: "UNSUPPORTED",
                message: "iOS does not support USB CCID smart-card tokens. Use NFC ID-card or saved-key signing instead.",
                details: nil
            ))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// On Android, `init` performs the license check up front so the host
    /// app can show a blocked banner if needed. On iOS, the SDK runs the
    /// license check inside `EImzoView.bootstrap()` and shows its own
    /// blocked screen if needed — we just return `true` here so the Dart
    /// API stays symmetrical.
    private func handleInit(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(true)
    }

    private func handleLaunchDeeplink(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let urlStr = args["url"] as? String,
              let url = URL(string: urlStr)
        else {
            result(FlutterError(code: "ARG", message: "url is required", details: nil))
            return
        }
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                result(nil)
            } else {
                result(FlutterError(code: "NO_HANDLER",
                                    message: "Couldn't open \(urlStr)",
                                    details: nil))
            }
        }
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
}

// MARK: - EventChannel sink for deeplinks

private final class LinkStreamHandler: NSObject, FlutterStreamHandler {
    fileprivate var sink: FlutterEventSink?

    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        return nil
    }
}
