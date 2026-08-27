## 2.1.2

**Tuzatish: `EimzoConfig` iOS'da e'tiborsiz qolardi.**

iOS plagini `init` ga berilgan konfiguratsiyani o'qimasdan tashlab yuborardi,
`openSignUi` esa SDK ekranini standart sozlamalar bilan ochardi. Ya'ni
`isTestMode`, API manzillari va litsenziya — hech biri iOS SDK'siga
yetmasdi. Android tomonda ham litsenziya UI ochilishi bilan o'chib ketardi.

**Yangi: litsenziyani Dart'dan berish mumkin.**

`EimzoConfig(license: ...)` qo'shildi. Bu iOS'dagi eng ko'p uchraydigan
muammoni chetlab o'tadi: fayl Xcode'da Runner maqsadining *Copy Bundle
Resources* bosqichida bo'lishi kerak, buni o'tkazib yuborish oson va natija
sezdirmay "Litsenziya topilmadi" bo'ladi.

```dart
final token = await rootBundle.loadString('assets/eimzo-license.txt');
await EimzoFlutter.instance.init(config: EimzoConfig(license: token));
```

Fayl usuli ham ishlayveradi — bu qo'shimcha yo'l, almashtirish emas.

**Yaxshilandi: "Litsenziya topilmadi" endi nima qilish kerakligini aytadi.**

Xabar bundle ichida `eimzo` nomli fayl bor-yo'qligini tekshiradi va shunga
qarab javob beradi. Ilgari u faqat "litsenziya oling" derdi — vaholanki
odatda litsenziya bor, faqat bundle'ga tushmagan.

Yo'l-yo'lakay: iOS sozlamalar ekrani `Versiya 2.0.0` ko'rsatib turgan edi.

## 2.1.1

**Tuzatish: kalitsiz imzolashda kalit qo'sha olmaslik.**

Deeplink bilan kirgan, kaliti yo'q foydalanuvchi "Kalitlarim" ekranida
tiqilib qolishi mumkin edi: bo'sh ro'yxat va boshqa hech nima. Kalit ham
qo'sha olmasdi, imzolay ham olmasdi.

Bosh ekrandagi "Kalit qo'shish" kartasining butun foni bosiladigan edi va
kalitlar ekraniga o'tkazardi; u yerda esa ro'yxat bo'sh bo'lsa qo'shish
qatori umuman chiqmasdi. Endi fon bosilmaydi va qo'shish qatori har doim
turadi — oxirgi kalitni o'chirgan holatda ham.

**Tuzatish: litsenziya tekshiruvi paytida ortga qaytilsa ilova qulardi.**

Tekshiruv asinxron, javob esa activity tirikmi-yo'qmi ko'rmasdan qaytarilardi.
Foydalanuvchi shu orada ekrandan chiqsa, `NullPointerException` bilan krash
bo'lardi. Endi yopilayotgan activity'ga javob umuman yetkazilmaydi.

iOS binariga tegilmadi — u 2.1.0 da qoladi.

## 2.1.0

**BUZUVCHI — raqam minor bo'lsa ham.** `signWithUsbToken` olib tashlandi; SDK
endi faqat `openSignUi` orqali ishlatiladi.

Odatda bunday o'zgarish major raqamni talab qiladi. Bu yerda minor tanlandi,
chunki bu metodni chaqirayotgan integrator yo'q. Ammo `^2.0.0` ga bog'langan
loyiha uni `pub upgrade` da avtomatik oladi — agar `signWithUsbToken` ni
ishlatayotgan bo'lsangiz, build shu paytda yiqiladi. Quyidagi migratsiyaga
qarang.

Plaginda endi beshta narsa bor: `init`, `getInitialDeeplink`, `launchDeeplink`,
`openSignUi` va `onNewDeeplink`. Imzolash va kalit qo'shishning barcha yo'llari
native UI ichida — tashqaridan chaqirib bo'lmaydi.

