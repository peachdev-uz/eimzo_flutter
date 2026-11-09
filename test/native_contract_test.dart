import 'dart:io';

import 'package:eimzo_flutter/eimzo_flutter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks that both native sides actually implement what Dart sends.
///
/// A method channel has no shared type: Dart hands over a string and a map, and
/// whatever the other side fails to read is dropped without a word. Nothing in
/// a build, an analyzer run or a widget test notices — the app compiles, ships,
/// and behaves as though the argument was never passed.
///
/// That is not hypothetical. Until 2.1.2 the iOS plugin answered `init` without
/// looking at its arguments and then opened the UI with a default config, so
/// `isTestMode`, the API URLs and the licence all stopped at the channel. The
/// symptom reached an integrator as "Litsenziya topilmadi" — with the licence
/// sitting in the config object they had passed in.
///
/// So this reads the native sources and insists every method and every config
/// key appears on both. It is a coarse check — a grep, not a type system — but
/// it is anchored to the real files, and the failure it prevents is the one
/// that costs a release.
void main() {
  final dart = File('lib/eimzo_flutter.dart');
  final kotlin = File(
      'android/src/main/kotlin/uz/peachdev/eimzo_flutter/EimzoFlutterPlugin.kt');
  final swift = File(
      'ios/eimzo_flutter/Sources/eimzo_flutter/EimzoFlutterPlugin.swift');

  late String dartSource;
  late String kotlinSource;
  late String swiftSource;

  setUpAll(() {
    // If a file moved, say so here rather than passing vacuously — a contract
    // test that silently checks nothing is worse than no test.
    for (final f in [dart, kotlin, swift]) {
      if (!f.existsSync()) {
        fail('manba topilmadi: ${f.path} — test yo\'lini yangilash kerak');
      }
    }
    dartSource = dart.readAsStringSync();
    kotlinSource = kotlin.readAsStringSync();
    swiftSource = swift.readAsStringSync();
  });

  /// Method names Dart invokes, read from the source rather than hand-listed —
  /// a list maintained by hand drifts the moment someone adds a method.
  Set<String> dartMethods() {
    final re = RegExp(r"invokeMethod<[^>]*>\(\s*'([A-Za-z]+)'");
    final found = re.allMatches(dartSource).map((m) => m.group(1)!).toSet();
    return found;
  }

  test('Dart really does invoke methods (the regex still matches)', () {
    // Guards the two tests below: if the call style changes, they would find
    // an empty set and pass without checking anything.
    expect(dartMethods(), isNotEmpty,
        reason: 'invokeMethod chaqiruvlari topilmadi — regex eskirgan');
    expect(dartMethods(), contains('openSignUi'));
  });

  test('every method Dart invokes is handled on Android', () {
    for (final method in dartMethods()) {
      expect(kotlinSource, contains('"$method"'),
          reason: 'Android plagini "$method" ni ushlamaydi');
    }
  });

  test('every method Dart invokes is handled on iOS', () {
    for (final method in dartMethods()) {
      expect(swiftSource, contains('"$method"'),
          reason: 'iOS plagini "$method" ni ushlamaydi');
    }
  });

  test('every EimzoConfig key is read on both platforms', () {
    // Every field set, so toMap() emits the full key set — the optional ones
    // are omitted when null, which is exactly how the gap hid before.
    const full = EimzoConfig(
      environment: EimzoEnvironment.dev,
      productionApiUrl: 'https://prod.example/rpc',
      testApiUrl: 'https://test.example/rpc',
      license: 'EIMZO1.payload.signature',
      debugLogging: true,
    );
    // The gateway override for YT's testing is in the map only when the app
    // is built with --dart-define=EIMZO_GATEWAY_URL, so it is added by hand.
    final keys = {...full.toMap().keys, 'gatewayOverride'};

    for (final key in ['environment', 'license', 'debugLogging']) {
      expect(keys, contains(key),
          reason: 'toMap() $key ni chiqarmayapti — test o\'z manbasini yo\'qotdi');
    }
    expect(dartSource, contains("'gatewayOverride'"),
        reason: 'Dart gateway override kalitini boshqa nom bilan yuboryapti');

    for (final key in keys) {
      expect(kotlinSource, contains('"$key"'),
          reason: 'Android plagini "$key" ni o\'qimaydi');
      expect(swiftSource, contains('"$key"'),
          reason: 'iOS plagini "$key" ni o\'qimaydi');
    }
  });

  test('every argument sign() sends is read on both platforms', () async {
    // Taken from the call itself rather than listed by hand: a key renamed on
    // one side only would reach the SDK as an empty string, and the app would
    // hear key_not_found or invalid_request for a key and a link that are
    // fine.
    TestWidgetsFlutterBinding.ensureInitialized();
    const channel = MethodChannel('uz.peachdev/eimzo_flutter');
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    MethodCall? sent;
    messenger.setMockMethodCallHandler(channel, (call) async {
      sent = call;
      return '{"status":"cancelled"}';
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    await EimzoFlutter.instance.sign(keyId: 'k', deepLink: 'eimzo://sign?qc=00');

    final keys = Map<String, dynamic>.from(sent!.arguments as Map).keys;
    expect(keys, containsAll(['keyId', 'deepLink']));
    for (final key in keys) {
      expect(kotlinSource, contains('"$key"'),
          reason: 'Android plagini sign() ning "$key" argumentini o\'qimaydi');
      expect(swiftSource, contains('"$key"'),
          reason: 'iOS plagini sign() ning "$key" argumentini o\'qimaydi');
    }
  });

  test('the Keys API reaches the SDK on both platforms', () {
    // A handler that answers without calling the SDK would compile and pass
    // every Dart test.
    expect(kotlinSource, contains('EImzoSDK.getKeys('),
        reason: 'Android plagini EImzoSDK.getKeys ni chaqirmaydi');
    expect(kotlinSource, contains('EImzoSDK.sign('),
        reason: 'Android plagini EImzoSDK.sign ni chaqirmaydi');
    // On iOS with the config init stored — the same rule as EImzoView.
    expect(swiftSource, contains('EImzoAPI.getKeys(config: config)'),
        reason: 'iOS plagini getKeys ga saqlangan konfiguratsiyani bermayapti');
    expect(swiftSource, matches(RegExp(r'EImzoAPI\.sign\([^)]*config: config\)')),
        reason: 'iOS plagini sign ga saqlangan konfiguratsiyani bermayapti');
  });

  test('the plugin errors Dart maps are the ones the platforms send', () {
    // Dart turns these two codes into the API's own JSON. Renamed on the
    // native side, they would fall through to a generic sign_failed.
    expect(dartSource, contains("'NO_ACTIVITY'"));
    expect(kotlinSource, contains('"NO_ACTIVITY"'),
        reason: 'Android plagini activity yo\'qligini boshqa kod bilan aytyapti');
    expect(dartSource, contains("'NOT_INITIALIZED'"));
    expect(swiftSource, contains('"NOT_INITIALIZED"'),
        reason: 'iOS plagini init chaqirilmaganini boshqa kod bilan aytyapti');
  });

  test('iOS passes the stored config into the SDK view', () {
    // Reading the keys is not enough on its own: 2.1.1 would have parsed them
    // into a value it then never handed to EImzoView.
    expect(swiftSource, contains('config: config'),
        reason: 'iOS plagini konfiguratsiyani EImzoView ga uzatmayapti');
  });

  test('the method channel name matches on all three sides', () {
    const method = 'uz.peachdev/eimzo_flutter';

    for (final entry in {
      'Dart': dartSource,
      'Android': kotlinSource,
      'iOS': swiftSource,
    }.entries) {
      expect(entry.value, contains(method),
          reason: '${entry.key} boshqa metod kanalini ishlatyapti');
    }
  });

  test('no side listens for eimzo:// links any more', () {
    // eimzo:// is the E-IMZO app's. A handler left behind on either platform
    // would take a link from any page or app and open the SDK with it.
    for (final entry in {
      'Dart': dartSource,
      'Android': kotlinSource,
      'iOS': swiftSource,
    }.entries) {
      for (final gone in [
        'getInitialDeeplink',
        'launchDeeplink',
        'onNewDeeplink',
        'eimzo_flutter/links',
        'onNewIntent',
        'addApplicationDelegate',
      ]) {
        expect(entry.value, isNot(contains(gone)),
            reason: '${entry.key} da $gone qolib ketgan');
      }
    }
  });

  test('the environment values are the ones both platforms read', () {
    // Dart sends the enum's name; the native sides map "dev" and fall back to
    // prod. A renamed value would quietly become prod on both.
    expect(EimzoEnvironment.values.map((e) => e.name), ['prod', 'dev']);
    expect(kotlinSource, contains('"dev"'),
        reason: 'Android plagini "dev" muhitini tanimaydi');
    expect(swiftSource, contains('EImzoEnvironment.init(rawValue:)'),
        reason: 'iOS plagini muhitni nomidan o\'qimaydi');
  });

  test('gateway addresses and the isTestMode key are gone from every side', () {
    // Removed before 2.3.0: the SDK carries its gateways, and the integrator
    // picks only the environment. isTestMode survives in Dart as a deprecated
    // parameter, but the channel carries the environment alone.
    for (final entry in {
      'Dart': dartSource,
      'Android': kotlinSource,
      'iOS': swiftSource,
    }.entries) {
      for (final key in ['testGatewayUrl', 'productionGatewayUrl']) {
        expect(entry.value, isNot(contains(key)),
            reason: '${entry.key} da $key qolib ketgan');
      }
    }
    expect(dartSource, isNot(contains("'isTestMode'")),
        reason: 'Dart isTestMode kalitini hamon yuboryapti');
    expect(kotlinSource, isNot(contains('"isTestMode"')),
        reason: 'Android plagini isTestMode kalitini hamon o\'qiyapti');
    expect(swiftSource, isNot(contains('"isTestMode"')),
        reason: 'iOS plagini isTestMode kalitini hamon o\'qiyapti');
  });

  test('signWithUsbToken is gone from every side', () {
    // Removed in 2.1.0: signing is reachable only through openSignUi. A native
    // handler left behind would be a live path back in, invisible from Dart.
    for (final entry in {
      'Dart': dartSource,
      'Android': kotlinSource,
      'iOS': swiftSource,
    }.entries) {
      expect(entry.value, isNot(contains('signWithUsbToken')),
          reason: '${entry.key} da signWithUsbToken qolib ketgan');
    }
  });
}
