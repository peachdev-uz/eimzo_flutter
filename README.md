# eimzo_flutter

Thin Flutter plugin that bootstraps the official [E-IMZO Mobile SDK](https://github.com/peachdev-uz/eimzo-mobile-sdk) (`eimzo-sdk-2.5.0` bundled inside on Android, `EimzoSDK` 2.5.0 on iOS) on the host activity. All signing and key management lives in the native UI; the Flutter side initializes it and opens it — with a sign request the app makes itself, or without one.

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
  eimzo_flutter: ^2.5.0
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

`^2.2.1` resolves to 2.5.0 on the next `flutter pub upgrade`, so pin
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

### Keys API («Kalitlar API»)

Since 2.4 an integrator YT has registered for it can list the keys the user
has added to the SDK and sign with one of them in the SDK's own sheet,
without opening the full UI:

- `getKeys()` — the keys, as JSON;
- `sign(keyId:, deepLink:)` — signs a sign request with the chosen key.

Both return the native SDK's JSON as a `String`, once, and never throw. The
JSON and the codes are the same as in the Android (`EImzoSDK.getKeys` /
`EImzoSDK.sign`) and iOS (`EImzoAPI`) SDKs.

**The permission** is the integrator's «Kalitlar API». It is off by
default; YT turns it on at the integrator's request once there is a
contract — write to **info@yt.uz**. It covers all of the integrator's apps.
Turned on, it takes effect when the app restarts, or within the hour;
turned off, `sign` stops within a few seconds. Without it both methods
answer `api_not_allowed`; `openSignUi` stays open to every registered app.

**Keys are added in the SDK's UI**, as before: `openSignUi`, by file, QR
code, ID card, USB token or BAIK token. The API lists keys and signs with
them; it does not add any. No method takes a password or returns key
material: the password or PIN is typed only in the SDK's sheet.

Call `init` first, with the usual config. On Android the API works once
`init` has returned `true` in the process; on iOS it runs on the config
`init` stored.

```dart
import 'dart:convert';

final eimzo = EimzoFlutter.instance;
await eimzo.init(config: const EimzoConfig(environment: EimzoEnvironment.prod));

final reply = jsonDecode(await eimzo.getKeys()) as Map<String, dynamic>;
if (reply['status'] != 'ok') return showError(reply['code']); // see the codes below
final keys = (reply['keys'] as List).cast<Map<String, dynamic>>();
```

```json
{"status":"ok","keys":[
  {"id":"7a3f…","pinfl":"31234567890123","name":"ALIYEV VALI ALIYEVICH",
   "type":"pfx","validFrom":"2025-03-01","validTo":"2027-03-01"}
]}
```

| Field | Meaning |
|---|---|
| `id` | The certificate's serial number as the SDK stores it. Opaque: pass it to `sign` unchanged |
| `pinfl` | The holder's PINFL (JShShIR); `null` when the certificate has none |
| `name` | The certificate holder's name |
| `type` | What the key is (since 2.5.0): `pfx` — a key file, added from a file or a QR code; `id_card` — an ID card; `token` — a USB or BAIK token |
| `validFrom`, `validTo` | The certificate's validity, `yyyy-MM-dd` without the time; `null` when the SDK cannot read it |

One holder's ID card, token and key file come as separate entries: their
`id`s differ, `pinfl` and `name` are the same, and `type` tells them apart.
A later version may add a kind: show a value you do not know as a plain key.

Nothing else leaves the SDK: not the STIR, the organization, the key itself
or a saved password. The list has every kind of key
that can sign in the configured `environment`, expired ones too — tell them
by `validTo` — in the SDK's own order, the default key first. A key added in
the other environment is left out. No keys: `{"status":"ok","keys":[]}`.

```dart
// siteId, documentId and hash come from your backend, keyId from getKeys()
Future<void> signDocument(String siteId, String documentId, String hash, String keyId) async {
  final link = EimzoSignLink.create(siteId: siteId, documentId: documentId, hash: hash);
  final reply = jsonDecode(
    await EimzoFlutter.instance.sign(keyId: keyId, deepLink: link),
  ) as Map<String, dynamic>;
  switch (reply['status']) {
    case 'signed':
      await refreshDocument(); // the result is on your backend, from E-IMZO
    case 'cancelled':
      break; // the user closed the sheet
    case 'error':
      showError(reply['code']);
  }
}
```

`sign` checks first, in this order, and answers without opening anything
when a check fails: the permission, the sign request, the key here, the key
not expired, no other `sign` open. Then the SDK opens its sign sheet over
your app:

- the site (from E-IMZO), the hash and the key, which cannot be changed;
- the password for a file or QR key (a saved password works as in the full
  UI), the PIN and a card tap for an ID card, the PIN and the token for a
  USB or BAIK token;
- nothing is signed until the user taps «Imzolash»;
- after a signature, «Imzolandi», which returns to your app by itself after
  3 seconds. Then the call returns.

Any site's request can be signed, as with `openSignUi`; the sheet shows
which site it is. The answer:

- `{"status":"signed"}` — E-IMZO accepted the signature.
- `{"status":"cancelled"}` — the user closed the sheet without signing, also
  after an error they could act on there: a wrong password or PIN, no
  network, the card or token missing.
- `{"status":"error","code":"…","message":"…"}` — a check failed, or the
  flow ended by itself: the gateway refused, the key expired, E-IMZO refused
  the signature, a PIN got blocked.

One `sign` at a time: a second one while the sheet is open gets `busy`. The
future completes once, also when Android recreates your activity meanwhile
(on rotation, say).

The signature goes to E-IMZO through the YT gateway, as every signature
does, and E-IMZO hands the signed document (PKCS#7) to your backend. The app
never gets it: after `signed`, ask your backend for the document's state.

| `code` | When |
|---|---|
| `api_not_allowed` | The integrator has no «Kalitlar API» permission |
| `not_initialized` | Android: `init` has not returned `true` in this process. iOS: `init` has not been called |
| `blocked` | The licence check or the gateway turned the app or the phone away; `message` starts with their code, e.g. `app_blocked`. The blocked screen is not shown |
| `network` | The gateway could not be reached, or did not answer in time |
| `invalid_request` | `deepLink` is not a sign request, or E-IMZO does not know its site |
| `key_not_found` | No key with this `id` can sign in this environment |
| `key_expired` | The key's certificate has expired |
| `busy` | Another `sign` is still open |
| `sign_failed` | E-IMZO refused the signature, or anything else ended the flow. When E-IMZO refused, `message` is its own answer; a blocked card or token PIN is `pin_blocked` |

`message` is for the developer: English, except E-IMZO's own answer, which
may be in Russian or Uzbek. It never holds a key, a password or a hash. Show
users your own text for the `code`.

A failure in the plugin itself comes back in the same shape, not as an
exception: with no Android activity to open the sheet over, `sign` answers
`sign_failed` with the message `no_activity`; any other platform error is
`sign_failed` with that error's message.

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

### Appearance, language and the hash (2.5.0)

The SDK's screens can take your app's look: its colours, font and corners,
light or dark. The quickest way is your own `ThemeData`:

```dart
await EimzoFlutter.instance.init(
  config: EimzoConfig(
    appearance: EimzoAppearance.fromTheme(
      lightTheme,                  // your app's ThemeData
      dark: darkTheme,             // optional
      themeMode: ThemeMode.system, // or the mode your app is in
    ),
    language: EimzoLanguage.ru,    // the SDK's language
    showLanguagePicker: false,     // your app has its own setting
    hashDisplay: EimzoHashDisplay.hidden,
  ),
);
```

Or set the colours yourself — each one optional, a colour left out stays the
SDK's:

```dart
EimzoAppearance(
  light: EimzoPalette(
    primary: Color(0xFF0A6CFF),       // buttons, marks, links
    background: Colors.white,         // the page
    surface: Color(0xFFF2F4F7),       // cards, sheets, rows, PIN keys
    text: Color(0xFF101828),
    textSecondary: Color(0xFF667085), // hints and captions
    divider: Color(0xFFEAECF0),
  ),
  dark: EimzoPalette(primary: Color(0xFF4D94FF)), // null: the SDK's dark colours with your primary
  fontFamily: 'Inter',  // a font your app bundles; null: the SDK's own
  cornerRadius: 12,     // the buttons' radius, 0–28; the rest scale with it
)
```

What `fromTheme` takes:

| SDK | `ThemeData` |
|---|---|
| `primary` | `colorScheme.primary` |
| `background` | `scaffoldBackgroundColor` |
| `surface` | `cardTheme.color`, else `cardColor` (drawn a shade darker if it is the page's colour) |
| `text` | `colorScheme.onSurface` |
| `textSecondary` | `colorScheme.onSurfaceVariant` |
| `divider` | `dividerTheme.color`, else `colorScheme.outlineVariant` (Material 3) or `dividerColor` |
| font | `textTheme.bodyMedium.fontFamily` |
| corners | the filled or elevated button theme's `RoundedRectangleBorder` |

- **The SDK works out the rest** from the six colours: the link colour, the
  label on a filled button (white or black, whichever reads), washes, PIN
  dots. If the text does not read on the background or the cards (under
  4.5:1), it ignores that mode's colours, keeps its own and logs why.
- **The font** has to be one your app bundles in `pubspec.yaml`: the plugin
  finds its files among the app's assets and hands them to the SDK, regular,
  medium and semibold where the family has them. A font `google_fonts`
  downloads at run time cannot be handed over; the SDK then keeps its own
  (the system font on iOS, Montserrat on Android).
- **With an appearance** the SDK also draws no photo behind its home screen,
  and on Android stops offering its own wallpaper and dark-mode choices: the
  look is your app's.
- **Language:** `language` is the language the SDK starts in; the user can
  still change it in the SDK's settings. With `showLanguagePicker: false`
  the choice is gone and the SDK is always in `language` — or, with none,
  the phone's language. Without either the SDK does what it did before.
- **To follow a change** in your app — its theme mode, its language — call
  `init` again with the new config. The next SDK screen takes it.
- **`hashDisplay: EimzoHashDisplay.hidden`** leaves the hash card out of the
  sign screen for a request your app made — `openSignUi(deepLink: …)` and
  the Keys API's `sign`. The user has nothing to compare it with there, and
  your backend gave the hash. A QR code the user scans with the SDK's own
  scanner still shows it: that site shows the same hash, and comparing the
  two protects the user.

**What stays the SDK's**, whatever is set, because it protects the person
signing: the name of the site asking for the signature, the key's holder,
the «Imzolash» button's words and place (its colour is your primary), and
the SDK's own password and PIN entry, which your app never sees. So do the
error, warning and success colours, the key card and the QR scanner.

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
  one the SDK started with — except the appearance, language and hash
  options (2.5.0), which come from the last `init` on both.
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

- **`EimzoFlutter.instance.getKeys()`** → `Future<String>`
  «Kalitlar API» (2.4), for an integrator with the permission: the keys the
  user has added to the SDK, as JSON. Never throws — see
  [Keys API](#keys-api-kalitlar-api).

- **`EimzoFlutter.instance.sign({required String keyId, required String deepLink})`** → `Future<String>`
  «Kalitlar API» (2.4): signs a sign request made with
  `EimzoSignLink.create` with the key `keyId` from `getKeys`, in the SDK's
  own sheet, and returns how it ended as JSON — `signed`, `cancelled` or an
  error. Never throws.

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
- `appearance` — `EimzoAppearance` (2.5.0): colours, font, corners, theme
  mode; null keeps the SDK's design. See
  [Appearance, language and the hash](#appearance-language-and-the-hash-250).
- `language` — `EimzoLanguage.uz`, `.ru` or `.en` (2.5.0); null keeps the
  SDK's own choice, else the phone's.
- `showLanguagePicker` — false hides the SDK's language choice (2.5.0); true
  by default.
- `hashDisplay` — `EimzoHashDisplay.hidden` leaves the hash out of the sign
  screen for the app's own requests (2.5.0); `visible` by default.

> Before 2.1.2 the iOS side discarded this config entirely: `init` ignored
> its arguments and the UI opened with defaults. If you are on an earlier
> version, `isTestMode` and `license` never reached the iOS SDK.

`EimzoException(code, message)` wraps `PlatformException` errors from
the native side for `init` and `openSignUi`. `getKeys` and `sign` never
throw: they answer in their JSON.

## Licence

The plugin code in this package is MIT — see `LICENSE`.

The bundled E-IMZO Mobile SDK binaries (`android/libs/eimzo-sdk-*.jar`, the
iOS `EimzoSDK.xcframework`) are **proprietary** to "Yangi texnologiyalar"
and are not covered by MIT. To use them, register your app with YT at
**info@yt.uz** — see [Registration](#8-registration) above.
