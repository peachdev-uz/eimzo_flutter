import 'dart:convert';

import 'package:flutter/services.dart';

/// Which E-IMZO the SDK works with — see [EimzoConfig.environment].
enum EimzoEnvironment {
  /// E-IMZO itself: real keys and real documents. The default.
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

  /// The `EIMZO1.…` licence issued by YT, for an app that already ships one.
  ///
  /// Since 2.3 an app needs no licence: YT registers it and the gateway
  /// knows it by attestation. An app that has a licence opens its gateway
  /// session with it instead, and the gateway must have that licence on
  /// record. It can come from here or from a file: leave this null and the
  /// SDK looks for an `eimzo-license.txt` resource in the app bundle (iOS) or
  /// in `android/app/src/main/assets/` (Android).
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
/// the app made ([EimzoSignLink]) or without one. For an integrator YT has
/// registered for the «Kalitlar API» it also lists the user's keys
/// ([getKeys]) and signs with one of them in the SDK's own sheet ([sign]).
class EimzoFlutter {
  EimzoFlutter._();
  static final EimzoFlutter instance = EimzoFlutter._();

  static const _channel = MethodChannel('uz.peachdev/eimzo_flutter');

  /// Applies [config] and, on Android, checks the app: the device checks, the
  /// licence if the app ships one, and the gateway session. Returns `false`
  /// when the app or the phone was refused — the SDK has then shown its
  /// blocked screen over the app, and closing it comes back to the app — and
  /// `true` otherwise. On iOS it stores the config and returns `true`; the
  /// same checks run when [openSignUi] presents the UI, and when [getKeys] or
  /// [sign] is called.
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
  /// The native UI handles the gateway session, password prompts, NFC
  /// waiting and the round-trip to E-IMZO through the YT gateway.
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

  /// «Kalitlar API» (2.4): the keys the user has added to the SDK on this
  /// phone, as the native SDK's JSON, unchanged.
  ///
  /// Only for an integrator YT has registered for it. The permission — the
  /// integrator's «Kalitlar API» in YT's gateway admin panel — is off by
  /// default; YT turns it on at the integrator's request, once there is a
  /// contract, for all of the integrator's apps, and the SDK reads it from
  /// the gateway session: turned on, it reaches the app with the next
  /// session — within the hour, at once when the app restarts. Without it
  /// this and [sign] answer `api_not_allowed`. [openSignUi] stays open to
  /// every registered app, and it is where users add their keys: the API
  /// lists them and signs, it does not add any.
  ///
  /// ```dart
  /// final reply = jsonDecode(await EimzoFlutter.instance.getKeys());
  /// ```
  ///
  /// ```json
  /// {"status":"ok","keys":[
  ///   {"id":"7a3f…","pinfl":"31234567890123","name":"ALIYEV VALI ALIYEVICH",
  ///    "validFrom":"2025-03-01","validTo":"2027-03-01"}]}
  /// ```
  ///
  /// Every kind of key — file, QR, ID card, USB token, BAIK — that can be used
  /// in the configured [EimzoConfig.environment], expired ones too, in the
  /// SDK's own order with the default key first; a key added in the other
  /// environment is left out. `id` is opaque: hand it to [sign] as it is.
  /// `pinfl` is null when the certificate has none. `validFrom` and
  /// `validTo` are `yyyy-MM-dd`, or null when the SDK cannot read them;
  /// `validTo` is how the app tells an expired key. No keys:
  /// `{"status":"ok","keys":[]}`.
  ///
  /// An error comes as `{"status":"error","code":"…","message":"…"}`, with
  /// the codes [sign] lists — here `api_not_allowed`, `not_initialized`,
  /// `blocked`, `network` or `sign_failed`. It never throws.
  ///
  /// Call [init] first, with the usual config: on Android the API works once
  /// [init] has returned `true` in this process, and on iOS it runs on the
  /// config [init] stored.
  Future<String> getKeys() =>
      _keysApi(() => _channel.invokeMethod<String>('getKeys'));

