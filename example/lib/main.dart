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

  static const _deepLink =
      'eimzo://sign?qc=1a4759282737518b091cc3878831103872e422ec71d2e6ee501e255dce3290af02042edfcd6989e4017b';

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
              onPressed: () => eimzo.openSignUi(),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              icon: const Icon(Icons.qr_code_2),
              label: const Text('Open with deep link (sign flow)'),
              onPressed: () => eimzo.openSignUi(deepLink: _deepLink),
            ),
          ],
        ),
      ),
    );
  }
}
