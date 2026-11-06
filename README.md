# eimzo_flutter

Thin Flutter plugin that bootstraps the official [E-IMZO Mobile SDK](https://github.com/peachdev-uz/eimzo-mobile-sdk) (`eimzo-sdk-2.3.0` bundled inside) on the host activity. All signing and key management lives in the native UI; the Flutter side initializes it and opens it — with a sign request the app makes itself, or without one.

Every app signs through the YT gateway and has to be registered with YT
first — see [Registration](#8-registration).

## Platform support

| Android | iOS |
|---------|-----|
| ✅ (minSdk 24) | ✅ (iOS 16+) |

## Setup

### 1. Add the dependency

```yaml
dependencies:
  eimzo_flutter: ^2.3.0
```

Coming from 2.2? See [Upgrading from 2.2](#upgrading-from-22).

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
2.2.

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

### 8. Registration

The SDK reaches E-IMZO only through the YT gateway, and the gateway lets in
the apps YT has registered. It recognises an app by the platform's
attestation, so there is no licence file to ship:

- **Android** — key attestation proves the package name and the signing
  certificate.
- **iOS** — App Attest proves the bundle id and the Team ID.

Email **info@yt.uz** with, for each platform you ship:

- **Android** — the package name and the SHA-256 of the certificate the app
  is signed with:

  ```
  apksigner verify --print-certs app-release.apk | grep -i "SHA-256"
  ```

  A debug build signed with another certificate needs its own SHA-256. If
  Google Play signs your app (Play App Signing), the copies installed from
  Play carry Google's app signing certificate: send its SHA-256, from Play
  Console, as well.

- **iOS** — the bundle id and your Team ID:

  ```
  codesign -dvvv YourApp.app 2>&1 | grep TeamIdentifier
  ```

Say which [environment](#environment) each is for: `dev` while you test,
`prod` for release. The two are registered separately. An app that is not
registered for its environment gets the SDK's blocked screen.

**Test on real phones.** In production an Android phone needs hardware-backed
key attestation and a locked bootloader with an unmodified system, as
Google-certified phones have; rooted or unlocked phones and Huawei phones
without Google services get the blocked screen. On iOS, App Attest needs a
real iPhone or iPad: the iOS Simulator cannot attest.

#### Apps that already ship a licence

An app with an `EIMZO1.…` licence from 2.0–2.2 opens its gateway session
with the licence instead of attestation. The SDK still checks the licence on
the phone, and the gateway must have it on record — otherwise the blocked
screen. The SDK no longer downloads the list of revoked licences: the gateway
refuses a revoked, unknown or expired licence.

**Write to info@yt.uz before upgrading such an app, and keep 2.2 until YT
confirms.**

The licence is supplied as before, from Dart:

```dart
final token = await rootBundle.loadString('assets/eimzo-license.txt');
await EimzoFlutter.instance.init(config: EimzoConfig(license: token));
```

or as an `eimzo-license.txt` file: in `android/app/src/main/assets/` on
Android; on iOS in the Runner target, checked under *Build Phases → Copy
Bundle Resources* (Xcode can show a file in the navigator without copying it
into the bundle). If the SDK finds no licence, that is no longer an error in
itself: the app is attested like any other, and blocked unless it is
registered.

## Upgrading from 2.2

`^2.2.1` resolves to 2.3.0 on the next `flutter pub upgrade`, so pin
`eimzo_flutter: 2.2.1` until the app is registered. An app that ships a
licence: write to **info@yt.uz** first and keep 2.2 until YT confirms — see
[Apps that already ship a licence](#apps-that-already-ship-a-licence).

1. Register the app for each environment it uses — see
   [Registration](#8-registration).
2. Remove the `eimzo` intent-filter from `AndroidManifest.xml` and the `eimzo`
   entry from `CFBundleURLTypes` in `Info.plist`.
3. Make each sign request in the app with `EimzoSignLink.create` and pass it
   to `openSignUi(deepLink:)`, in place of `getInitialDeeplink()`,
   `onNewDeeplink()` and `launchDeeplink()` — see
   [Open with a sign request](#open-with-a-sign-request-made-in-your-app).
4. Replace `isTestMode` with `environment` (`EimzoEnvironment.dev` or
   `EimzoEnvironment.prod`).
5. iOS: declare **Crash Data** and **Other Diagnostic Data** in App Store
   Connect → App Privacy — see [Error and crash reports](#error-and-crash-reports).

## Usage

The plugin's job is to launch the bundled native SDK UI. All key
management, password prompts, NFC waiting screens and HTTP signing
round-trips live inside the native UI — the Flutter side just opens it,
with a sign request the app made or without one.

### Open the SDK from a button

```dart
import 'package:eimzo_flutter/eimzo_flutter.dart';

class _AppState extends State<App> {
  final _eimzo = EimzoFlutter.instance;

  Future<void> _openSdk() async {
    // Applies the config. Android also checks the app with the gateway
    // here; iOS returns true and checks when the UI opens.
    final allowed = await _eimzo.init(
      config: const EimzoConfig(environment: EimzoEnvironment.prod),
    );
    if (!allowed) return; // native SDK is showing its blocked screen

    // Present the full native UI (Home + Keys + Sign flow).
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
  final allowed = await EimzoFlutter.instance.init(
    config: const EimzoConfig(environment: EimzoEnvironment.prod), // the same config every time
  );
  if (!allowed) return;
  await EimzoFlutter.instance.openSignUi(deepLink: link);
}
```

`EimzoSignLink.create` adds the CRC32 the SDK checks and throws an
`ArgumentError` when a value is not in that form. The UI then shows what
is about to be signed — the site, the hash and the key — and signs only when
the user taps IMZOLASH there. After signing, the SDK shows «Ilovaga qaytish»
(*Return to the app*) and goes back to your app by itself after about 3
seconds. With no key yet, the request waits on the home screen and opens as
soon as the first key is added. There is no timer on the phone: if the
site's request has expired, the server says so and the SDK shows it.

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
2.3 have no mark and sign in either.

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

### YT gateway

Every app signs through the YT gateway; `environment` decides which one, and
there is nothing else to set for it. The gateway lets in a registered app
(see [Registration](#8-registration)) on the phone's attestation: key
attestation on Android, App Attest on iOS. An app that ships a licence opens
its session with the licence instead.

A refused app or phone gets the SDK's blocked screen, whose details tell the
developer why. No connection is not a refusal: the SDK says so when it needs
the network.

### Error and crash reports

The SDK sends its errors and crashes to the YT gateway, so YT sees what goes
wrong on real phones. It is always on, for every app, with a licence or
without.

- **Sent:** the action (adding a key, signing, scanning a QR, deleting a key),
  an error code, the message the user was shown, the kind of key, the SDK and
  OS versions, the device model, and for a crash its stack.
- **Never sent:** names, PINFL/STIR, certificate serials, passwords, PINs, QR
  codes, documents or their hashes. Messages and stacks are scrubbed of such
  values before they leave the phone.

A crash is sent on the next start; your own crash reporter still gets it.

**iOS — App Store privacy.** In App Store Connect → App Privacy, declare
**Crash Data** and **Other Diagnostic Data**: not linked to the user, not
used for tracking, purpose *App Functionality*. The iOS SDK's privacy
manifest (`PrivacyInfo.xcprivacy`) declares the same.

The gateway counts signatures per app and per kind of key (PFX file, QR code,
ID card, USB token, BAIK token). It never stores what was signed or by whom.

## API

- **`EimzoFlutter.instance.init({EimzoConfig config})`** → `Future<bool>`
  Applies the configuration. Call it before `openSignUi`, with the same
  config every time: iOS uses the last one it was given, Android keeps the
  one the SDK started with.
  - **Android** checks the app here: the SDK's device checks (root, hooking
    tools, an attached debugger), the licence if the app ships one, and the
    gateway session, opened by key attestation or with the licence. Returns
    `true` when the app may sign, `false` when the app or the phone was
    refused — the SDK has then opened its blocked screen over your app, and
    closing it comes back to your app. No connection is not a refusal:
    `init` returns `true`, and the SDK says so when it needs the network.
  - **iOS** stores the config and returns `true`. The same checks — the
    licence if there is one, then the gateway session by App Attest or with
    the licence — run each time `openSignUi` presents the UI, and a refusal
    shows the blocked screen there.

- **`EimzoFlutter.instance.openSignUi({String? deepLink})`** → `Future<void>`
  Presents the full native UI (Home / Keys / sign flow). `deepLink` is a
  sign request made with `EimzoSignLink.create`; the UI shows it, signs
  when the user taps IMZOLASH and then goes back to your app. Returns when
  the UI is presented — it does not wait for the signature.

- **`EimzoSignLink.create({siteId, documentId, hash})`** → `String`
  Makes the `eimzo://sign?qc=…` link for `openSignUi` from a document's
  values, with the CRC32 the SDK checks. Throws `ArgumentError` on a value
  out of form.

**Removed in 2.3:** `getInitialDeeplink()`, `onNewDeeplink()` and
`launchDeeplink()`. The plugin no longer takes `eimzo://` links from
outside; the app makes the request with `EimzoSignLink.create`.

`EimzoConfig`:

- `environment` — `EimzoEnvironment.prod` (the default) or
  `EimzoEnvironment.dev`; see [Environment](#environment).
- `debugLogging` — the SDK's steps to the console, never keys, PINs or
  signatures. Off by default.
- `license` — the `EIMZO1.…` token, only for an app that already ships one;
  see [Apps that already ship a licence](#apps-that-already-ship-a-licence).
- `isTestMode` — the 2.2 flag. It still works (`true` is `dev`) and is
  deprecated.
- `productionApiUrl` / `testApiUrl` — still accepted, so 2.2 code builds,
  but they have no effect: every call goes through the gateway, which knows
  E-IMZO's address.

> Before 2.1.2 the iOS side discarded this config entirely: `init` ignored
> its arguments and the UI opened with defaults. If you are on an earlier
> version, `isTestMode` and `license` never reached the iOS SDK.

`EimzoException(code, message)` wraps `PlatformException` errors from
the native side.

## Licence

The plugin code in this package is MIT — see `LICENSE`.

The bundled E-IMZO Mobile SDK binaries (`android/libs/eimzo-sdk-*.jar`, the
iOS `EimzoSDK.xcframework`) are **proprietary** to "Yangi texnologiyalar"
and are not covered by MIT. To use them, register your app with YT at
**info@yt.uz** — see [Registration](#8-registration) above.