`signWithUsbToken` bilan birga `EimzoSignResult` ham ketdi — u faqat shu metod
uchun edi.

### Nega

Imzolash oqimi litsenziya tekshiruvi, PIN so'rash, sessiya muddati va backend
bilan aloqani o'z ichiga oladi. Uni bo'lak-bo'lak tashqariga chiqarish har bir
integratorga o'sha ketma-ketlikni qayta yig'ish imkonini berardi — va noto'g'ri
yig'ish imkonini ham. Yagona kirish nuqtasi buni yo'q qiladi.

### Migratsiya

`signWithUsbToken` ni chaqirayotgan bo'lsangiz, o'rniga:

```dart
await EimzoFlutter.instance.openSignUi(deepLink: link);
```

USB token endi UI ichida "USB token orqali" yo'li bilan qo'shiladi va
odatdagidek imzolanadi. Boshqa hech narsa o'zgarmagan — `init` va `openSignUi`
imzolari ham, litsenziya ham, sozlamalar ham o'sha-o'sha.

### Native SDK'lar

Android va iOS SDK'larining ommaviy yuzasi ham shunga mos qisqartirildi.
Android'da tashqarida `EImzoActivity`, `EImzoConfig` va
`EImzoSDK.checkLicenseAndInit` qoldi; iOS'da `EImzoView`, `EImzoConfig` va
`SignResult` — UI'dan tashqari 141 ta ommaviy e'lon o'rniga uchtasi.

## 2.0.2

**Bosh ekrandan qayta dizayndan qolgan tugmalar olib tashlandi.**

TEZ IMZO ostida eski interfeysning uchta bo'lagi turardi: "USB TOKENNI ULANG"
tugmasi, "Kalit qo'shish" ajratgichi va "ERI qo'shish" qatori. Kalit qo'shish
kartasi va TEZ IMZO ularning o'rnini bosgan edi, ya'ni ekranda bir xil narsa
ikki marta ko'rinardi. Endi ekran TEZ IMZO da tugaydi.

**E'tibor bering:** USB tokendan to'g'ridan-to'g'ri, hech nima saqlamasdan
imzolash tugmasi kalit saqlagan foydalanuvchilarga ham ko'rinardi. U endi
yo'q — token "USB token orqali" yo'li bilan kalit sifatida qo'shiladi va
odatdagidek imzolanadi. `signWithUsbToken` API'si o'zgarmagan, ya'ni o'z
interfeysingizdan chaqirsangiz ishlayveradi.

iOS tomoniga tegilmadi.

## 2.0.1

**Android tuzatish: sozlamalar ekrani ochilmasdi.**

2.0.0 da SDK ichidagi to'rtta ekran — sozlamalar, til, mavzu va imzo
natijasi — release build'da `ClassNotFoundException` bilan yiqilardi.

Sabab: kutubxonaning o'zi R8 bilan qisqartirilardi. Bu ekranlar faqat
navigatsiya grafidan, `android:name` orqali chaqiriladi, kutubxona uchun AAPT
yozadigan keep qoidalari esa navigatsiya grafini qamrab olmaydi — u faqat
manifest komponentlarini va layout'dagi custom view'larni ko'radi. Natijada R8
ular chaqirilmaydi deb hisoblab, AAR'dan butunlay olib tashlagan.

Endi kutubxona o'zini qisqartirmaydi. Ilovangizning R8'i esa bu ekranlarni
to'g'ri saqlaydi — ilova darajasida AAPT nav-graf fragmentlari uchun keep
qoidasini o'zi yozadi, ya'ni sizdan qo'shimcha ProGuard sozlamasi talab
qilinmaydi.

iOS tomoniga tegilmadi — u SwiftUI'da, navigatsiya grafi yo'q.

### Yangilash

`eimzo_flutter: ^2.0.1`. Litsenziya, API va sozlamalar o'zgarmagan.

