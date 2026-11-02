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

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  /// A sign request the way an app makes one: the site's id, the document's
  /// id and the hash come from the app's own backend — here, a document
  /// captured from E-IMZO during QA — and the plugin makes the link. Never an
  /// `eimzo://` link taken from outside: that scheme is the E-IMZO app's.
  static final _signLink = EimzoSignLink.create(
    siteId: '1a47',
    documentId: '59282737',
    hash: '518b091cc3878831103872e422ec71d2e6ee501e255dce3290af02042edfcd69',
  );

  @override
  Widget build(BuildContext context) {
    final eimzo = EimzoFlutter.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('E-IMZO Flutter')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open E-IMZO native UI'),
              onPressed: () async {
                final allowed = await eimzo.init(
                  config: const EimzoConfig(environment: EimzoEnvironment.dev),
                );

                if (!allowed) return;
                await eimzo.openSignUi();
              },
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Open with a sign request'),
              onPressed: () => eimzo.openSignUi(deepLink: _signLink),
            ),
          ],
        ),
      ),
    );
  }
}
