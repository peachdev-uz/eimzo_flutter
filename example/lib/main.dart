import 'dart:convert';

import 'package:eimzo_flutter/eimzo_flutter.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'E-IMZO Demo',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.indigo),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// A sign request the way an app makes one: the site's id, the document's
  /// id and the hash come from the app's own backend — here, a document
  /// captured from E-IMZO during QA — and the plugin makes the link. Never an
  /// `eimzo://` link taken from outside: that scheme is the E-IMZO app's.
  static final _signLink = EimzoSignLink.create(
    siteId: '1a47',
    documentId: '59282737',
    hash: '518b091cc3878831103872e422ec71d2e6ee501e255dce3290af02042edfcd69',
  );

  /// «Namuna bank»: a made-up bank's theme, to show the SDK in an app's own
  /// colours (2.5.0). The SDK takes them from the ThemeData.
  static final _bankLight = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0A6CFF)),
    scaffoldBackgroundColor: Colors.white,
    cardTheme: const CardThemeData(color: Color(0xFFF2F4F7)),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
  );
  static final _bankDark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF0A6CFF), brightness: Brightness.dark),
    scaffoldBackgroundColor: const Color(0xFF0C111D),
    cardTheme: const CardThemeData(color: Color(0xFF161B26)),
  );

  /// Whether the SDK opens in «Namuna bank»'s design: its colours, Russian
  /// without the SDK's language choice, and no hash on the app's own
  /// requests.
  bool _bank = false;

  /// The config for every call: iOS uses the last one `init` was given, so
  /// a change of design is another `init`.
  EimzoConfig get _config => _bank
      ? EimzoConfig(
          environment: EimzoEnvironment.dev,
          appearance: EimzoAppearance.fromTheme(_bankLight, dark: _bankDark),
          language: EimzoLanguage.ru,
          showLanguagePicker: false,
          hashDisplay: EimzoHashDisplay.hidden,
        )
      : const EimzoConfig(environment: EimzoEnvironment.dev);

  final _eimzo = EimzoFlutter.instance;

  /// The Keys API's last answer, as the SDK gave it.
  String? _json;

  /// The keys from the last `getKeys()`, and the one picked for `sign()`.
  List<Map<String, dynamic>> _keys = const [];
  String? _keyId;

  /// «Kalitlar API»: lists the keys the user has added in the SDK's UI.
  /// Only for an integrator YT has given the permission; otherwise the JSON
  /// says `api_not_allowed`.
  Future<void> _listKeys() async {
    if (!await _eimzo.init(config: _config)) return;
    final json = await _eimzo.getKeys();
    final reply = jsonDecode(json) as Map<String, dynamic>;
    final keys = reply['status'] == 'ok'
        ? (reply['keys'] as List).cast<Map<String, dynamic>>()
        : const <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      _json = json;
      _keys = keys;
      if (!keys.any((k) => k['id'] == _keyId)) {
        _keyId = keys.isEmpty ? null : keys.first['id'] as String;
      }
    });
  }

  /// «Kalitlar API»: signs [_signLink] with the picked key in the SDK's own
  /// sheet. The answer says how it ended; the signed document itself goes
  /// from E-IMZO to the site's backend.
  Future<void> _signWithKey(String keyId) async {
    final json = await _eimzo.sign(keyId: keyId, deepLink: _signLink);
    if (!mounted) return;
    setState(() => _json = json);
  }

  /// `validTo` is how an app tells an expired key; the list includes them.
  static String _label(Map<String, dynamic> key) {
    final validTo = key['validTo'] as String?;
    final expired = DateTime.tryParse(validTo ?? '')?.isBefore(DateTime.now()) ?? false;
    return '${key['name']} · ${validTo ?? '—'}${expired ? ' (muddati o\'tgan)' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final keyId = _keyId;
    final json = _json;
    return Scaffold(
      appBar: AppBar(title: const Text('E-IMZO Flutter')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ElevatedButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open E-IMZO native UI'),
            onPressed: () async {
              final allowed = await _eimzo.init(config: _config);

              if (!allowed) return;
              await _eimzo.openSignUi();
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.qr_code_2),
            label: const Text('Open with a sign request'),
            onPressed: () async {
              if (!await _eimzo.init(config: _config)) return;
              await _eimzo.openSignUi(deepLink: _signLink);
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('«Namuna bank» dizayni'),
            subtitle: const Text('Ilova ranglari, ruscha, hash\'siz'),
            value: _bank,
            onChanged: (on) => setState(() => _bank = on),
          ),
          const Divider(height: 32),
          Text('Kalitlar API', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.key),
            label: const Text('Kalitlar ro\'yxati'),
            onPressed: _listKeys,
          ),
          if (_keys.isNotEmpty) ...[
            const SizedBox(height: 8),
            DropdownButton<String>(
              isExpanded: true,
              value: keyId,
              items: [
                for (final key in _keys)
                  DropdownMenuItem(
                    value: key['id'] as String,
                    child: Text(_label(key), overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (id) => setState(() => _keyId = id),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.draw),
            label: const Text('Tanlangan kalit bilan imzolash'),
            onPressed: keyId == null ? null : () => _signWithKey(keyId),
          ),
          if (json != null) ...[
            const SizedBox(height: 16),
            SelectableText(json, style: const TextStyle(fontFamily: 'monospace')),
          ],
        ],
      ),
    );
  }
}
