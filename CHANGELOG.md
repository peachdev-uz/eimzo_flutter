## 1.0.4

* 📝 Android setup section rewritten: clearer build.gradle requirements
  (Java 17 + desugaring + minSdk 24), explanations of why each piece
  is needed, note on `launchMode="singleTop"` and Material theme
  pitfalls.

## 1.0.3

* 📝 README usage and API sections rewritten — old `init` / `getInitialDeeplink`
  / `onNewDeeplink` snippet was missing the `openSignUi` call that actually
  presents the SDK. New section shows the two real flows: open-from-button
  and open-from-external-deeplink. No code changes.

## 1.0.2

* 🍎 **iOS support added.** The plugin now bundles the closed-source
  `EimzoSDK.xcframework` (downloaded from the public release on `pod install`)
  and exposes the same `openSignUi(deepLink:)` API on iOS. Requires iOS 16+.
* The native iOS UI mirrors the Android SDK 1:1: Home, Cards (key list),
  PFX/QR/NFC import, deep-link auto-sign, in-app QR scan with "Domen va
  hesh kod" confirmation bottom sheet.
* Example app extended with iOS platform (`example/ios/`) — same two
  buttons work on both platforms.
* See README for iOS-specific setup: minimum deployment target, NFC
  entitlement, `Info.plist` permissions, `eimzo://` URL scheme.

## 1.0.1

* Bundled native SDK bumped to `eimzo-sdk-1.0.1`.
* **Fix:** PFX/QR key import crashed with `JsonIOException: Abstract classes can't be instantiated! Class name: uz.eimzo.sdk.network.JsonRpcResponse` after the cert-info HTTP round-trip — R8 was stripping the no-arg constructors of the Gson-deserialized network DTOs. Added explicit `-keep` rules for all `uz.eimzo.sdk.network.*` DTOs (`JsonRpcRequest/Response`, `CertInfoParams/Result`, `SiteInfoParams/Result`, `SendPkcs7Params`, `Pkcs7Result`).
* **Fix:** `ClassNotFoundException: androidx.viewbinding.ViewBinding` at runtime — added explicit `api 'androidx.databinding:viewbinding:8.1.0'` to the plugin's Gradle dependencies.
* **Fix:** `NoClassDefFoundError: pfx2qr.Pfx2qr` during PFX import — bundled `pfx2qr.jar` and the `libgojni.so` native library (all 4 ABIs) directly into the plugin so consumers don't need any extra Maven repo.
* New native bridge method `openSignUi({String? deepLink})` — launches the full native `EImzoActivity` (Home + Keys + AddKey + sign flow). Optional deep-link argument jumps straight into the sign flow.
* Example app simplified to two buttons: "Open E-IMZO native UI" and "Open with deep link (sign flow)".
* Verbose diagnostic logging added to `EImzoSDK.import*` and `EImzoApiClient.rpcCall` (bakes exception class + stack into the log message string so R8 can't drop it).

## 1.0.0

**BREAKING:** Rewritten as a thin wrapper around the official [E-IMZO Mobile SDK](https://github.com/peachdev-uz/eimzo-mobile-sdk). The bundled `eimzo-sdk-1.0.0` native SDK (classes + resources + jniLibs) owns all signing / key-management UI; this plugin just initializes it on the host activity and forwards deep links into Dart.

* New singleton entry point: `EimzoFlutter.instance` (the old static API is gone).
* Three-method API: `init({EimzoConfig})` (runs `EImzoSDK.checkLicenseAndInit`), `getInitialDeeplink()`, `onNewDeeplink()`.
* `EimzoConfig` exposes `isTestMode`, `productionApiUrl`, `testApiUrl`.
* `EimzoException` wraps platform errors.
* Deep-link scheme host changed from `eimzo://open` to `eimzo://sign` (per new SDK).
* Android: dropped `uz.yt.idcard.eimzo:flutter_debug/release` dependency and the `nexus.yt.uz` repository requirement. AAR contents are merged into the plugin (classes, res, jniLibs, manifest) plus transitive deps (kotlinx-coroutines, AndroidX core/appcompat/lifecycle/room, Material, OkHttp, Gson, BouncyCastle, Lottie). Consumers don't need any extra Maven repo.
* AGP `androidResources.additionalParameters '--extra-packages', 'uz.eimzo.sdk'` so the bundled SDK can resolve its R class against the merged resources.
* Removed the separate-Flutter-engine `EimzoFlutterActivity` — deep links are delivered to the host app's MainActivity.
* Licensing: apps must register their package name at `info@yt.uz`. Unregistered apps see the SDK's blocked-app screen automatically.

## 0.2.0

* Android: E-IMZO Flutter modul dependency versiyasi `1.1.3` ga yangilandi (`flutter_debug` va `flutter_release`).

## 0.1.8

* Android: `rootProject.allprojects { repositories }` bloki olib tashlandi — zamonaviy Flutter proyektlardagi `dependencyResolutionManagement` bilan to'qnashib, build xatosiga va `MissingPluginException`ga olib kelardi.
* README: Maven repository qo'shish majburiyligi aniq belgilandi.

## 0.1.7

* README: core library desugaring sozlash bo'limi qo'shildi.

## 0.1.6

* Android: `isCoreLibraryDesugaringEnabled true` — Groovy sintaksisiga o'tkazildi.

## 0.1.5

* Android: `isCoreLibraryDesugaringEnabled = true` `compileOptions` ga qo'shildi — desugaring to'liq yoqildi.

## 0.1.4

* Android: `coreLibraryDesugaring` (`desugar_jdk_libs:2.1.4`) to'g'ri e'lon qilindi.

## 0.1.3

* Android: `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")` dependency qo'shildi — Java 8+ API desugaring qo'llab-quvvatlash uchun.

## 0.1.2

* Android: E-IMZO Flutter modul dependency versiyasi `1.0.0` ga tuzatildi.

## 0.1.1

* Android: E-IMZO Flutter modul dependency versiyasi `1.0.0` ga yangilandi (`flutter_debug` va `flutter_release`).

## 0.1.0

* Initial release.
* Android: E-IMZO Flutter modulini `EimzoFlutterActivity` orqali ishga tushirish.
* `openEImzo({String? deeplink})` — E-IMZO imzolash ekranini ochadi.
* `getInitialLink()` — ilova `eimzo://` orqali ochilgan bo'lsa dastlabki URL ni qaytaradi.
* `linkStream` — ilova ochiq turganida kelgan `eimzo://` deep linklar oqimi.
