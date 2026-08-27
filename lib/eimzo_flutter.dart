import 'dart:async';

import 'package:flutter/services.dart';

/// SDK configuration passed to [EimzoFlutter.init].
class EimzoConfig {
  final bool isTestMode;
  final String? productionApiUrl;
  final String? testApiUrl;

  /// The `EIMZO1.…` licence issued by YT.
  ///
  /// Optional in the sense that a file is the other way to supply it: leave
  /// this null and the SDK looks for an `eimzo-license.txt` resource in the
  /// app bundle (iOS) or in `android/app/src/main/assets/` (Android). One of
  /// the two must be present.
  ///
  /// Pass it here when the file placement is awkward — on iOS it has to sit in
  /// the Runner target's *Copy Bundle Resources*, which is easy to miss and
  /// silently produces "Litsenziya topilmadi". Loading the token from a
  /// Flutter asset and handing it over here avoids Xcode entirely:
  ///
  /// ```dart
  /// final token = await rootBundle.loadString('assets/eimzo-license.txt');
  /// await EimzoFlutter.instance.init(config: EimzoConfig(license: token));
  /// ```
  ///
  /// The licence is bound to your package name and signing identity, so it
  /// does not need to be kept secret.
  final String? license;

  const EimzoConfig({
    this.isTestMode = false,
    this.productionApiUrl,
    this.testApiUrl,
    this.license,
  });

  Map<String, dynamic> toMap() => {
        'isTestMode': isTestMode,
        if (productionApiUrl != null) 'productionApiUrl': productionApiUrl,
        if (testApiUrl != null) 'testApiUrl': testApiUrl,
        if (license != null) 'license': license,
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
