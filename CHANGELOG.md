## 1.1.4

* 🎨 **Feature: Android SDK 1.2.3 — UX yaxshilanishlar + NFC bug-fixlar.**
  Bundled native Android SDK bumped `eimzo-sdk 1.2.2 → 1.2.3`.
  * **103-sek deeplink sessiya taymeri.** Tashqi `eimzo://sign?qc=...`
    deeplink kelganida sarlavhada toza taymer ko'rsatiladi
    (`Sessiya: 1:43 qoldi`). Foydalanuvchi kerak bo'lsa kalit qo'shishi
    va keyin imzolashi mumkin — deeplink ushlab turiladi. QR hash
    endi ekranga chiqarilmaydi (foydalanuvchiga ma'nosiz edi).
  * **Orqaga qaytish tugmasi.** Home (deeplink mode), AddKey, Keys
    ekranlarida AppBar back tugmasi.
  * **NFC imzolashda Lottie bottom sheet.** Endi NFC kalit bilan
    imzolashda ham kalit qo'shishdagi kabi 3 ta animatsiya
    (yaqinlashtiring → o'qilmoqda → bajarildi) ko'rsatiladi.
* 🐛 **Tuzatishlar (SDK 1.2.3):**
  * NFC tag tashlanmas muammosi: `dispatchNfcTag` Activity'ning
    pause→resume tsiklida fragment topishni boshqa usulda qiladi.
  * `disableForegroundDispatch` crash try-catch ichida.
  * Sessiya tugaganida app majburan yopilmaydi — taymer faqat
    informatsion.

## 1.1.3

* ✨ **Feature: SDK 1.1.4 — 103-soniyalik deeplink sessiyasi.** Bundled
  native iOS SDK bumped `EimzoSDK 1.1.3 → 1.1.4`. Deeplink orqali
  ochilgan imzo so'rovi endi darhol imzolanmaydi — SDK 103 soniyalik
  sessiya ochadi va foydalanuvchi shu vaqt davomida kalit qo'shishi
  (ID karta / PFX / QR / USB token) yoki mavjudini tanlashi va
  **IMZOLASH** tugmasini bosib imzolashi mumkin. `HomeView` yuqorisida
  live countdown banner ko'rinadi (mm:ss + progress bar, 15 soniya
  qolganda qizilga o'tadi). Vaqt tugasa "Sessiya muddati tugadi"
  overlay chiqadi. **API o'zgarishi yo'q** — Dart tomonida hech narsa
  o'zgarmadi, faqat native side UX o'zgardi.

## 1.1.2

* 🐛 **Fix: SDK 1.1.3 - HomeView orqaga qaytish tugmasi.** Bundled native
  SDK bumped `EimzoSDK 1.1.2 → 1.1.3`. EImzoView sheet sifatida
  ochilganda HomeView'da SDK'ni yopadigan tugma yo'q edi —
  hamburger icon funksiyasiz bor edi. Endi `chevron.backward` orqaga
  tugmasi sheet'ni `@Environment(\.dismiss)` orqali yopadi.

## 1.1.1

* 🐛 **Fix: SDK 1.1.2 module dependency.** Bundled native SDK bumped
  `EimzoSDK 1.1.1 → 1.1.2`. Avvalgi versiyada `Unable to resolve module
  dependency: 'FeitianSDK'` compile xatosi chiqayotgan edi. Endi
  `@_implementationOnly import FeitianSDK` orqali swiftinterface'dan
  yashirildi — consumer loyihalar muammosiz compile qiladi.

## 1.1.0

* 🔑 **iOS: USB token orqali imzolash qo'shildi.** Bundled native SDK
  bumped `EimzoSDK 1.0.4 → 1.1.1`. iOS 16+ ning ichki `CryptoTokenKit`
  orqali Lightning/USB-C portga ulangan CCID tokenlar (Feitian eJava,
  ePass2003, Identiv SCR3xx va boshqalar) endi to'g'ridan-to'g'ri ishlaydi
  — token MFi sertifikatlangan bo'lishi shart emas.
  * `AddKeyView`'da 4-source **"USB Token"** tugmasi.
  * `HomeView` auto-detect — CCID slot ulanganda **"USB Token aniqlandi"**
    banneri.
  * `KeyCard`'da `Token` chip.
  * Server tomonidan PKCS#7 qabul qilinishi tasdiqlangan (`m.e-imzo.uz`).
* 🔒 **Security:** USB token APIsi license-gated. Barcha kirish nuqtalar
  `LicenseEnforcement.ensureAllowed()` orqali o'tadi.
* **Cheklov:** Lightning iPhone'da Apple Lightning-to-USB Camera Adapter
  (yoki MFi-certified ekvivalent) kerak. USB-C iPhone 15+ Pro / iPad'da
  to'g'ridan-to'g'ri USB-C → USB-A kabel ishlaydi.
* Flutter tomonida API o'zgartirish yo'q — mavjud `openEImzoView()` /
  deeplink flow USB tokenlar uchun ham avtomatik ishlaydi.

## 1.0.9

* 🧹 **Android: `EimzoFlutterPlugin.kt` tozalandi.** Foydalanuvchi
  uchun ko'rinmas, lekin loyiha sog'lig'i uchun foydali optimizatsiya:
  * Keraksiz `Handler/Looper` boqimda olib tashlandi — `EImzoSDK`
    callbacklari allaqachon `Dispatchers.Main` da chaqiriladi,
    qo'shimcha `mainHandler.post { }` qatlami foydasiz edi.
  * `requireActivity(result)` helper'i ajratildi — 4 ta handler'da
    takrorlangan `activity ?: result.error("NO_ACTIVITY", ...)`
    patterni bitta funksiyaga yig'ildi.
  * `onDetachedFromEngine` da `eventChannel.setStreamHandler(null)`
    va `eventSink = null` qo'shildi — yengil memory leak xavfini
    yopadi.
  * Kanal nomlari va deep-link sxemasi `companion object` ichida
    konstantalar sifatida ajratildi.
  * Kotlin compile warning'lar: 3 → 0.

## 1.0.8

* 🔌 **Android: USB ulaganda ilova endi avtomatik ochilmaydi.** Avvalgi
  versiyada `USB_DEVICE_ATTACHED` intent-filter qo'shilgan edi —
  natijada FEITIAN token ulanishi bilan OS native UI'ni majburan
  ochib yuborardi. Bu noqulay edi, shuning uchun intent-filter
  va `eimzo_usb_device_filter.xml` olib tashlandi. USB token
  aniqlash hali ham ishlaydi — faqat foydalanuvchi native UI'ga
  o'tganida BroadcastReceiver yoqiladi va tugma faollashadi.
* Bundled native SDK bumped to `eimzo-sdk-1.2.2`.

## 1.0.7

* 🔌 **Android: USB token avtomatik aniqlash.** "USB Token orqali
  imzolash" tugmasi endi faqat FEITIAN / CCID smart-card reader
  telefonga ulanganda faollashadi. SDK `USB_DEVICE_ATTACHED` /
  `DETACHED` broadcastlarini kuzatib, tugmani real vaqtda
  yoqadi / o'chiradi. Ulanmagan paytda tugma matni "USB tokenni
  ulang" ga o'zgaradi.
* 🪪 **Android: device-filter + intent-filter.** FEITIAN VID (0x096E)
  uchun `res/xml/eimzo_usb_device_filter.xml` + `EImzoActivity`
  manifestida `USB_DEVICE_ATTACHED` intent-filter. Token ulanganda
  OS ilovani avtomatik ochishni taklif qiladi va USB ruxsatini
  beradi.
* 🧹 **Android: SDK ommaviy API tozalandi.** Barcha ichki klasslar
  (`UsbTokenManager`, `NfcManager`, `EImzoApiClient`, Room DAO/DB,
  `LicenseGuard`, `QrCryptoManager`, ViewModel'lar, va h.k.)
  `internal` deb belgilandi. Endi consumer'da faqat zarur APIlar
  ko'rinadi. Past darajali `signUsbHash` primitiv olib tashlandi —
  USB sign uchun yagona API `signWithUsbToken(pin, deepLink, callback)`.
* Bundled native SDK bumped to `eimzo-sdk-1.2.1`.

## 1.0.6

* 📚 New `CONTRIBUTING.md` — how to report bugs, suggest features,
  set up the dev environment, and submit PRs. Helps pub.dev's
  "package score" community signals and gives external contributors
  a clear on-ramp.
* 🌐 Opened public GitHub issues calling for help with desktop and
  web platform support: [macOS #1](https://github.com/peachdev-uz/eimzo_flutter/issues/1),
  [Windows #2](https://github.com/peachdev-uz/eimzo_flutter/issues/2),
  [Linux #3](https://github.com/peachdev-uz/eimzo_flutter/issues/3),
  [Web #4](https://github.com/peachdev-uz/eimzo_flutter/issues/4).

## 1.0.5

* 🔐 **Security hardening (both platforms).**
  * **Android:** saved passwords are now AES-256-GCM encrypted with an
    AndroidKeyStore-bound key before being written to Room. Plain SQLite
    reads on rooted devices yield ciphertext only; the key is bound to
    the application UID and is invalidated on `Clear data`. Bundled
    SDK bumped to `eimzo-sdk-1.0.2`.
  * **Android:** the SDK's Room DB and encrypted prefs are now excluded
    from `adb backup` / Google Drive cloud backup via
    `android:fullBackupContent` + `android:dataExtractionRules`. Your
    own app data is untouched — only `eimzo_keys.db` is filtered.
  * **iOS:** `keys.json` written with
    `NSFileProtectionCompleteUntilFirstUserAuthentication`. Pre-first-
    unlock the file is OS-encrypted; backup / jailbreak extraction
    yields opaque ciphertext.

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
