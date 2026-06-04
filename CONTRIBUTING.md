# Contributing to eimzo_flutter

Rahmat — hissangizni qo'shmoqchi bo'lganingiz uchun! Bu plugin O'zbekiston
E-IMZO ekosistemini Flutter dunyosiga olib chiqishni maqsad qilgan, va
hamjamiyat yordami uni yanada yaxshi qiladi.

## Qanday yordam berishim mumkin?

### 🐛 Bug topdingizmi?

[Issue oching](https://github.com/peachdev-uz/eimzo_flutter/issues/new) va quyidagilarni qo'shing:

- **Reproduce qilish qadamlari** — tartibli ro'yxat
- **Kutilgan xulq-atvor** vs **Aslida nima bo'ldi**
- **Loglar** — `flutter logs` yoki `adb logcat` chiqishi
- **Versiya** — `flutter --version`, `eimzo_flutter` versiyasi
- **Qurilma** — Android API darajasi yoki iOS versiyasi
- **Bundle ID / Package name** (license bilan bog'liq bo'lsa)

### ✨ Yangi xususiyat taklif qilmoqchimisiz?

Avval [open issuelarni ko'rib chiqing](https://github.com/peachdev-uz/eimzo_flutter/issues) —
balki kimdir allaqachon shu narsani so'ragan. Yo'q bo'lsa, yangi issue oching
va nima va nega kerakligini tushuntiring.

### 📱 Yangi platforma qo'llab-quvvatlash

Hozir plagin **Android** + **iOS**'ni qo'llab-quvvatlaydi. Quyidagi platforma'lar uchun **yordam kerak**:

- [#1 macOS support](https://github.com/peachdev-uz/eimzo_flutter/issues/1)
- [#2 Windows support](https://github.com/peachdev-uz/eimzo_flutter/issues/2)
- [#3 Linux support](https://github.com/peachdev-uz/eimzo_flutter/issues/3)
- [#4 Web support](https://github.com/peachdev-uz/eimzo_flutter/issues/4)

Har bir issue'da tegishli platforma uchun texnik kontekst va boshlash qadamlari
yozilgan. PR'larni mamnuniyat bilan qabul qilamiz.

### 📝 Dokumentatsiyani yaxshilash

- README'da typo / chalkash narsa → PR yuboring
- Yangi misol kod kerak deb hisoblasangiz → PR yuboring
- Til tarjimasi (en/ru) — PR yuboring

## Development environment

### Repo'ni clone qilish

```bash
git clone https://github.com/peachdev-uz/eimzo_flutter
cd eimzo_flutter
flutter pub get
```

### Example'ni ishga tushirish

```bash
cd example
flutter pub get

# Android device/emulator
flutter run

# iOS device
flutter run -d <device-id>
```

### iOS uchun

Birinchi marta `pod install` orqali `EimzoSDK.xcframework` yuklab olinadi
(GitHub Releases'dan, taxminan 6 MB):

```bash
cd example/ios
LANG=en_US.UTF-8 pod install
```

Keyin Xcode'da `example/ios/Runner.xcworkspace`'ni oching va o'z
**Apple Development Team**'ingizni tanlang.

### Android uchun

Hech qanday qo'shimcha qadam kerak emas — `flutter run` to'liq ishlatadi.

## Pull Request qoidalari

1. **Branch nomi** — `feature/...`, `fix/...`, `docs/...` prefix bilan
2. **Commit xabarlari** — qisqa va aniq, ingliz tilida (Conventional Commits ma'qul)
3. **Test qiling** — Android va iOS'da o'zgarish ishlashini tasdiqlang
4. **CHANGELOG.md'ga entry qo'shing** — versiya bumpi sizga emas, lekin "Unreleased" section'ga yozing
5. **PR description'da** — nima o'zgartirilgani va nega kerakligi yoziladi

### Kodga qo'yiladigan talablar

- **Dart** — `dart format` o'tkazing
- **Kotlin** (Android) — Kotlin standart konventsiyalari
- **Swift** (iOS) — SwiftLint qoidalari (4-space indent, `final class`)
- Yangi public API'ga **dokumentatsiya kommentariyasi** qo'shing
- Yangi xususiyat — tegishli **testni** qo'shing (agar imkoniyat bo'lsa)

## Litsenziya

Bu plagin **closed-source SDK** (eimzo-sdk-1.x.aar va EimzoSDK.xcframework)
ni o'rab oladi. Plagin'ning Dart va platform-channel kodi MIT litsenziyasida.
PR yuborganingizda, kod siz egasiligini va MIT ostida tarqatishga roziligingizni
tasdiqlaysiz.

## Bog'lanish

- **GitHub Issues** — bug va xususiyatlar uchun
- **Email** — `info@peachdev.uz` — biznes va license savollari uchun
- **License** uchun bundle ID'ni ro'yxatdan o'tkazish — `info@yt.uz`

Rahmat va xush kelibsiz! 🌸
