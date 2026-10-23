#!/bin/bash
# Pegaso Destek markalaması: RustDesk kaynak ağacının kökünde çalıştırılır.
# Sunucu adresi, sunucu anahtarı ve uygulama adı derlemeye gömülür;
# müşteri hiçbir ayar girmez.
set -euo pipefail

# Alan adı (DNS-only, Cloudflare proxy KAPALI olmalı): sunucu değişirse yalnız DNS güncellenir.
SUNUCU="${PEGASO_SUNUCU:-destek.pegaso.com.tr}"
ANAHTAR="${PEGASO_ANAHTAR:-Am9YfgJQGkUDKNLorEVhWdrFK5isyI1xoVWbdIDC4VU=}"
AD="PegasoDestek"
GORUNEN_AD="Pegaso Destek"
P="$(cd "$(dirname "$0")" && pwd)"

degistir() { # dosya, eski, yeni — eski bulunmazsa derlemeyi durdur
  grep -qF -- "$2" "$1" || { echo "YAMA BULUNAMADI: $1 -> $2"; exit 1; }
  python3 - "$1" "$2" "$3" <<'EOF'
import sys
f, eski, yeni = sys.argv[1:]
s = open(f, encoding='utf-8').read()
open(f, 'w', encoding='utf-8', newline='').write(s.replace(eski, yeni))
EOF
}

C=libs/hbb_common/src/config.rs
degistir $C 'pub const RENDEZVOUS_SERVERS: &[&str] = &["rs-ny.rustdesk.com"];' \
            "pub const RENDEZVOUS_SERVERS: &[&str] = &[\"$SUNUCU\"];"
degistir $C 'pub const RS_PUB_KEY: &str = "OeVuKk5nlHiXp+APNn0Y3pC1Iwpwn44JGqrQCsWqmBw=";' \
            "pub const RS_PUB_KEY: &str = \"$ANAHTAR\";"
degistir $C 'RwLock::new("RustDesk".to_owned());' "RwLock::new(\"$AD\".to_owned());"

degistir flutter/windows/runner/Runner.rc '"ProductName", "RustDesk"' "\"ProductName\", \"$GORUNEN_AD\""
degistir flutter/windows/runner/Runner.rc '"FileDescription", "RustDesk Remote Desktop"' "\"FileDescription\", \"$GORUNEN_AD\""
degistir Cargo.toml 'ProductName = "RustDesk"' "ProductName = \"$GORUNEN_AD\""
degistir Cargo.toml 'FileDescription = "RustDesk Remote Desktop"' "FileDescription = \"$GORUNEN_AD\""
degistir libs/portable/Cargo.toml 'ProductName = "RustDesk"' "ProductName = \"$GORUNEN_AD\""
degistir libs/portable/Cargo.toml 'FileDescription = "RustDesk Remote Desktop"' "FileDescription = \"$GORUNEN_AD\""

cp "$P/assets/icon.ico" res/icon.ico
cp "$P/assets/icon.ico" res/tray-icon.ico
cp "$P/assets/icon.png" res/icon.png
cp "$P/assets/icon.ico" flutter/windows/runner/resources/app_icon.ico
cp "$P/assets/icon.png" flutter/assets/icon.png
cp "$P/assets/logo.png" flutter/assets/logo.png
cp "$P/assets/logo.png" flutter/assets/logo_light.png
cp "$P/assets/logo_dark.png" flutter/assets/logo_dark.png

echo "Pegaso Destek yaması uygulandı: sunucu=$SUNUCU ad=$AD"
