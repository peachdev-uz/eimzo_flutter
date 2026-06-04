# eimzo_flutter

Thin Flutter plugin that bootstraps the official [E-IMZO Mobile SDK](https://github.com/peachdev-uz/eimzo-mobile-sdk) (`eimzo-sdk-1.0.0.aar` bundled inside) on the host activity. All signing / key-management UI is owned by the native SDK; the Flutter side just initializes it and receives `eimzo://sign?...` deep links.

## Platform support

| Android | iOS |
|---------|-----|
| ✅ (minSdk 24) | ✅ (iOS 16+) |

## Setup

### 1. Add the dependency

```yaml
dependencies:
  eimzo_flutter: ^1.0.0
```

### 2. Android `app/build.gradle`

```groovy
android {
    compileSdk 34
    defaultConfig {
        minSdk 24
        targetSdk 34
    }
    compileOptions {
        coreLibraryDesugaringEnabled true
        sourceCompatibility JavaVersion.VERSION_17
        targetCompatibility JavaVersion.VERSION_17
    }
    kotlinOptions { jvmTarget = '17' }
}

dependencies {
    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
}
```

### 3. `AndroidManifest.xml` — declare the deep-link intent-filter

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop">

    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>

    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="eimzo" android:host="sign" />
    </intent-filter>
</activity>
```

Permissions (`INTERNET`, `NFC`, `CAMERA`, `READ_EXTERNAL_STORAGE` ≤ API 32) and the NFC / USB-host `<uses-feature>` declarations are merged in from the plugin manifest automatically.

### 4. Theme — must inherit Material Components

The SDK's blocked-app screen requires a Material theme:

```xml
<style name="LaunchTheme" parent="Theme.MaterialComponents.Light.NoActionBar">
    <item name="android:windowBackground">@drawable/launch_background</item>
</style>
<style name="NormalTheme" parent="Theme.MaterialComponents.Light.NoActionBar">
    <item name="android:windowBackground">?android:colorBackground</item>
</style>
```

### 5. iOS — minimum deployment target

In `ios/Podfile`:
```ruby
platform :ios, '16.0'
```

### 6. iOS — `Info.plist` permissions and deeplink scheme

```xml
<!-- Camera (QR scanner) -->
<key>NSCameraUsageDescription</key>
<string>QR-kod skanerlash uchun kamera kerak</string>

<!-- NFC (ID-karta) -->
<key>NFCReaderUsageDescription</key>
<string>ID-karta orqali kalit o'qish uchun NFC kerak</string>
<key>com.apple.developer.nfc.readersession.iso7816.select-identifiers</key>
<array>
  <string>65696D7A6F617070</string>  <!-- "eimzoapp" ASCII -->
</array>

<!-- eimzo:// deep links -->
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleURLName</key>
    <string>YOUR.BUNDLE.ID.signing</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>eimzo</string>
    </array>
  </dict>
</array>
```

### 7. iOS — NFC entitlement

Add to `Runner.entitlements` (create the file if missing and link it via Xcode → Signing & Capabilities → + Capability → Near Field Communication Tag Reading):

```xml
<key>com.apple.developer.nfc.readersession.formats</key>
<array><string>TAG</string></array>
```

Apple requires a one-time NFC entitlement approval on your Developer Portal account for production builds.

### 8. License

The SDK is license-gated. Send your app's package name (Android) **and** bundle identifier (iOS) to **info@yt.uz** for approval. Unregistered apps automatically see the SDK's built-in blocked screen with an in-app email request form.

## Usage

The plugin's job is to launch the bundled native SDK UI. All key
management, password prompts, NFC waiting screens and HTTP signing
round-trips live inside the native UI — the Flutter side just hands
it a deep link (if any) and listens for new links while the app runs.

### Open the SDK from a button

```dart
import 'package:eimzo_flutter/eimzo_flutter.dart';

class _AppState extends State<App> {
  final _eimzo = EimzoFlutter.instance;

  Future<void> _openSdk() async {
    // Pre-flight license check (Android only; iOS always returns true
    // and runs the check itself inside the native UI).
    final allowed = await _eimzo.init(
      config: const EimzoConfig(isTestMode: false),
    );
    if (!allowed) return; // native SDK is showing its blocked screen

    // Present the full native UI (Home + Cards + Sign flow).
    // User taps IMZOLASH inside → scans QR → confirms → signs.
    await _eimzo.openSignUi();
  }

  @override
  Widget build(BuildContext context) => ElevatedButton(
        onPressed: _openSdk,
        child: const Text('Open E-IMZO'),
      );
}
```

### Open with an external deeplink (sign flow auto-starts)

When another app or website sends an `eimzo://sign?qc=...` URL, route
it straight into the native sign flow. The native UI skips the
confirmation dialog for external deeplinks — the host that issued the
URL has already vetted it — and goes directly to the password prompt
(or auto-signs if the user previously saved their password).

```dart
class _AppState extends State<App> {
  final _eimzo = EimzoFlutter.instance;

  @override
  void initState() {
    super.initState();
    _captureDeeplinks();
  }

  Future<void> _captureDeeplinks() async {
    // Cold-start: app was launched by tapping an eimzo:// URL.
    final initial = await _eimzo.getInitialDeeplink();
    if (initial != null) _openSign(initial);

    // Warm: user came back to a running app via a new eimzo:// URL.
    _eimzo.onNewDeeplink().listen(_openSign);
  }

  Future<void> _openSign(String link) async {
    final allowed = await _eimzo.init();
    if (!allowed) return;
    await _eimzo.openSignUi(deepLink: link);
  }
}
```

### Test mode

Pass `isTestMode: true` to talk to `m.test.e-imzo.uz` instead of the
production endpoint. QRs generated against the test stand only work in
test mode (and vice versa).

```dart
await _eimzo.init(config: const EimzoConfig(isTestMode: true));
```

## API

- **`EimzoFlutter.instance.init({EimzoConfig config})`** → `Future<bool>`
  Runs the SDK's license check. Returns `true` if the app is
  registered, `false` if the native SDK is now showing its blocked
  screen. iOS always returns `true`; the actual check runs inside
  `openSignUi` and surfaces as a BlockedView if denied.

- **`EimzoFlutter.instance.openSignUi({String? deepLink})`** → `Future<void>`
  Presents the full native UI (Home / Cards / sign flow). If `deepLink`
  is provided, jumps straight into signing that document. Returns when
  the UI is presented — subscribe to `onNewDeeplink` for re-entries.

- **`EimzoFlutter.instance.getInitialDeeplink()`** → `Future<String?>`
  The `eimzo://sign?...` URL the app was cold-started with. Consume
  once on app launch.

- **`EimzoFlutter.instance.onNewDeeplink()`** → `Stream<String>`
  Broadcast stream of `eimzo://...` URLs delivered while the app is
  already running.

- **`EimzoFlutter.instance.launchDeeplink(String url)`** → `Future<void>`
  Convenience that fires an `eimzo://` URL through the OS — useful in
  dev to test the deeplink path without an external trigger.

`EimzoConfig` accepts `isTestMode` (default `false`), and optional
`productionApiUrl` / `testApiUrl` overrides.

`EimzoException(code, message)` wraps `PlatformException` errors from
the native side.

## License

MIT
