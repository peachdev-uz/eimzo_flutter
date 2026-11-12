import 'dart:convert';

import 'package:eimzo_flutter/eimzo_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// What the Dart side actually puts on the wire.
///
/// The plugin is a thin shell, so almost every bug it has ever had lived at
/// this boundary rather than inside it: an argument that stopped being sent, a
/// method the native side never handled, a config field that existed in Dart
/// and nowhere else. None of that shows up in a build — the channel is
/// untyped, and a key nobody reads is silently dropped.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('uz.peachdev/eimzo_flutter');

  late List<MethodCall> calls;
  Object? reply;

  setUp(() {
    calls = [];
    reply = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      // PlatformException and MissingPluginException alike: the binding
      // turns each into what a real native side would send.
      if (reply is Exception) throw reply as Exception;
      return reply;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Map<String, dynamic> argsOf(MethodCall call) =>
      Map<String, dynamic>.from(call.arguments as Map);

  group('init', () {
    test('forwards the licence when one is configured', () async {
      // 2.1.2's bug in one assertion: the token was accepted by Dart and never
      // reached either native side.
      reply = true;
      await EimzoFlutter.instance
          .init(config: const EimzoConfig(license: 'EIMZO1.payload.signature'));

      expect(calls.single.method, 'init');
      expect(argsOf(calls.single)['license'], 'EIMZO1.payload.signature');
    });

    test('omits the licence key entirely when none is configured', () async {
      // Not "sends null" — omitted. The native sides fall back to the bundled
      // file when the key is absent, and a null would read the same only by
      // luck of how each platform decodes it.
      reply = true;
      await EimzoFlutter.instance.init();

      expect(argsOf(calls.single).containsKey('license'), isFalse);
    });

    test('sends the environment, prod when none is chosen', () async {
      // Always present, because "absent" and "prod" must not be the same
      // question for the native side to answer.
      reply = true;
      await EimzoFlutter.instance.init();

      expect(argsOf(calls.single)['environment'], 'prod');
    });

    test('sends dev when it is chosen', () async {
      reply = true;
      await EimzoFlutter.instance
          .init(config: const EimzoConfig(environment: EimzoEnvironment.dev));

      expect(argsOf(calls.single)['environment'], 'dev');
    });

    test('a 2.2 config with isTestMode still picks the environment', () async {
      reply = true;
      // ignore: deprecated_member_use_from_same_package
      await EimzoFlutter.instance.init(config: const EimzoConfig(isTestMode: true));

      expect(argsOf(calls.single)['environment'], 'dev');
      expect(argsOf(calls.single).containsKey('isTestMode'), isFalse);
    });

    test('sends no gateway address', () async {
      // The SDK carries the gateways itself; the integrator picks an
      // environment and nothing else. The override for YT's testing comes
      // only from --dart-define, which these tests do not set.
      reply = true;
      await EimzoFlutter.instance
          .init(config: const EimzoConfig(environment: EimzoEnvironment.dev));

      final keys = argsOf(calls.single).keys;
      expect(keys.where((k) => k.toLowerCase().contains('gateway')), isEmpty);
    });

    test('carries API URL overrides', () async {
      reply = true;
      await EimzoFlutter.instance.init(
        config: const EimzoConfig(
          environment: EimzoEnvironment.dev,
          productionApiUrl: 'https://prod.example/rpc',
          testApiUrl: 'https://test.example/rpc',
        ),
      );

      final args = argsOf(calls.single);
      expect(args['environment'], 'dev');
      expect(args['productionApiUrl'], 'https://prod.example/rpc');
      expect(args['testApiUrl'], 'https://test.example/rpc');
    });

    test('returns false when the native side refuses', () async {
      reply = false;
      expect(await EimzoFlutter.instance.init(), isFalse);
    });

    test('treats a null reply as refusal', () async {
      // Fail closed: an unimplemented or half-migrated native side must not
      // read as "licensed".
      reply = null;
      expect(await EimzoFlutter.instance.init(), isFalse);
    });
  });

  group('init: appearance, language, hash (2.5.0)', () {
    test('a 2.4 config sends the defaults and no appearance', () async {
      // Without an appearance the SDK keeps its own design; the native sides
      // must not be handed an empty one, which would hide its wallpaper and
      // dark-mode choice for nothing.
      reply = true;
      await EimzoFlutter.instance.init();

      final args = argsOf(calls.single);
      expect(args.containsKey('appearance'), isFalse);
      expect(args.containsKey('language'), isFalse);
      expect(args['showLanguagePicker'], isTrue);
      expect(args['hashDisplay'], 'visible');
    });

    test('colours go as 0xAARRGGBB, only the ones given', () async {
      reply = true;
      await EimzoFlutter.instance.init(
        config: const EimzoConfig(
          appearance: EimzoAppearance(
            light: EimzoPalette(primary: Color(0xFF0A6CFF), background: Color(0xFFFFFFFF)),
            dark: EimzoPalette(primary: Color(0xFF4D94FF)),
            themeMode: ThemeMode.dark,
            cornerRadius: 12,
          ),
        ),
      );

      final appearance = Map<String, dynamic>.from(argsOf(calls.single)['appearance'] as Map);
      expect(appearance['light'], {'primary': 0xFF0A6CFF, 'background': 0xFFFFFFFF});
      expect(appearance['dark'], {'primary': 0xFF4D94FF});
      expect(appearance['themeMode'], 'dark');
      expect(appearance['cornerRadius'], 12);
      expect(appearance.containsKey('fontFamily'), isFalse);
      expect(appearance.containsKey('fonts'), isFalse);
    });

    test('the theme mode is the system one unless chosen', () async {
      reply = true;
      await EimzoFlutter.instance.init(
        config: const EimzoConfig(appearance: EimzoAppearance()),
      );
      expect((argsOf(calls.single)['appearance'] as Map)['themeMode'], 'system');
    });

    test('language, its picker and the hash travel by name', () async {
      reply = true;
      await EimzoFlutter.instance.init(
        config: const EimzoConfig(
          language: EimzoLanguage.ru,
          showLanguagePicker: false,
          hashDisplay: EimzoHashDisplay.hidden,
        ),
      );

      final args = argsOf(calls.single);
      expect(args['language'], 'ru');
      expect(args['showLanguagePicker'], isFalse);
      expect(args['hashDisplay'], 'hidden');
    });

    test('a font family with no files in the app is sent by name only', () async {
      // The test binding has no FontManifest.json for this family: the
      // native side keeps its own font (Android) or tries the name (iOS).
      reply = true;
      await EimzoFlutter.instance.init(
        config: const EimzoConfig(appearance: EimzoAppearance(fontFamily: 'NoSuchFont')),
      );

      final appearance = argsOf(calls.single)['appearance'] as Map;
      expect(appearance['fontFamily'], 'NoSuchFont');
      expect(appearance.containsKey('fonts'), isFalse);
    });
  });

  group('openSignUi', () {
    test('sends the deep link when given', () async {
      await EimzoFlutter.instance.openSignUi(deepLink: 'eimzo://sign?qc=ABC');

      expect(calls.single.method, 'openSignUi');
      expect(argsOf(calls.single)['deepLink'], 'eimzo://sign?qc=ABC');
    });

    test('omits the deep link when there is none', () async {
      await EimzoFlutter.instance.openSignUi();

      expect(argsOf(calls.single).containsKey('deepLink'), isFalse);
    });
  });

  group('Kalitlar API', () {
    // The native SDKs' JSON, byte for byte: Dart must not re-encode it, and
    // an app parses the same text on Android, iOS and Flutter.
    const keysJson = '{"status":"ok","keys":[{"id":"7a3f01","pinfl":null,'
        '"name":"ALIYEV VALI ALIYEVICH","validFrom":"2025-03-01","validTo":null}]}';

    Map<String, dynamic> decoded(String json) => jsonDecode(json) as Map<String, dynamic>;

    test('getKeys calls getKeys and returns the native JSON unchanged', () async {
      reply = keysJson;

      final json = await EimzoFlutter.instance.getKeys();

      expect(calls.single.method, 'getKeys');
      expect(json, keysJson);
    });

    test('sign passes the key id and the link through as they are', () async {
      reply = '{"status":"signed"}';
      const link = 'eimzo://sign?qc=1a4759282737518b';

      await EimzoFlutter.instance.sign(keyId: '7a3f01', deepLink: link);

      expect(calls.single.method, 'sign');
      expect(argsOf(calls.single), {'keyId': '7a3f01', 'deepLink': link});
    });

    test('sign returns each native outcome unchanged', () async {
      for (final outcome in [
        '{"status":"signed"}',
        '{"status":"cancelled"}',
        '{"status":"error","code":"key_expired","message":"The key\'s certificate has expired."}',
        '{"status":"error","code":"api_not_allowed","message":"No «Kalitlar API» permission."}',
      ]) {
        reply = outcome;
        expect(await EimzoFlutter.instance.sign(keyId: 'k', deepLink: 'l'), outcome);
      }
    });

    test('no Android activity is sign_failed / no_activity, not an exception', () async {
      // What the Kotlin side's requireActivity sends.
      reply = PlatformException(code: 'NO_ACTIVITY', message: 'Activity not attached');

      expect(await EimzoFlutter.instance.sign(keyId: 'k', deepLink: 'l'),
          '{"status":"error","code":"sign_failed","message":"no_activity"}');
    });

    test('iOS without init is not_initialized, with the native words', () async {
      reply = PlatformException(
          code: 'NOT_INITIALIZED', message: 'EimzoFlutter.instance.init has not been called yet.');

      for (final call in [
        () => EimzoFlutter.instance.getKeys(),
        () => EimzoFlutter.instance.sign(keyId: 'k', deepLink: 'l'),
      ]) {
        expect(decoded(await call()), {
          'status': 'error',
          'code': 'not_initialized',
          'message': 'EimzoFlutter.instance.init has not been called yet.',
        });
      }
    });

    test('any other PlatformException is sign_failed with its message', () async {
      reply = PlatformException(code: 'error', message: 'Reply "already" submitted');

      for (final call in [
        () => EimzoFlutter.instance.getKeys(),
        () => EimzoFlutter.instance.sign(keyId: 'k', deepLink: 'l'),
      ]) {
        // Valid JSON even when the message has quotes in it.
        expect(decoded(await call()), {
          'status': 'error',
          'code': 'sign_failed',
          'message': 'Reply "already" submitted',
        });
      }
    });

    test('a message-less PlatformException still says something', () async {
      reply = PlatformException(code: 'SOME_CODE');

      expect(decoded(await EimzoFlutter.instance.getKeys())['message'], 'SOME_CODE');
    });

    test('no native side at all is sign_failed, not an exception', () async {
      // Another platform, or a host whose native build predates 2.4.
      reply = MissingPluginException('No implementation found for method getKeys');

      final json = decoded(await EimzoFlutter.instance.getKeys());

      expect(json['status'], 'error');
      expect(json['code'], 'sign_failed');
      expect(json['message'], contains('No implementation'));
    });

    test('a null reply is sign_failed rather than a null string', () async {
      reply = null;

      final json = decoded(await EimzoFlutter.instance.sign(keyId: 'k', deepLink: 'l'));

      expect(json.keys, ['status', 'code', 'message']);
      expect(json['code'], 'sign_failed');
    });
  });

  group('Kalitlar API: kalit qo\'shish (2.6)', () {
    Map<String, dynamic> decoded(String json) => jsonDecode(json) as Map<String, dynamic>;

    const added = '{"status":"added","key":{"id":"7a3f01","pinfl":"31234567890123",'
        '"name":"ALIYEV VALI ALIYEVICH","type":"pfx","validFrom":"2025-03-01","validTo":"2027-03-01"}}';

    test('addPfxKey sends the bytes, the password and no save by default', () async {
      reply = added;
      final pfx = Uint8List.fromList([0x30, 0x82, 0x01, 0xff]);

      final json = await EimzoFlutter.instance.addPfxKey(pfx: pfx, password: 'parol');

      expect(calls.single.method, 'addPfxKey');
      expect(argsOf(calls.single), {'pfx': pfx, 'password': 'parol', 'savePassword': false});
      expect(json, added, reason: 'the native JSON, byte for byte');
    });

    test('addQrKey sends the code as it is, and the save choice', () async {
      reply = added;
      const code = 'E73101AABB';

      await EimzoFlutter.instance.addQrKey(qrCode: code, password: 'p', savePassword: true);

      expect(calls.single.method, 'addQrKey');
      expect(argsOf(calls.single), {'qrCode': code, 'password': 'p', 'savePassword': true});
    });

    test('addIdCardKey and addTokenKey send the PIN and no save by default', () async {
      reply = '{"status":"cancelled"}';

      expect(await EimzoFlutter.instance.addIdCardKey(pin: '12345678'), '{"status":"cancelled"}');
      await EimzoFlutter.instance.addTokenKey(pin: '1234', savePin: true);

      expect(calls.map((c) => c.method), ['addIdCardKey', 'addTokenKey']);
      expect(argsOf(calls[0]), {'pin': '12345678', 'savePin': false});
      expect(argsOf(calls[1]), {'pin': '1234', 'savePin': true});
    });

    test('each native outcome comes back unchanged', () async {
      for (final outcome in [
        added,
        '{"status":"exists","key":{"id":"7a3f01","pinfl":null,"name":"A","type":"token","validFrom":null,"validTo":null}}',
        '{"status":"error","code":"wrong_pin","message":"The PIN is wrong.","triesLeft":2}',
        '{"status":"error","code":"token_not_found","message":"No USB or BAIK token is plugged in."}',
      ]) {
        reply = outcome;
        expect(await EimzoFlutter.instance.addTokenKey(pin: '1'), outcome);
      }
    });

    test('no Android activity is add_failed / no_activity, not an exception', () async {
      reply = PlatformException(code: 'NO_ACTIVITY', message: 'Activity not attached');

      expect(await EimzoFlutter.instance.addIdCardKey(pin: '1'),
          '{"status":"error","code":"add_failed","message":"no_activity"}');
    });

    test('iOS without init is not_initialized', () async {
      reply = PlatformException(
          code: 'NOT_INITIALIZED', message: 'EimzoFlutter.instance.init has not been called yet.');

      expect(decoded(await EimzoFlutter.instance.addQrKey(qrCode: 'c', password: 'p'))['code'],
          'not_initialized');
    });

    test('any other plugin failure is add_failed, never sign_failed or an exception', () async {
      reply = PlatformException(code: 'error', message: 'Reply "already" submitted');
      expect(decoded(await EimzoFlutter.instance.addTokenKey(pin: '1')), {
        'status': 'error',
        'code': 'add_failed',
        'message': 'Reply "already" submitted',
      });

      reply = MissingPluginException('No implementation found for method addPfxKey');
      final missing = decoded(await EimzoFlutter.instance
          .addPfxKey(pfx: Uint8List(1), password: 'p'));
      expect(missing['code'], 'add_failed');

      reply = null;
      expect(decoded(await EimzoFlutter.instance.addIdCardKey(pin: '1'))['code'], 'add_failed');
    });

    test('cancelAddKey asks the native side and never throws', () async {
      reply = null;
      await EimzoFlutter.instance.cancelAddKey();
      expect(calls.single.method, 'cancelAddKey');

      reply = PlatformException(code: 'error');
      await EimzoFlutter.instance.cancelAddKey();
      reply = MissingPluginException();
      await EimzoFlutter.instance.cancelAddKey();
    });
  });

  group('errors', () {
    test('a PlatformException surfaces as EimzoException', () async {
      reply = PlatformException(code: 'NO_VC', message: 'No root controller');

      await expectLater(
        EimzoFlutter.instance.openSignUi(),
        throwsA(isA<EimzoException>()
            .having((e) => e.code, 'code', 'NO_VC')
            .having((e) => e.message, 'message', 'No root controller')),
      );
    });

    test('a message-less PlatformException does not produce "null"', () async {
      reply = PlatformException(code: 'ARG');

      await expectLater(
        EimzoFlutter.instance.init(),
        throwsA(isA<EimzoException>().having((e) => e.message, 'message', '')),
      );
    });
  });
}
