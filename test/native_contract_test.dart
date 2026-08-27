import 'dart:io';

import 'package:eimzo_flutter/eimzo_flutter.dart';
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
      isTestMode: true,
      productionApiUrl: 'https://prod.example/rpc',
      testApiUrl: 'https://test.example/rpc',
      license: 'EIMZO1.payload.signature',
    );
    final keys = full.toMap().keys.toSet();

    expect(keys, contains('license'),
        reason: 'toMap() license ni chiqarmayapti — test o\'z manbasini yo\'qotdi');

    for (final key in keys) {
      expect(kotlinSource, contains('"$key"'),
          reason: 'Android plagini "$key" ni o\'qimaydi');
      expect(swiftSource, contains('"$key"'),
          reason: 'iOS plagini "$key" ni o\'qimaydi');
    }
  });

  test('iOS passes the stored config into the SDK view', () {
    // Reading the keys is not enough on its own: 2.1.1 would have parsed them
    // into a value it then never handed to EImzoView.
    expect(swiftSource, contains('config: config'),
        reason: 'iOS plagini konfiguratsiyani EImzoView ga uzatmayapti');
  });

  test('the channel names match on all three sides', () {
    const method = 'uz.peachdev/eimzo_flutter';
    const event = 'uz.peachdev/eimzo_flutter/links';

    for (final entry in {
      'Dart': dartSource,
      'Android': kotlinSource,
      'iOS': swiftSource,
    }.entries) {
      expect(entry.value, contains(method),
          reason: '${entry.key} boshqa metod kanalini ishlatyapti');
      expect(entry.value, contains(event),
          reason: '${entry.key} boshqa hodisa kanalini ishlatyapti');
    }
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
