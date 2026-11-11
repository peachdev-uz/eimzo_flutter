import 'dart:convert';

import 'package:flutter/material.dart';
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

/// The languages the SDK's screens come in — see [EimzoConfig.language].
enum EimzoLanguage {
  /// O‘zbekcha (lotin).
  uz,

  /// Русский.
  ru,

  /// English.
  en,
}

/// Whether the sign screen shows the hash — see [EimzoConfig.hashDisplay].
enum EimzoHashDisplay {
  /// The hash card as always: the hash, «Nusxa» and the advice to compare it
  /// with the site's. The default.
  visible,

  /// No hash card on a request the app made itself — the `deepLink` of
  /// [EimzoFlutter.openSignUi], and [EimzoFlutter.sign]. The user has nothing
  /// to compare it with there, and the app gave the hash in the first place.
  ///
  /// A request the user scans with the SDK's own QR scanner keeps it: that
  /// site shows the same hash on its own screen, and comparing the two is
  /// what protects the user from a substituted document.
  hidden,
}

/// The six colours of one of the SDK's modes, light or dark — see
/// [EimzoAppearance].
///
/// Each one is optional: a colour left out stays the SDK's own for that mode.
/// The SDK works out the rest of its colours from these — the link colour,
/// the label on a filled button (white or black, whichever reads), the
/// washes, the PIN dots — so they keep holding together.
@immutable
class EimzoPalette {
  /// Filled buttons, switches, marks, links.
  final Color? primary;

  /// The page behind everything.
  final Color? background;

  /// Cards, rows, the sheets that come up from the bottom, the PIN keys.
  final Color? surface;

  /// Body text and titles.
  final Color? text;

  /// Hints, captions, subtitles.
  final Color? textSecondary;

  /// Dividers and hairlines.
  final Color? divider;

  const EimzoPalette({
    this.primary,
    this.background,
    this.surface,
    this.text,
    this.textSecondary,
    this.divider,
  });

  /// The colours given, as `0xAARRGGBB` — the form both native sides read.
  Map<String, int> toMap() => {
        if (primary != null) 'primary': _argb(primary!),
        if (background != null) 'background': _argb(background!),
        if (surface != null) 'surface': _argb(surface!),
        if (text != null) 'text': _argb(text!),
        if (textSecondary != null) 'textSecondary': _argb(textSecondary!),
        if (divider != null) 'divider': _argb(divider!),
      };

  /// `Color.value` is deprecated from Flutter 3.27 in favour of
  /// `toARGB32()`, which 3.10 — the oldest Flutter this plugin supports —
  /// does not have. Both give the same 32 bits.
  // ignore: deprecated_member_use
  static int _argb(Color color) => color.value;

  @override
  bool operator ==(Object other) =>
      other is EimzoPalette &&
      other.primary == primary &&
      other.background == background &&
      other.surface == surface &&
      other.text == text &&
      other.textSecondary == textSecondary &&
      other.divider == divider;

  @override
  int get hashCode => Object.hash(primary, background, surface, text, textSecondary, divider);
}

/// How the SDK's screens look in the app: colours, font, corners and
/// light or dark — see [EimzoConfig.appearance]. Since 2.5.0.
///
/// The fastest way is the app's own theme:
///
/// ```dart
/// EimzoConfig(appearance: EimzoAppearance.fromTheme(lightTheme, dark: darkTheme))
/// ```
///
/// Some things stay the SDK's whatever is set, because they protect the
/// person signing: the name of the site asking for the signature, the key's
/// holder, the «Imzolash» button's words and place (its colour is
/// [EimzoPalette.primary]), and the SDK's own password and PIN entry. So do
/// the error, warning and success colours, the key card and the QR scanner.
/// If the text would not read on the background or the cards (under 4.5:1),
/// the SDK ignores that mode's colours, keeps its own and logs why.
@immutable
class EimzoAppearance {
  /// Colours in light mode. Null keeps the SDK's.
  final EimzoPalette? light;

  /// Colours in dark mode. Null keeps the SDK's dark colours, with
  /// [light]'s primary.
  final EimzoPalette? dark;

  /// Light, dark or the phone's setting on the SDK's screens;
  /// [ThemeMode.system] by default. With an appearance set the SDK also stops
  /// offering its own wallpaper and dark-mode choices (Android), and draws no
  /// photo behind its home screen.
  final ThemeMode themeMode;

