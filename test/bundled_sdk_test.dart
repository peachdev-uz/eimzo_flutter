import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Checks that the screens this package ships actually exist in the SDK it
/// ships them with.
///
/// The plugin carries the native SDK as three separate pieces — classes in
/// `android/libs/*.jar`, resources under `android/src/main/res/`, a manifest
/// listing activities — and nothing ties them together at build time. A
/// navigation graph naming a class that is not in the jar compiles, packages
/// and installs; it fails when a user taps the row that leads there.
///
/// Both halves of that have already shipped:
///
/// - 2.0.0 minified the library itself, and R8 deleted four screens from the
///   AAR because the only thing referencing them was the navigation XML.
///   Result: `ClassNotFoundException` on the settings button.
/// - 2.0.2 replaced the jar without re-copying `res/`, so the package briefly
///   carried the old layout — buttons drawn on screen with nothing behind
///   them.
///
/// Needs `unzip`; skips itself where that is missing rather than failing on a
/// machine that simply cannot run it.
void main() {
  final navDir = Directory('android/src/main/res/navigation');
  final libs = Directory('android/libs');
  final manifest = File('android/src/main/AndroidManifest.xml');

  late Set<String> jarClasses;
  late String sdkJarName;
  var canRun = true;

  setUpAll(() {
    if (Process.runSync('which', ['unzip']).exitCode != 0) {
      canRun = false;
      return;
    }
    for (final e in [navDir, libs, manifest]) {
      if (!e.existsSync()) {
        fail('kutilgan yo\'l topilmadi: ${e.path}');
      }
    }

    final sdkJar = libs
        .listSync()
        .whereType<File>()
        .firstWhere(
          (f) => f.path.split('/').last.startsWith('eimzo-sdk-'),
          orElse: () => throw StateError('android/libs/ da eimzo-sdk jar yo\'q'),
        );
    sdkJarName = sdkJar.path.split('/').last;

    final listing = Process.runSync('unzip', ['-l', sdkJar.path]);
    if (listing.exitCode != 0) {
      fail('jar o\'qib bo\'lmadi: ${listing.stderr}');
    }
    jarClasses = RegExp(r'([\w/$]+)\.class')
        .allMatches(listing.stdout as String)
        .map((m) => m.group(1)!.replaceAll('/', '.'))
        .toSet();
  });

  /// Class names an XML file points the framework at.
  Set<String> namesIn(String xml) => RegExp(r'android:name="(uz\.eimzo\.[\w.]+)"')
      .allMatches(xml)
      .map((m) => m.group(1)!)
      .toSet();

  test('the bundled jar was read at all', () {
    if (!canRun) return;
    expect(jarClasses, isNotEmpty, reason: '$sdkJarName bo\'sh ko\'rinyapti');
    expect(jarClasses.length, greaterThan(50),
        reason: 'jar kutilganidan kichik — qisqartirilgan bo\'lishi mumkin');
  });

  test('every screen the navigation graph names exists in the jar', () {
    if (!canRun) return;

    final graphs = navDir.listSync().whereType<File>().toList();
    expect(graphs, isNotEmpty, reason: 'navigatsiya grafi topilmadi');

    final missing = <String>[];
    for (final graph in graphs) {
      for (final name in namesIn(graph.readAsStringSync())) {
        if (!jarClasses.contains(name)) missing.add(name);
      }
    }

    expect(missing, isEmpty,
        reason: 'bu ekranlar $sdkJarName ichida yo\'q — bosilganda '
            'ClassNotFoundException beradi: ${missing.join(", ")}');
  });

  test('every SDK activity the manifest declares exists in the jar', () {
    if (!canRun) return;

    final missing = namesIn(manifest.readAsStringSync())
        .where((n) => !jarClasses.contains(n))
        .toList();

    expect(missing, isEmpty,
        reason: 'manifest e\'lon qilgan, jar da yo\'q: ${missing.join(", ")}');
  });

  test('the resources ship alongside the classes that use them', () {
    if (!canRun) return;

    // A ViewBinding class is generated per layout and compiled into the jar.
    // If res/ and the jar drift apart, the two stop lining up — which is the
    // 2.0.2 failure, seen from the other direction.
    final layouts = Directory('android/src/main/res/layout')
        .listSync()
        .whereType<File>()
        .map((f) => f.path.split('/').last.replaceAll('.xml', ''))
        .where((n) => n.startsWith('eimzo_ui_'))
        .toSet();

    expect(layouts, isNotEmpty, reason: 'layout fayllari topilmadi');

    String bindingFor(String layout) {
      final camel = layout
          .split('_')
          .map((p) => p.isEmpty ? p : p[0].toUpperCase() + p.substring(1))
          .join();
      return 'uz.eimzo.sdk.databinding.${camel}Binding';
    }

    final orphans = layouts
        .map(bindingFor)
        .where((b) => !jarClasses.contains(b))
        .toList();

    expect(orphans, isEmpty,
        reason: 'layout bor, unga tegishli binding klassi $sdkJarName da yo\'q '
            '— res/ va jar bir-biriga mos emas: ${orphans.join(", ")}');
  });
}
