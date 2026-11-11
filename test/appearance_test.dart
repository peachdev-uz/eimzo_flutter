import 'dart:convert';

import 'package:eimzo_flutter/eimzo_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// [EimzoAppearance.fromTheme] and the font lookup: what an app's own theme
/// turns into before it crosses the channel.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fromTheme', () {
    test('takes the six colours from a Material 3 theme', () {
      final theme = ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A6CFF)),
        cardTheme: const CardThemeData(color: Color(0xFFF2F4F7)),
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
      );

      final palette = EimzoAppearance.fromTheme(theme).light!;
      expect(palette.primary, theme.colorScheme.primary);
      expect(palette.background, const Color(0xFFFFFFFF));
      expect(palette.surface, const Color(0xFFF2F4F7));
      expect(palette.text, theme.colorScheme.onSurface);
      expect(palette.textSecondary, theme.colorScheme.onSurfaceVariant);
      expect(palette.divider, theme.colorScheme.outlineVariant);
    });

    test('cards the colour of the page are drawn a shade toward the text', () {
      // Material 3's defaults: scaffold and card are both colorScheme.surface.
      final theme = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo);
      expect(theme.cardColor, theme.scaffoldBackgroundColor,
          reason: 'Flutter M3 standarti o\'zgargan — testni yangilang');

      final palette = EimzoAppearance.fromTheme(theme).light!;
      expect(palette.surface, isNot(palette.background));
      expect(palette.surface,
          Color.lerp(theme.scaffoldBackgroundColor, theme.colorScheme.onSurface, 0.05));
    });

    test('a Material 2 theme gives its divider colour', () {
      final theme = ThemeData(useMaterial3: false, dividerColor: const Color(0x1F000000));
      expect(EimzoAppearance.fromTheme(theme).light!.divider, const Color(0x1F000000));
    });

    test('the dark theme fills the dark palette, the mode passes through', () {
      final light = ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo);
      final dark = ThemeData(
          useMaterial3: true, colorSchemeSeed: Colors.indigo, brightness: Brightness.dark);

      final appearance = EimzoAppearance.fromTheme(light, dark: dark, themeMode: ThemeMode.light);
      expect(appearance.dark!.primary, dark.colorScheme.primary);
      expect(appearance.dark!.text, dark.colorScheme.onSurface);
      expect(appearance.themeMode, ThemeMode.light);
      expect(EimzoAppearance.fromTheme(light).dark, isNull);
    });

    test('a rounded-rectangle button gives its radius, a stadium none', () {
      final rounded = ThemeData(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
      expect(EimzoAppearance.fromTheme(rounded).cornerRadius, 10);

      final elevated = ThemeData(
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
        ),
      );
      expect(EimzoAppearance.fromTheme(elevated).cornerRadius, 4);

      final stadium = ThemeData(
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(shape: const StadiumBorder()),
        ),
      );
      expect(EimzoAppearance.fromTheme(stadium).cornerRadius, isNull);
      expect(EimzoAppearance.fromTheme(ThemeData()).cornerRadius, isNull);
    });

    test('takes the text theme\'s font family', () {
      final theme = ThemeData(fontFamily: 'Inter');
      expect(EimzoAppearance.fromTheme(theme).fontFamily, 'Inter');
    });
  });

  group('fontAssetsOf', () {
    final manifest = jsonEncode([
      {
        'family': 'Inter',
        'fonts': [
          {'asset': 'fonts/Inter-Regular.ttf'},
          {'asset': 'fonts/Inter-Italic.ttf', 'style': 'italic'},
          {'asset': 'fonts/Inter-Medium.ttf', 'weight': 500},
          {'asset': 'fonts/Inter-Bold.ttf', 'weight': 700},
        ],
      },
      {
        'family': 'Light',
        'fonts': [
          {'asset': 'fonts/Light-300.ttf', 'weight': 300},
          {'asset': 'fonts/Light-600.ttf', 'weight': 600},
        ],
      },
      {
        'family': 'packages/brand_kit/Brand',
        'fonts': [
          {'asset': 'packages/brand_kit/fonts/Brand.ttf'},
        ],
      },
    ]);
    final bundle = _StringBundle({'FontManifest.json': manifest});

    test('picks regular, medium and semibold (700 standing in for 600)', () async {
      expect(await EimzoFlutter.fontAssetsOf('Inter', bundle: bundle), {
        'regular': 'fonts/Inter-Regular.ttf',
        'medium': 'fonts/Inter-Medium.ttf',
        'semibold': 'fonts/Inter-Bold.ttf',
      });
    });

    test('with no 400 the nearest weight is the regular face', () async {
      expect(await EimzoFlutter.fontAssetsOf('Light', bundle: bundle), {
        'regular': 'fonts/Light-300.ttf',
        'semibold': 'fonts/Light-600.ttf',
      });
    });

    test('a package font is found by its full family name', () async {
      expect(await EimzoFlutter.fontAssetsOf('packages/brand_kit/Brand', bundle: bundle),
          {'regular': 'packages/brand_kit/fonts/Brand.ttf'});
    });

    test('an unknown family or no manifest gives nothing', () async {
      expect(await EimzoFlutter.fontAssetsOf('Roboto', bundle: bundle), isEmpty);
      expect(await EimzoFlutter.fontAssetsOf('Inter', bundle: _StringBundle({})), isEmpty);
    });
  });
}

/// An asset bundle of strings, for the font manifest.
class _StringBundle extends CachingAssetBundle {
  _StringBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) throw FlutterError('asset $key yo\'q');
    return ByteData.sublistView(utf8.encode(value));
  }
}