  /// A font family the app bundles, as its pubspec names it (`Inter`). The
  /// plugin finds its files among the app's assets and hands them to the
  /// SDK, regular, medium and semibold where the family has them. Not found
  /// — a font the `google_fonts` package downloads at run time, say — the
  /// SDK keeps its own font. Null keeps it too: the system font on iOS,
  /// Montserrat on Android.
  final String? fontFamily;

  /// The corner radius of the SDK's buttons, in logical pixels, from 0 to
  /// 28; 16 by default. Cards, sheets and the rest scale with it, and round
  /// things stay round.
  final double? cornerRadius;

  const EimzoAppearance({
    this.light,
    this.dark,
    this.themeMode = ThemeMode.system,
    this.fontFamily,
    this.cornerRadius,
  });

  /// The appearance of an app themed with [light] (and [dark], when it has a
  /// dark theme):
  ///
  /// | SDK | ThemeData |
  /// |---|---|
  /// | primary | `colorScheme.primary` |
  /// | background | `scaffoldBackgroundColor` |
  /// | surface | `cardTheme.color`, else `cardColor` |
  /// | text | `colorScheme.onSurface` |
  /// | textSecondary | `colorScheme.onSurfaceVariant` |
  /// | divider | `dividerTheme.color`, else `colorScheme.outlineVariant` (Material 3) or `dividerColor` |
  /// | font | `textTheme.bodyMedium.fontFamily` |
  /// | corners | the filled or elevated button theme's `RoundedRectangleBorder` |
  ///
  /// Where the cards are the colour of the page — Material 3's defaults,
  /// where a card is only told apart by its elevation — the SDK's cards are
  /// drawn a shade toward the text colour, or they would not show.
  factory EimzoAppearance.fromTheme(
    ThemeData light, {
    ThemeData? dark,
    ThemeMode themeMode = ThemeMode.system,
  }) =>
      EimzoAppearance(
        light: _paletteOf(light),
        dark: dark == null ? null : _paletteOf(dark),
        themeMode: themeMode,
        fontFamily: light.textTheme.bodyMedium?.fontFamily,
        cornerRadius: _radiusOf(light),
      );

  static EimzoPalette _paletteOf(ThemeData theme) {
    final scheme = theme.colorScheme;
    final background = theme.scaffoldBackgroundColor;
    var surface = theme.cardTheme.color ?? theme.cardColor;
    if (surface == background) {
      surface = Color.lerp(background, scheme.onSurface, 0.05)!;
    }
    return EimzoPalette(
      primary: scheme.primary,
      background: background,
      surface: surface,
      text: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      divider: theme.dividerTheme.color ??
          (theme.useMaterial3 ? scheme.outlineVariant : theme.dividerColor),
    );
  }

  /// The button theme's corner radius, when it is a rounded rectangle with
  /// one. A stadium — Material 3's default — or anything else gives null,
  /// the SDK's own 16.
  static double? _radiusOf(ThemeData theme) {
    final style = theme.filledButtonTheme.style ?? theme.elevatedButtonTheme.style;
    final shape = style?.shape?.resolve(const {});
    if (shape is RoundedRectangleBorder) {
      return shape.borderRadius.resolve(TextDirection.ltr).topLeft.x;
    }
    return null;
  }

  /// What the native sides read. The font files are added by
  /// [EimzoFlutter.init], which looks them up in the app's assets.
  Map<String, dynamic> toMap() => {
        if (light != null) 'light': light!.toMap(),
        if (dark != null) 'dark': dark!.toMap(),
        'themeMode': themeMode.name,
        if (fontFamily != null) 'fontFamily': fontFamily,
        if (cornerRadius != null) 'cornerRadius': cornerRadius,
      };

  @override
  bool operator ==(Object other) =>
      other is EimzoAppearance &&
      other.light == light &&
      other.dark == dark &&
      other.themeMode == themeMode &&
      other.fontFamily == fontFamily &&
      other.cornerRadius == cornerRadius;

  @override
  int get hashCode => Object.hash(light, dark, themeMode, fontFamily, cornerRadius);
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

  /// The SDK's screens in the app's colours, font and corners (2.5.0). Null —
  /// the default — keeps the SDK's own design. See [EimzoAppearance].
  final EimzoAppearance? appearance;

  /// The language of the SDK's screens (2.5.0). Null — the default — keeps
  /// what the SDK did before: the language the user picked in its settings,
  /// else the phone's. Given, it is the language the SDK starts in; the
  /// user can still change it there, unless [showLanguagePicker] is false.
  final EimzoLanguage? language;

