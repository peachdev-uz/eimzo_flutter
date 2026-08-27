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
      if (reply is PlatformException) throw reply as PlatformException;
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

    test('sends isTestMode even when false', () async {
      // Always present, because "absent" and "false" must not be the same
      // question for the native side to answer.
      reply = true;
      await EimzoFlutter.instance.init();

      expect(argsOf(calls.single)['isTestMode'], false);
    });

    test('carries API URL overrides', () async {
      reply = true;
      await EimzoFlutter.instance.init(
        config: const EimzoConfig(
          isTestMode: true,
          productionApiUrl: 'https://prod.example/rpc',
          testApiUrl: 'https://test.example/rpc',
        ),
      );

      final args = argsOf(calls.single);
      expect(args['isTestMode'], true);
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

  group('deep links', () {
    test('getInitialDeeplink returns what the native side held', () async {
      reply = 'eimzo://sign?qc=COLD';
      expect(await EimzoFlutter.instance.getInitialDeeplink(),
          'eimzo://sign?qc=COLD');
      expect(calls.single.method, 'getInitialDeeplink');
    });

    test('getInitialDeeplink returns null on a cold start with no link',
        () async {
      reply = null;
      expect(await EimzoFlutter.instance.getInitialDeeplink(), isNull);
    });

    test('launchDeeplink sends the url', () async {
      await EimzoFlutter.instance.launchDeeplink('eimzo://sign?qc=X');

      expect(calls.single.method, 'launchDeeplink');
      expect(argsOf(calls.single)['url'], 'eimzo://sign?qc=X');
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