  /// «Kalitlar API» (2.4): signs [deepLink] — a sign request made with
  /// [EimzoSignLink.create] — with the key [keyId] from [getKeys], and returns
  /// how it ended as the native SDK's JSON, unchanged. Only for an integrator
  /// with the permission; see [getKeys].
  ///
  /// ```dart
  /// final link = EimzoSignLink.create(siteId: siteId, documentId: documentId, hash: hash);
  /// final reply = jsonDecode(await EimzoFlutter.instance.sign(keyId: id, deepLink: link));
  /// if (reply['status'] == 'signed') { /* your backend has it from E-IMZO */ }
  /// ```
  ///
  /// The SDK checks first and answers without opening anything when a check
  /// fails: the permission, the request, the key here, the key not expired,
  /// no other [sign] open. Then it opens its own sign sheet over the app —
  /// the site, the hash and the key, fixed, with no other to pick. The user
  /// types the password, or the PIN with the ID card or token, there and
  /// never in your app, and taps «Imzolash»; after a signature the sheet
  /// says «Imzolandi», closes by itself after 3 seconds, and the call
  /// returns. Any site's request can be signed, as in [openSignUi].
  ///
  /// The signature goes to E-IMZO through the YT gateway, and E-IMZO hands
  /// the signed document to your backend, as with [openSignUi]. No signature
  /// or PKCS#7 comes to the app: `signed` tells it the signing went through,
  /// and the backend has the result from E-IMZO.
  ///
  /// - `{"status":"signed"}` — E-IMZO accepted the signature.
  /// - `{"status":"cancelled"}` — the user closed the sheet without signing,
  ///   also after an error they could act on: a wrong password or PIN, the
  ///   card or token, the network.
  /// - `{"status":"error","code":"…","message":"…"}` — a check failed, or the
  ///   flow ended by itself.
  ///
  /// The codes, the same on Android and iOS:
  ///
  /// - `api_not_allowed` — the integrator has no «Kalitlar API» permission.
  /// - `not_initialized` — Android: [init] has not returned `true` in this
  ///   process; iOS: [init] has not been called.
  /// - `blocked` — the licence check or the gateway turned the app or the
  ///   phone away; `message` starts with their code, e.g. `app_blocked`. The
  ///   blocked screen is not shown.
  /// - `network` — the gateway could not be reached, or did not answer in
  ///   time.
  /// - `invalid_request` — [deepLink] is not a valid sign request, or E-IMZO
  ///   does not know its site.
  /// - `key_not_found` — no key with that `id` can be used in this
  ///   environment.
  /// - `key_expired` — the key's certificate has expired.
  /// - `busy` — another [sign] is still open; there is one at a time.
  /// - `sign_failed` — E-IMZO refused the signature, or anything else ended
  ///   the flow; `message` says what — E-IMZO's own answer when it refused,
  ///   `pin_blocked` when the card's or token's PIN is blocked.
  ///
  /// `message` is for the developer, not the user: English, except E-IMZO's
  /// own answer, and never a key, a password or a hash. Show the user your
  /// own words for the `code`.
  ///
  /// It never throws. A failure of the plugin itself comes in the same
  /// shape: with no Android activity to open the sheet over it is
  /// `sign_failed` with the message `no_activity`, and any other platform
  /// error is `sign_failed` with that error's message.
  Future<String> sign({required String keyId, required String deepLink}) =>
      _keysApi(() => _channel.invokeMethod<String>('sign', {
            'keyId': keyId,
            'deepLink': deepLink,
          }));

  /// Runs a «Kalitlar API» call and gives back the native JSON as it is. A
  /// failure of the plugin itself — no native side, no activity, no config —
  /// comes back in the API's own error shape rather than as an exception, so
  /// an app reads one thing whatever happened.
  static Future<String> _keysApi(Future<String?> Function() call) async {
    try {
      return await call() ?? _apiError('sign_failed', 'The native side returned no result.');
    } on PlatformException catch (e) {
      final message = e.message ?? e.code;
      return switch (e.code) {
        // Android: no activity to open the sheet over.
        'NO_ACTIVITY' => _apiError('sign_failed', 'no_activity'),
        // iOS: init has stored no config to call the SDK with.
        'NOT_INITIALIZED' => _apiError('not_initialized', message),
        _ => _apiError('sign_failed', message),
      };
    } on MissingPluginException catch (e) {
      // No native side for the call: another platform, or a host whose
      // native build predates 2.4.
      return _apiError('sign_failed', e.message ?? 'No native implementation.');
    }
  }

  static String _apiError(String code, String message) =>
      jsonEncode({'status': 'error', 'code': code, 'message': message});
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
