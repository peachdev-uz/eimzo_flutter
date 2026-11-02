import 'dart:async';

import 'package:flutter/services.dart';

/// Which E-IMZO the SDK works with — see [EimzoConfig.environment].
enum EimzoEnvironment {
  /// E-IMZO itself, m.e-imzo.uz: real keys and real documents. The default.
  prod,

  /// YT's test environment, in front of test.e-imzo.uz, for development and
  /// QA builds. Only test keys sign there, and a QR code from one
  /// environment does not work in the other.
  dev,
}

/// For YT's own testing: a gateway to use instead of the environment's, given
/// at build time with `--dart-define=EIMZO_GATEWAY_URL=…`. Empty otherwise.
/// The native SDKs take it in a debuggable (Android) or development-signed
/// (iOS) build only, so it can never reach a published app.
const _gatewayOverride = String.fromEnvironment('EIMZO_GATEWAY_URL');

/// SDK configuration passed to [EimzoFlutter.init].
class EimzoConfig {
  /// Production E-IMZO or YT's test environment; [EimzoEnvironment.prod] by
  /// default.
  ///
  /// It picks E-IMZO for an app with a licence and the YT gateway for one
  /// without. The SDK carries both addresses, so nothing else is configured
  /// for it.
  final EimzoEnvironment environment;

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

  /// Logs the SDK's steps to the console — never keys, PINs or signatures.
  /// For debug builds, e.g. `debugLogging: kDebugMode`.
  final bool debugLogging;

  /// [isTestMode] is the flag the environment was until 2.3: `true` is
  /// [EimzoEnvironment.dev]. It still works, so configurations written for
  /// 2.2 build unchanged; [environment], when given, wins.
  const EimzoConfig({
    EimzoEnvironment? environment,
    @Deprecated('environment: EimzoEnvironment.dev yoki EimzoEnvironment.prod bilan almashtiring')
    bool isTestMode = false,
    this.productionApiUrl,
    this.testApiUrl,
    this.license,
    this.debugLogging = false,
  }) : environment = environment ??
            (isTestMode ? EimzoEnvironment.dev : EimzoEnvironment.prod);

  @Deprecated('environment ni ishlating')
  bool get isTestMode => environment == EimzoEnvironment.dev;

  Map<String, dynamic> toMap() => {
        'environment': environment.name,
        if (productionApiUrl != null) 'productionApiUrl': productionApiUrl,
        if (testApiUrl != null) 'testApiUrl': testApiUrl,
        if (license != null) 'license': license,
        if (_gatewayOverride.isNotEmpty) 'gatewayOverride': _gatewayOverride,
        'debugLogging': debugLogging,
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
