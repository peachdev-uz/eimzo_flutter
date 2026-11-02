#!/usr/bin/env bash
#
# Native SDK'ni AAR'dan plaginga ko'chiradi.
#
# Plagin AAR'ga bog'lanmaydi — uning ichini o'ziga yoyib oladi: klasslar
# android/libs/ ga jar sifatida, resurslar va .so fayllar esa plaginning o'z
# src/main/ iga. Ya'ni SDK'ning har bir chiqarilishida ko'chiriladigan uchta
# narsa bor, va ulardan bittasini unutish oson.
#
# 2.0.2 tayyorlanayotganda aynan shunday bo'ldi: jar yangilandi, res esa eski
# qoldi. Natijada bosh ekranning eski layouti chizilaverar, undagi tugmalarni
# esa yangi kod hech qayerga ulamas edi — ya'ni ekranda ishlamaydigan tugmalar.
# Build ham, testlar ham buni ko'rmaydi, chunki ortiqcha view xato emas.
#
# Ishlatish:
#   tool/sync_sdk.sh ../eimzo-mobile-sdk/maven/uz/eimzo/eimzo-sdk/2.0.2/eimzo-sdk-2.0.2.aar
#   tool/sync_sdk.sh --check <aar>     # ko'chirmaydi, faqat farqni aytadi
#
set -euo pipefail

CHECK=0
if [[ "${1:-}" == "--check" ]]; then CHECK=1; shift; fi

AAR="${1:-}"
if [[ -z "$AAR" || ! -f "$AAR" ]]; then
    echo "Ishlatish: $0 [--check] <eimzo-sdk-X.Y.Z.aar>" >&2
    exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(basename "$AAR" .aar | sed 's/^eimzo-sdk-//')"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

unzip -q "$AAR" -d "$TMP"

drift=0
report() {
    if [[ $CHECK -eq 1 ]]; then
        echo "FARQ: $1"
        drift=1
    else
        echo "  $1"
    fi
}

# 1. Klasslar
JAR="$ROOT/android/libs/eimzo-sdk-$VERSION.jar"
if [[ ! -f "$JAR" ]] || ! cmp -s "$TMP/classes.jar" "$JAR"; then
    report "android/libs/eimzo-sdk-$VERSION.jar"
    if [[ $CHECK -eq 0 ]]; then
        rm -f "$ROOT"/android/libs/eimzo-sdk-*.jar
        cp "$TMP/classes.jar" "$JAR"
    fi
fi

# 2. Resurslar va 3. native kutubxonalar
for pair in "res:android/src/main/res" "jni:android/src/main/jniLibs"; do
    src="$TMP/${pair%%:*}"
    dst="$ROOT/${pair##*:}"
    [[ -d "$src" ]] || continue
    if ! diff -rq "$src" "$dst" >/dev/null 2>&1; then
        report "${pair##*:}"
        if [[ $CHECK -eq 0 ]]; then
            rm -rf "$dst"
            cp -R "$src" "$dst"
        fi
    fi
done

# 4. R8 qoidalari — faqat tekshiriladi. android/consumer-rules.pro AAR'dagi
# proguard.txt'dan qo'lda ko'chiriladi (unda plaginning o'z qoidalari ham
# bor), shuning uchun skript uni yozmaydi: SDK'ning har bir qoida qatori
# plaginda ham bo'lishini talab qiladi. Bu qatorlar yetmasa, ilova debug'da
# ishlaydi, release (R8) build'da esa yiqiladi — 2.3.0-dev.5 gacha Gson
# qoidasi yo'qligidan imzo aynan shunday yiqilardi.
rules_missing=""
if [[ -f "$TMP/proguard.txt" ]]; then
    rule_lines() { grep -vE '^[[:space:]]*(#|$)' "$1" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | sort -u; }
    rules_missing="$(comm -23 <(rule_lines "$TMP/proguard.txt") <(rule_lines "$ROOT/android/consumer-rules.pro"))"
fi
if [[ -n "$rules_missing" ]]; then
    echo "FARQ: android/consumer-rules.pro da SDK'ning R8 qoidalari yo'q (qo'lda qo'shing):" >&2
    echo "$rules_missing" | sed 's/^/    /' >&2
    drift=1
fi

if [[ $CHECK -eq 1 ]]; then
    if [[ $drift -eq 0 ]]; then
        echo "Plagin $VERSION bilan mos."
    else
        echo
        echo "Plagin AAR'dan orqada. Sinxronlash: $0 $AAR" >&2
        exit 1
    fi
elif [[ -n "$rules_missing" ]]; then
    echo "SDK $VERSION ko'chirildi, lekin R8 qoidalari qo'lda qo'shilishi kerak." >&2
    exit 1
else
    echo "SDK $VERSION ko'chirildi."
fi