## 2.0.0

**BUZUVCHI: litsenziya endi majburiy.**

Plagin E-IMZO SDK 2.0.0 ga o'tdi. SDK endi faqat imzolangan oflayn litsenziya
bilan ishlaydi — Firestore ro'yxatidan tekshirish olib tashlandi, va orqada
tushadigan zaxira yo'l yo'q. Litsenziyasiz ilova bloklanadi.

### Migratsiya

1. `info@yt.uz` ga yozing va ikkinchi omilni yuboring:
   - **iOS** — Team ID (`codesign -dvvv MyApp.app 2>&1 | grep TeamIdentifier`)
   - **Android** — release APK imzo sertifikati SHA-256
     (`apksigner verify --print-certs app-release.apk | grep -i "SHA-256"`)
2. Kelgan `eimzo-license.txt` faylini qo'ying:
   - iOS: ilova bundle'iga resurs sifatida
   - Android: `android/app/src/main/assets/`
3. `eimzo_flutter: ^2.0.0` ga yangilang.

Litsenziya paket nomingizga **va** imzo identifikatoringizga bog'lanadi, ya'ni
boshqa ilovada ishlamaydi.

### Nega

Tekshiruv `firestore.googleapis.com` javob berishini talab qilardi — u yerdagi
uzilish barcha integratorlarni to'xtatardi. Binardagi API kalitni ajratib
olgan kishi qaysi paketlar ro'yxatda ekanini zondlab ko'ra olardi. Va paket
nomi — chaqiruvchi tanlaydigan satr; uni tuzatadigan ikkinchi omil endi
litsenziyaning ichida, yopiq kalitsiz o'zgartirib bo'lmaydi.

### Boshqa o'zgarishlar

- Native SDK: Android 1.2.10 → 2.0.0, iOS 1.1.7 → 2.0.0.
- Yangi dizayn tizimi: qorong'i rejim, uch til (uz/ru/en), Montserrat,
  tanlanadigan oboylar, qayta ishlangan 11 ta ekran.
- USB-token endi kalit sifatida saqlanadi (ilgari faqat imzolash uchun edi).
- Android: `uses-feature android:required="false"` qo'shildi — usiz Google
  Play ilovangizni USB host'i yo'q qurilmalardan filtrlab tashlardi.
- Android: R8 qoidalariga BouncyCastle qo'shildi. Usiz release build'da
  litsenziya tekshiruvchisi olib tashlanib, ilova bloklanardi.
- "Ruxsat so'rash" formasi olib tashlandi — o'rniga `info@yt.uz`.

## 1.2.3

🍎 **iOS: Swift Package Manager qo'llab-quvvatlashi** + 🤖 **Android native SDK fix**.

* **iOS — SPM qo'shildi.** Endi plagin `podspec` yonida `Package.swift`
  ham tashiydi. SPM yoqilgan ilovalar (`flutter config
  --enable-swift-package-manager`) `eimzo_flutter`'ni "qo'llab-quvvatlanmaydi"
  deb ogohlantirmaydi. CocoaPods fallback sifatida saqlanadi — ikkala yo'l
  ham bir xil Swift manbasini kompilyatsiya qiladi. `EimzoSDK` va `Pfx2qr`
  xcframework'lari SPM'da remote `.binaryTarget(url:checksum:)` orqali (podspec
  ishlatadigan o'sha GitHub release'dan) yuklanadi. Real qurilmada tasdiqlandi.
* **Android SDK `1.2.9 → 1.2.10`.** Kalit qo'shishda yuzaga keladigan Room
  null-krash tuzatildi. Boshqa o'zgarish yo'q — bundled aux jarlar
  (FEITIAN/applet/pfx2qr), native `.so` lar, resurslar va manifest o'sha-o'sha.

## 1.2.2

🔄 **Native SDK yangilandi** — test muhitining API manzili o'zgardi.

