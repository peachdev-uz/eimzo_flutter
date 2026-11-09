import 'dart:convert';

import 'package:eimzo_flutter/eimzo_flutter.dart';
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
