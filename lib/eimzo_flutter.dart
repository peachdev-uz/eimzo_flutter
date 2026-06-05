import 'dart:async';

import 'package:flutter/services.dart';

/// SDK configuration passed to [EimzoFlutter.init].
class EimzoConfig {
  final bool isTestMode;
  final String? productionApiUrl;
  final String? testApiUrl;

  const EimzoConfig({
    this.isTestMode = false,
    this.productionApiUrl,
    this.testApiUrl,
  });

  Map<String, dynamic> toMap() => {
        'isTestMode': isTestMode,
        if (productionApiUrl != null) 'productionApiUrl': productionApiUrl,
        if (testApiUrl != null) 'testApiUrl': testApiUrl,
      };
}

/// Thrown when a native call fails.
class EimzoException implements Exception {
  final String code;
  final String message;
  const EimzoException(this.code, this.message);

  @override
  String toString() => 'EimzoException($code): $message';
}

/// Result of a high-level sign operation — mirrors the SDK's
/// `SignResult.Success` / `SignResult.Failure` shape.
class EimzoSignResult {
  /// Backend state (e.g. `"signature.valid"`, `"signature.invalid"`).
  final String state;

  /// Human-readable message from the backend.
  final String message;

  bool get isSuccess =>
      !state.toLowerCase().contains('invalid') &&
      !state.toLowerCase().contains('error');

  const EimzoSignResult({required this.state, required this.message});
}

/// Thin wrapper around the bundled E-IMZO Mobile SDK.
///
/// The native SDK owns all signing / key-management UI — this plugin just
/// initializes it on the host activity and forwards `eimzo://sign?...`
/// deep links into Dart.
class EimzoFlutter {
  EimzoFlutter._();
  static final EimzoFlutter instance = EimzoFlutter._();

  static const _channel = MethodChannel('uz.peachdev/eimzo_flutter');
  static const _linkChannel = EventChannel('uz.peachdev/eimzo_flutter/links');

  Stream<String>? _linkStream;

  /// Initialize the SDK and run its license check on the host activity.
  /// Returns `true` if the app is licensed and may proceed, `false` if the
  /// SDK has shown its blocked-app screen.
  Future<bool> init({EimzoConfig config = const EimzoConfig()}) async {
    try {
      final allowed = await _channel.invokeMethod<bool>('init', config.toMap());
      return allowed ?? false;
    } on PlatformException catch (e) {
      throw EimzoException(e.code, e.message ?? '');
    }
  }

  /// Returns the `eimzo://sign?...` URL the app was cold-started with,
  /// or null. Call once before `runApp`.
  Future<String?> getInitialDeeplink() async {
    try {
      return await _channel.invokeMethod<String>('getInitialDeeplink');
    } on PlatformException catch (e) {
      throw EimzoException(e.code, e.message ?? '');
    }
  }

  /// Fires an `ACTION_VIEW` intent for [url] — useful for testing the
  /// deep-link flow without an external trigger. Since this app's
  /// AndroidManifest registers `eimzo://sign`, the system routes the
  /// intent right back to MainActivity and [onNewDeeplink] emits.
  Future<void> launchDeeplink(String url) async {
    try {
      await _channel.invokeMethod<void>('launchDeeplink', {'url': url});
    } on PlatformException catch (e) {
      throw EimzoException(e.code, e.message ?? '');
    }
  }

  /// Opens the full E-IMZO native UI (Home + Keys + AddKey + sign flow).
  ///
  /// If [deepLink] is provided (an `eimzo://sign?qc=...` URL), the UI jumps
  /// straight into the sign flow for that document. Otherwise the user can
  /// browse keys, add new ones, and trigger signing via QR scanning.
  ///
  /// The native UI handles license check, password prompts, NFC waiting
  /// animations, and the network round-trip to `m.e-imzo.uz`.
  ///
  /// Returns when [EImzoActivity] is started — does NOT wait for the user
  /// to complete signing. Subscribe to [onNewDeeplink] to receive results.
  Future<void> openSignUi({String? deepLink}) async {
    try {
      await _channel.invokeMethod<void>('openSignUi', {
        if (deepLink != null) 'deepLink': deepLink,
      });
    } on PlatformException catch (e) {
      throw EimzoException(e.code, e.message ?? '');
    }
  }

  /// Sign a document with a USB token (Feitian FT-1280 / e-imzo card reader).
  ///
  /// High-level flow — native SDK takes care of everything:
  ///   1. Parse the `eimzo://sign?qc=...` deeplink
  ///   2. Fetch site info from `m.e-imzo.uz`
  ///   3. Build OzDST 1106 signed-attributes hash
  ///   4. Open the FT-reader USB session, wait for token + card insert
  ///   5. Validate the [pin] on the card
  ///   6. Sign the hash with OzDST 1092
  ///   7. Send the PKCS#7 envelope back to `m.e-imzo.uz`
  ///   8. Return the backend's verdict
  ///
  /// USB tokens are **sign-only** — nothing is persisted as a saved key.
  /// Each call opens a fresh FT-reader session and tears it down.
  ///
  /// **Android only.** iOS throws `EimzoException("UNSUPPORTED", ...)` —
  /// Apple does not expose USB CCID via public iOS API.
  ///
  /// Throws [EimzoException] with `code = "401"` on wrong PIN.
  Future<EimzoSignResult> signWithUsbToken({
    required String pin,
    required String deepLink,
  }) async {
    try {
      final res = await _channel.invokeMethod<Map<dynamic, dynamic>>(
        'signWithUsbToken',
        {
          'pin': pin,
          'deepLink': deepLink,
        },
      );
      if (res == null) {
        throw const EimzoException('NULL', 'Native returned null');
      }
      return EimzoSignResult(
        state: res['state'] as String? ?? '',
        message: res['message'] as String? ?? '',
      );
    } on PlatformException catch (e) {
      throw EimzoException(e.code, e.message ?? '');
    }
  }

  /// Broadcast stream of `eimzo://sign?...` URLs delivered while the app
  /// is running.
  Stream<String> onNewDeeplink() {
    _linkStream ??= _linkChannel
        .receiveBroadcastStream()
        .where((e) => e != null)
        .cast<String>();
    return _linkStream!;
  }
}