  /// Whether the SDK's settings offer a language (2.5.0); true by default.
  /// False hides the choice, and the SDK is always in [language] — or, with
  /// none, the phone's. For an app with its own language setting: pass its
  /// current language here, and call [EimzoFlutter.init] again when it
  /// changes.
  final bool showLanguagePicker;

  /// Whether the sign screen shows the hash of a request the app made itself
  /// (2.5.0); [EimzoHashDisplay.visible] by default.
  final EimzoHashDisplay hashDisplay;

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
    this.appearance,
    this.language,
    this.showLanguagePicker = true,
    this.hashDisplay = EimzoHashDisplay.visible,
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
        if (appearance != null) 'appearance': appearance!.toMap(),
        if (language != null) 'language': language!.name,
        'showLanguagePicker': showLanguagePicker,
        'hashDisplay': hashDisplay.name,
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
  ///
  /// The config's [EimzoConfig.appearance] and language take effect on the
  /// SDK's next screen. To follow a change in the app — its theme, its
  /// language — call this again with the new config.
  Future<bool> init({EimzoConfig config = const EimzoConfig()}) async {
    final arguments = config.toMap();
    final family = config.appearance?.fontFamily;
    if (family != null) {
      final fonts = await fontAssetsOf(family);
      if (fonts.isNotEmpty) {
        (arguments['appearance'] as Map<String, dynamic>)['fonts'] = fonts;
      }
    }
    try {
      final allowed = await _channel.invokeMethod<bool>('init', arguments);
      return allowed ?? false;
    } on PlatformException catch (e) {
      throw EimzoException(e.code, e.message ?? '');
    }
  }

  /// The asset files of the font [family] in the app's `FontManifest.json`:
  /// `regular`, and `medium` and `semibold` where the family has them —
  /// upright faces only, keyed by weight (400, 500, 600, else 700 for
  /// semibold). The regular face is the 400, else the weight nearest it.
  ///
  /// Empty when the manifest has no such family — a font the app registers
  /// some other way, such as `google_fonts` at run time, cannot be handed to
  /// the native SDK, which then keeps its own.
  @visibleForTesting
  static Future<Map<String, String>> fontAssetsOf(String family, {AssetBundle? bundle}) async {
    final List<dynamic> manifest;
    try {
      manifest = jsonDecode(await (bundle ?? rootBundle).loadString('FontManifest.json'))
          as List<dynamic>;
    } catch (_) {
      return const {};
    }
    final entry = manifest.whereType<Map<String, dynamic>>().where((f) => f['family'] == family);
    if (entry.isEmpty) return const {};
    final byWeight = <int, String>{};
    for (final face in (entry.first['fonts'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()) {
      final asset = face['asset'];
      if (asset is! String || face['style'] == 'italic') continue;
      byWeight.putIfAbsent((face['weight'] as num?)?.toInt() ?? 400, () => asset);
    }
    if (byWeight.isEmpty) return const {};
    final nearest = byWeight.keys.reduce((a, b) => (a - 400).abs() <= (b - 400).abs() ? a : b);
    return {
      'regular': byWeight[400] ?? byWeight[nearest]!,
      if (byWeight[500] != null) 'medium': byWeight[500]!,
      if ((byWeight[600] ?? byWeight[700]) != null) 'semibold': (byWeight[600] ?? byWeight[700])!,
    };
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
  /// Only for an integrator YT has registered for it. The permission, the
  /// integrator's «Kalitlar API», is off by default: YT turns it on at the
  /// integrator's request, once there is a contract, for all of the
  /// integrator's apps. Turned on, it takes effect when the app restarts, or
  /// within the hour; turned off, [sign] stops within a few seconds. Without
  /// it this and [sign] answer `api_not_allowed`. [openSignUi] stays open to
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
  ///    "type":"pfx","validFrom":"2025-03-01","validTo":"2027-03-01"}]}
  /// ```
  ///
  /// Every kind of key — file, QR, ID card, USB token, BAIK — that can be used
  /// in the configured [EimzoConfig.environment], expired ones too, in the
  /// SDK's own order with the default key first; a key added in the other
  /// environment is left out. `id` is opaque: hand it to [sign] as it is.
  /// `pinfl` is null when the certificate has none. `type` (2.5) is `pfx`
  /// (a key file, from a file or a QR code), `id_card` or `token` (USB or
  /// BAIK), so one holder's keys can be told apart; show a value you do not
  /// know as a plain key, since a later version may add one. `validFrom` and
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
