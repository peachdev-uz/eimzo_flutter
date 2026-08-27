# eimzo_flutter

Thin Flutter plugin that bootstraps the official [E-IMZO Mobile SDK](https://github.com/peachdev-uz/eimzo-mobile-sdk) (`eimzo-sdk-2.1.2` bundled inside) on the host activity. All signing and key management lives in the native UI; the Flutter side initializes it, opens it, and receives `eimzo://sign?...` deep links.

## Platform support

| Android | iOS |
|---------|-----|
| ✅ (minSdk 24) | ✅ (iOS 16+) |

## Setup

### 1. Add the dependency

```yaml
dependencies:
  eimzo_flutter: ^2.1.2
```

### 2. Android — `android/app/build.gradle`

The bundled native SDK requires **Java 17**, **Kotlin JVM target 17**,
and **core library desugaring** for `java.time` APIs used inside the
crypto layer.

```groovy
android {
    compileSdk 34
    defaultConfig {
        minSdk 24          // EImzoActivity uses APIs from API 24
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

> ⚠️ If you skip desugaring you'll see `NoClassDefFoundError: java/time/...`
> at runtime when the SDK builds PKCS#7 signed attributes.

### 3. Android — `AndroidManifest.xml` (deep-link intent-filter)

Only the `<intent-filter>` is your job. Permissions (`INTERNET`, `NFC`,
`CAMERA`, `READ_EXTERNAL_STORAGE` ≤ API 32) and `<uses-feature>` entries
for NFC / USB host are merged in from the plugin's manifest
automatically — don't re-declare them.

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop">

    <intent-filter>
        <action android:name="android.intent.action.MAIN" />
        <category android:name="android.intent.category.LAUNCHER" />
    </intent-filter>

    <!-- Receive eimzo://sign?qc=... from external apps / scanners -->
    <intent-filter>
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="eimzo" android:host="sign" />
    </intent-filter>
</activity>
```

`android:launchMode="singleTop"` matters — without it Android creates
a fresh activity instance each time an `eimzo://` link arrives and the
Dart side never sees `onNewDeeplink()`.

### 4. Android — theme

Nothing to do. Every SDK activity declares `@style/Theme.Eimzo` in the
plugin's manifest, so the SDK's screens no longer inherit your app's theme
and no longer care what it is.

Earlier versions did inherit it, and a non-Material parent
(`Theme.AppCompat`) made the blocked screen throw on first launch. If you
added a `Theme.MaterialComponents` parent to your `LaunchTheme` /
`NormalTheme` for that reason, it is no longer required — though keeping it
harms nothing.

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

### 8. Licence

Since 2.0 the SDK verifies a **signed offline licence** and refuses to run
without one. There is no registration list and no network call behind it —
the licence travels inside your own app and is checked against a public key
compiled into the SDK.

Email **info@yt.uz** with your package name / bundle id and the second
factor for each platform you ship:

- **Android** — the **release** APK's signing certificate SHA-256:

  ```
  apksigner verify --print-certs app-release.apk | grep -i "SHA-256"
  ```

- **iOS** — your Team ID:

  ```
  codesign -dvvv YourApp.app 2>&1 | grep TeamIdentifier
  ```

You get back an `EIMZO1.…` token. Supply it in whichever way suits you.

**As a file**

- Android: `android/app/src/main/assets/eimzo-license.txt`
- iOS: add `eimzo-license.txt` to the **Runner** target, then check it is in
  *Build Phases → Copy Bundle Resources*. Xcode happily shows a file in the
  navigator without copying it into the bundle, and the app then fails at
  runtime with "Litsenziya topilmadi" — the single most common setup mistake.
  Verify before you ship:

  ```
  unzip -l build/ios/ipa/*.ipa | grep -i eimzo-license
  ```

**From Dart** — 2.1.2 and later, no Xcode work at all:

```dart
final token = await rootBundle.loadString('assets/eimzo-license.txt');
await EimzoFlutter.instance.init(config: EimzoConfig(license: token));
```

The licence is bound to your package name **and** your signing identity, so
it does not work in anyone else's app and does not need to be kept secret.

Debug builds are signed with a different certificate than release ones, so a
release licence will not validate a debug build — ask for a second licence if
you need to test against debug builds.

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
    // Applies the config on both platforms and runs the licence check.
    // Android answers here; iOS returns true and checks inside the UI.
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

When another app or website sends an `eimzo://sign?qc=...` URL, route it
straight into the native sign flow. The UI opens a confirmation screen
showing what is about to be signed and starts a 103-second session; the
user still has to tap IMZOLASH, and can add a key first if they have none.

Earlier versions signed the moment the deeplink arrived. That was removed
in 1.1.4 — hosts were importing a key on the same screen and never got to
see what they were signing.

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

Pass `isTestMode: true` to talk to `https://test.e-imzo.uz/api/rpc`
instead of the production endpoint. QRs generated against the test stand
only work in test mode, and vice versa.

```dart
await _eimzo.init(config: const EimzoConfig(isTestMode: true));
```

## API

- **`EimzoFlutter.instance.init({EimzoConfig config})`** → `Future<bool>`
  Applies the configuration and runs the licence check. Returns `true` if
  the app is licensed, `false` if the native SDK is now showing its blocked
  screen. On iOS it always returns `true` and stores the config — the check
  itself runs inside `openSignUi` and surfaces as a blocked screen there.
  Call it before `openSignUi` on both platforms.

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

`EimzoConfig` accepts `isTestMode` (default `false`), `license` (the
`EIMZO1.…` token — see [Licence](#8-licence)), and optional
`productionApiUrl` / `testApiUrl` overrides.

> Before 2.1.2 the iOS side discarded this config entirely: `init` ignored
> its arguments and the UI opened with defaults. If you are on an earlier
> version, `isTestMode` and `license` never reached the iOS SDK.

`EimzoException(code, message)` wraps `PlatformException` errors from
the native side.

## Licence

The plugin code in this package is MIT — see `LICENSE`.

The bundled E-IMZO Mobile SDK binaries (`android/libs/eimzo-sdk-*.jar`, the
iOS `EimzoSDK.xcframework`) are **proprietary** to "Yangi texnologiyalar"
and are not covered by MIT. Their use is governed by the licence you obtain
from **info@yt.uz** — see [Licence](#8-licence) above.