* **Android SDK `1.2.8 → 1.2.9`** va **iOS SDK `1.1.6 → 1.1.7`**.
* Test muhitining RPC manzili `https://m.test.e-imzo.uz/api/rpc` dan
  `https://test.e-imzo.uz/api/rpc` ga ko'chirildi (`m.` subdomeni olib
  tashlandi). Production manzili o'zgarmadi (`https://m.e-imzo.uz/api/rpc`).
* Boshqa o'zgarish yo'q — imzolash oqimlari, bundled aux jarlar
  (FEITIAN/applet/pfx2qr) va native `.so` lar o'sha-o'sha.

## 1.2.1

🔌 **USB token signing fixed** — verified end-to-end on a physical
FEITIAN JavaCard Token V1.0.

* **Bundled the missing native-SDK dependency jars.** 1.2.0 shipped
  only the core SDK classes; the FEITIAN FTReader, ID-card applet and
  pfx2qr jars were absent, so USB-token signing crashed with
  `NoClassDefFoundError: com.ftsafe...FTException`. The plugin now
  bundles all four jars.
* Updated bundled SDK to **1.2.8**, which fixes the FEITIAN 2.0.1.7
  USB flow: permission-request race, automatic `readerFind()` retry
  after the grant, reader addressing by `UsbDevice` name, and direct
  slot-status detection for tokens without an interrupt endpoint.
* Added R8 consumer rules for `com.ftsafe.**` and
  `uz.yt.idcard.applet.**` so release builds keep the JNI-referenced
  reader classes.

## 1.2.0

* 📐 **Android: 16 KB page size muvofiqligi (Android 15+).** Bundled
  native Android SDK bumped `eimzo-sdk 1.2.6 → 1.2.7`. Android 15+ va
  16 KB xotira sahifali qurilmalar native `.so` larning ELF LOAD
  segmentlari 16 KB ga tekislanishini talab qiladi (Google Play SDK 35
  uchun 2025-yil 1-noyabrdan majburiy). Avval qurilma quyidagi
  ogohlantirishni ko'rsatardi:
  ```
  Следующие библиотеки не выровнены по 16 КБ:
    libgojni.so, libFTReaderPCSC_*.so
  ```
  Tuzatishlar:
  * `libgojni.so` (pfx2qr) Go manbasidan 16 KB alignment bilan qayta
    build qilindi.
  * FEITIAN kutubxonasi `1.0.9.6 → 2.0.1.7` ga yangilandi — FEITIAN'ning
    rasmiy 16 KB tekislangan SDK'si. Ikkala lib ham endi 16 KB ELF.
  * `libgojni.so` va `pfx2qr.jar` bundled tartibda saqlanib qoldi.
* ⚠️ **Integratorlar uchun:** to'liq 16 KB muvofiqlik (yakuniy APK ZIP
  alignment) uchun ilovangizda **AGP 8.5.1+** ishlating — eski AGP
  native lib'larni 4 KB ga zipalign qiladi.
* ℹ️ USB token imzolash FEITIAN 2.0.1.7 API'ga o'tdi.

## 1.1.9

* 🔒 **Android: muddati tugagan sertifikat bilan imzolash bloklandi.**
  Bundled native Android SDK bumped `eimzo-sdk 1.2.5 → 1.2.6`.
  - Muddati o'tgan (`validTo` sanasi kelgan) kalit kartochkasida
    qizil **"Muddati tugagan"** badge chiqadi, Home'da IMZOLASH
    tugmasi o'chiriladi va kartochka xira ko'rinadi. "Mening
    kalitlarim" ro'yxatida ham har bir muddati o'tgan kartochka
    belgilanadi.
  - Defence-in-depth: tugma holati o'tib ketsa ham, bosilganda
    "Bu kalit muddati tugagan — imzolab bo'lmaydi" toast chiqadi.
