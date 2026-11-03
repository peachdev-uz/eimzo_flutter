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
  /// It picks the YT gateway the app goes through, with a licence or
  /// without. The SDK carries the addresses, so nothing else is configured
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
/// initializes it on the host activity and opens it, with a sign request
/// the app made ([EimzoSignLink]) or without one.
class EimzoFlutter {
  EimzoFlutter._();
  static final EimzoFlutter instance = EimzoFlutter._();

  static const _channel = MethodChannel('uz.peachdev/eimzo_flutter');

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

  /// Opens the full E-IMZO native UI (Home + Keys + AddKey + sign flow).
  ///
  /// [deepLink] is a sign request the app made with [EimzoSignLink.create]
  /// from its own backend's values: the UI shows it — site, hash, key — and
  /// signs when the user taps IMZOLASH. Without one the user can browse
  /// keys, add new ones, and sign by scanning a site's QR code.
  ///
  /// The app never takes `eimzo://` links from outside: that scheme is the
  /// E-IMZO app's. Do not declare it in AndroidManifest.xml or Info.plist —
  /// the SDK logs a warning when it finds it there.
  ///
  /// The native UI handles license check, password prompts, NFC waiting
  /// animations, and the network round-trip to `m.e-imzo.uz`.
  ///
  /// Returns when the native UI is up — it does not wait for the signature.
  Future<void> openSignUi({String? deepLink}) async {
    try {
      await _channel.invokeMethod<void>('openSignUi', {
        if (deepLink != null) 'deepLink': deepLink,
      });
    } on PlatformException catch (e) {
      throw EimzoException(e.code, e.message ?? '');
    }
  }
}

/// The sign request link the SDK opens — `eimzo://sign?qc=…` — made from the
/// three values E-IMZO gives a site for a document: the site's id, the
/// document's id and the hash to sign.
///
/// The app gets them from its own backend and hands the link to
/// [EimzoFlutter.openSignUi]:
///
/// ```dart
/// final link = EimzoSignLink.create(
///   siteId: siteId,          // 4 hex characters
///   documentId: documentId,  // 8, 10, 12, 14 or 16 hex characters
///   hash: hash,              // 64 hex characters
/// );
/// await EimzoFlutter.instance.openSignUi(deepLink: link);
/// ```
///
/// The same function is in the native Android and iOS SDKs.
class EimzoSignLink {
  EimzoSignLink._();

  static final _hex = RegExp(r'^[0-9a-fA-F]*$');

  /// `eimzo://sign?qc=<siteId><documentId><hash><crc32>`.
  ///
  /// Throws an [ArgumentError] when a value is not in the form above.
  static String create({
    required String siteId,
    required String documentId,
    required String hash,
  }) {
    if (siteId.length != 4 || !_hex.hasMatch(siteId)) {
      throw ArgumentError.value(siteId, 'siteId', '4 ta hex belgi bo‘lishi kerak');
    }
    if (!const {8, 10, 12, 14, 16}.contains(documentId.length) || !_hex.hasMatch(documentId)) {
      throw ArgumentError.value(
          documentId, 'documentId', '8, 10, 12, 14 yoki 16 ta hex belgi bo‘lishi kerak');
    }
    if (hash.length != 64 || !_hex.hasMatch(hash)) {
      throw ArgumentError.value(
          '${hash.length} belgi', 'hash', '64 ta hex belgi bo‘lishi kerak');
    }
    final body = '$siteId$documentId$hash';
    return 'eimzo://sign?qc=$body${_crc32OfHex(body)}';
  }

  /// CRC-32 (IEEE) over the hex-decoded bytes, as 8 lowercase hex digits —
  /// the check the SDKs read a link with.
  static String _crc32OfHex(String hex) {
    var crc = 0xFFFFFFFF;
    for (var i = 0; i < hex.length; i += 2) {
      crc ^= int.parse(hex.substring(i, i + 2), radix: 16);
      for (var bit = 0; bit < 8; bit++) {
        crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
      }
    }
    return ((crc ^ 0xFFFFFFFF) & 0xFFFFFFFF).toRadixString(16).padLeft(8, '0');
  }
}
