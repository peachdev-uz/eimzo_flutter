# eimzo_flutter

Thin Flutter plugin that bootstraps the official [E-IMZO Mobile SDK](https://github.com/peachdev-uz/eimzo-mobile-sdk) (`eimzo-sdk-2.3.0-dev.9` bundled inside) on the host activity. All signing and key management lives in the native UI; the Flutter side initializes it and opens it — with a sign request the app makes itself, or without one.

## Platform support

| Android | iOS |
|---------|-----|
| ✅ (minSdk 24) | ✅ (iOS 16+) |

## Setup

### 1. Add the dependency

```yaml
dependencies:
  eimzo_flutter: ^2.2.1
```

`2.3.0-dev.9` is a pre-release with the [YT gateway](#yt-gateway-23-pre-release).
`^2.2.1` does not pick it up; to try it, pin it exactly:
`eimzo_flutter: 2.3.0-dev.9`.

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

### 3. Android — `AndroidManifest.xml`

Nothing to add. Permissions (`INTERNET`, `ACCESS_NETWORK_STATE`, `NFC`,
`CAMERA`, `READ_EXTERNAL_STORAGE` ≤ API 32), `<uses-feature>` entries for
NFC / USB host and the SDK's activities are merged in from the plugin's
manifest automatically — don't re-declare them.

**Do not declare an `eimzo://` intent-filter.** That scheme is the E-IMZO
app's: an app that claims it opens its SDK for any page or app that sends
one. A sign request is made inside your app — see
[Open with a sign request](#open-with-a-sign-request-made-in-your-app). If
the SDK finds the filter, it logs a warning; remove it when upgrading from
2.3.0-dev.7 or earlier.

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

### 6. iOS — `Info.plist` permissions

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
```

**Do not add `eimzo` to `CFBundleURLTypes`** — the scheme is the E-IMZO
app's (see step 3). The SDK logs a warning when it finds it there.

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
      config: const EimzoConfig(environment: EimzoEnvironment.prod),
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

### Open with a sign request made in your app

Your app does not take `eimzo://` links from outside — that scheme is the
E-IMZO app's. When your own backend has a document for the user to sign,
it gets the site's id, the document's id and the hash from E-IMZO; the app
makes the link from them and opens the SDK with it:

```dart
Future<void> signDocument(String siteId, String documentId, String hash) async {
  final link = EimzoSignLink.create(
    siteId: siteId,          // 4 hex characters
    documentId: documentId,  // 8, 10, 12, 14 or 16 hex characters
    hash: hash,              // 64 hex characters
  );
  final allowed = await EimzoFlutter.instance.init();
  if (!allowed) return;
  await EimzoFlutter.instance.openSignUi(deepLink: link);
}
```

`EimzoSignLink.create` adds the CRC32 the SDK checks and throws an
`ArgumentError` when a value is not in that form. The UI then shows what
is about to be signed — the site, the hash and the key — and signs only when
the user taps IMZOLASH there. With no key yet, the request waits on the home
screen and opens as soon as the first key is added. There is no timer on
the phone: if the site's request has expired, the server says so and the SDK
shows it.

### Environment

`environment` picks which E-IMZO the SDK works with:

- `EimzoEnvironment.prod`, the default: E-IMZO itself, with real keys.
- `EimzoEnvironment.dev`: YT's test environment on `test.e-imzo.uz`, for
  development and QA builds. Only test keys sign there.

A QR code from one environment only works in that environment. Nothing else
needs configuring: the SDK knows each environment's gateway, which every app
goes through.

A key remembers the environment it was added in. In the other one it stays in
the list, marked «Boshqa server», and cannot sign. Keys added before
2.3.0-dev.9 have no mark and sign in either.

```dart
await _eimzo.init(
  config: const EimzoConfig(
    environment: kReleaseMode ? EimzoEnvironment.prod : EimzoEnvironment.dev,
    debugLogging: kDebugMode, // the SDK's steps to the console, never keys or PINs
  ),
);
```

Up to 2.2 this was `isTestMode`. It still works (`true` is `dev`), but it is
deprecated.

### YT gateway (2.3 pre-release)

From 2.3 every app signs through the YT gateway. An app **without** a licence
is known by its package name and signing certificate on Android, and by
bundle id and Team ID on iOS — the same second factors as a licence, but
there is no token to ship. To register, email **info@yt.uz** with them and
say which environment the app is for: `dev` while you test, `prod` for
release.

An app **with** a licence (from 2.3.0-dev.10) opens its gateway session with
the licence instead, so it also works on phones that cannot attest, such as
Huawei phones without Google services. The SDK still checks the licence on
the device first; the gateway then checks that YT has it on record and has
not revoked it. Since 2.3.0-dev.11 the SDK no longer downloads the list of
revoked licences itself: the gateway's answer is the one that counts, from
the moment a licence is revoked. A licence the gateway does not know gets
the blocked screen: ask info@yt.uz to register it.

`environment` decides which gateway the app uses; there is nothing to set
for it. The `prod` gateway **is not live yet**. Until it is, no 2.3
pre-release signs in production, with a licence or without, so keep 2.2 in
production for now.

### Error and crash reports (2.3)

The SDK sends its errors and crashes to the YT gateway, so YT sees what goes
wrong on real phones. It is always on, for every app — since 2.3.0-dev.10 for
an app with a licence too.

- **Sent:** the action (adding a key, signing, scanning a QR, deleting a key),
  an error code, the message the user was shown, the kind of key, the SDK and
  OS versions, the device model, and for a crash its stack.
- **Never sent:** names, PINFL/STIR, certificate serials, passwords, PINs, QR
  codes, documents or their hashes. Messages and stacks are scrubbed of such
  values before they leave the phone.

A crash is sent on the next start; your own crash reporter still gets it.

**iOS — App Store privacy.** In App Store Connect → App Privacy, declare
**Crash Data** and **Other Diagnostic Data**: not linked to the user, not
used for tracking, purpose *App Functionality*.

The gateway counts signatures per app and per kind of key (PFX file, QR code,
ID card, USB token, BAIK token). It never stores what was signed or by whom.

## API

- **`EimzoFlutter.instance.init({EimzoConfig config})`** → `Future<bool>`
  Applies the configuration and runs the licence check. Returns `true` if
  the app is licensed, `false` if the native SDK is now showing its blocked
  screen. On iOS it always returns `true` and stores the config — the check
  itself runs inside `openSignUi` and surfaces as a blocked screen there.
  Call it before `openSignUi` on both platforms.

- **`EimzoFlutter.instance.openSignUi({String? deepLink})`** → `Future<void>`
  Presents the full native UI (Home / Cards / sign flow). `deepLink` is a
  sign request made with `EimzoSignLink.create`; the UI shows it and signs
  when the user taps IMZOLASH. Returns when the UI is presented.

- **`EimzoSignLink.create({siteId, documentId, hash})`** → `String`
  Makes the `eimzo://sign?qc=…` link for `openSignUi` from a document's
  values, with the CRC32 the SDK checks. Throws `ArgumentError` on a value
  out of form.

`getInitialDeeplink()`, `onNewDeeplink()` and `launchDeeplink()` were
removed after 2.3.0-dev.7: the plugin no longer listens for `eimzo://` links.

`EimzoConfig` accepts `environment` (default `EimzoEnvironment.prod`, see
[Environment](#environment)), `license` (the `EIMZO1.…` token — see
[Licence](#8-licence)), optional `productionApiUrl` / `testApiUrl` overrides
and, since 2.3, `debugLogging`. The 2.2 `isTestMode` still works and is
deprecated.

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