* ✨ **iOS: muddati tugagan sertifikat bloki + kalitni bir bosishda
  tanlash.** Bundled native iOS SDK bumped `EimzoSDK 1.1.5 → 1.1.6`.
  - Muddati o'tgan (`validTo` sanasi kelgan) sertifikat bilan endi
    imzolab bo'lmaydi. Kartochka kulrang ko'rinishga o'tadi, qizil
    **"Muddati tugagan"** badge chiqadi, IMZOLASH tugmasi o'chiriladi.
    SDK-core'da ham guard bor (`SignError.certExpired`) — deeplink,
    QR va auto-sign yo'llari qamralgan.
  - Kalitlar ro'yxatida kartochka ustiga bir marta bosish endi uni
    darhol faol kalit qilib tanlaydi va Home'ga qaytaradi (avval
    uzoq bosib "Default qilish" tanlash kerak edi).

  Dart API o'zgarmagan. Migration: `cd ios && rm -rf Pods Podfile.lock && pod install`

## 1.1.7

* 🐛 **Android: PFX import R8 hot-fix.** Bundled native Android SDK
  bumped `eimzo-sdk 1.2.4 → 1.2.5`. R8 minification yoqilgan
  integrator app'larda PFX kalit qo'shganda quyidagi crash bilan
  to'qnashar edi:
  ```
  F/go/Seq : failed to find method Seq.getRef
  F/libc   : Fatal signal 6 (SIGABRT) in Java_go_Seq_init
  ```
  Sabab: `libgojni.so` JNI orqali `go.Seq.getRef`, `go.Seq.incRef`
  metodlarini nom orqali topadi. Consumer R8 ularni Kotlin koddan
  hech kim chaqirmaganini ko'rib rename/strip qilardi. Plugin
  `consumer-rules.pro` ga `go.**` va `pfx2qr.**` keep qoidalari
  qo'shildi — endi avtomatik shipga ket.

## 1.1.6

* 🛠 **Fix: iOS App Store nested framework rejection.** Bundled native
  iOS SDK bumped `EimzoSDK 1.1.4 → 1.1.5`. Avvalgi versiyalarda
  `Pfx2qr.framework` `EimzoSDK.framework/Frameworks/` ichida embed
  qilingan edi va App Store Connect bunday tuzilmani rad etardi:
  ```
  ITMS-90205  contains disallowed nested bundles
  ITMS-90206  contains disallowed file 'Frameworks'
  ITMS-90035  inner Pfx2qr Mach-O not properly signed
  ```
  Plus `dSYM` yo'qligi haqida warning. Yangi versiyada `Pfx2qr.xcframework`
  alohida sibling sifatida `App.app/Frameworks/` ostiga joylashadi
  va `dSYM` fayllari xcframework ichida ship qilinadi → crash log'lar
  symbolicate bo'ladi.
  `prepare_command` eski nested `EimzoSDK.xcframework`'ni avtomatik
  aniqlab tozalaydi va ikkala xcframework'ni qaytadan yuklab oladi.
  **Migration:** `cd ios && rm -rf Pods Podfile.lock && pod install`
  Dart API o'zgargan emas.

## 1.1.5

* 🚨 **Hot-fix: PFX fayldan import barcha avvalgi versiyalarda buzilgan
  edi.** Bundled native Android SDK bumped `eimzo-sdk 1.2.3 → 1.2.4`.
  Fayl orqali kalit qo'shganda quyidagi crash bilan to'qnashar edi:
  ```
  java.lang.UnsatisfiedLinkError: dlopen failed:
    library "libgojni.so" not found
  ```
  Sabab: `libgojni.so` (PFX parsing uchun native lib) Flutter plugin
  jniLibs ichida yo'q edi. Endi to'g'ridan-to'g'ri bundled
  (4 ABI × ~4.5 MB).
* 📦 APK hajmiga ta'sir: bundled `.so` fayllar tufayli ~18 MB qo'shildi.

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
