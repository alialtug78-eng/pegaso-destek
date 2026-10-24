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
# Dosya özelliklerinde (Ayrıntılar → Dosya açıklaması) görünen Pegaso sürümü; workflow'un "surum" girdisi.
ACIKLAMA="$GORUNEN_AD${PEGASO_SURUM:+ $PEGASO_SURUM}"
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

# Hesap girişi admin.rustdesk.com'a gidiyordu; girişli istemcide access_token yüzünden bizim hbbs'in
# desteklemediği anahtar değişimini bekleyip "Failed to secure tcp: deadline has elapsed" veriyordu.
# Hesap arayüzü gizlenir, API (rustdesk.com) kapatılır.
degistir $C '    pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' \
            '    pub static ref HARD_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("disable-account".to_owned(), "Y".to_owned())]));'
degistir $C '    pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' \
            '    pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("register-device".to_owned(), "N".to_owned())]));'
# Önceden giriş yapılmış istemcilerde kalan access_token da bağlantıyı kilitlemesin: hbbs'imiz
# (OSS 1.1.16) bu anahtar değişimini hiç yapmıyor, o yüzden bu yol tamamen kapatılır.
degistir src/client.rs '!key.is_empty() && (!token.is_empty() || !switch_code.is_empty())' \
                       'false && !key.is_empty() && (!token.is_empty() || !switch_code.is_empty())'

degistir flutter/windows/runner/Runner.rc '"ProductName", "RustDesk"' "\"ProductName\", \"$GORUNEN_AD\""
degistir flutter/windows/runner/Runner.rc '"FileDescription", "RustDesk Remote Desktop"' "\"FileDescription\", \"$ACIKLAMA\""
degistir Cargo.toml 'ProductName = "RustDesk"' "ProductName = \"$GORUNEN_AD\""
degistir Cargo.toml 'FileDescription = "RustDesk Remote Desktop"' "FileDescription = \"$ACIKLAMA\""
degistir libs/portable/Cargo.toml 'ProductName = "RustDesk"' "ProductName = \"$GORUNEN_AD\""
degistir libs/portable/Cargo.toml 'FileDescription = "RustDesk Remote Desktop"' "FileDescription = \"$ACIKLAMA\""

# Kurulum ("Kur") paketteki exe'yi kendi adıyla (PegasoDestek-qs.exe) kopyalıyor ama kısayolu ve
# Windows hizmetini PegasoDestek.exe'ye bağlıyordu → "eksik kısayol", hizmet başlamıyor.
# Güncelleme kodundaki (update_me) yeniden adlandırma adımı kuruluma da eklenir.
python3 - <<'EOF'
p = 'src/platform/windows.rs'
s = open(p, encoding='utf-8').read()
for eski, yeni in (
    ('md \\"{path}\\"\n{copy_exe}\nreg add {subkey} /f\n',
     'md \\"{path}\\"\n{copy_exe}\n{rename_exe}\nreg add {subkey} /f\n'),
    ('        copy_exe = copy_exe_cmd(&src_exe, &exe, &path)?,\n        import_config = get_import_config(&exe),',
     '        copy_exe = copy_exe_cmd(&src_exe, &exe, &path)?,\n        rename_exe = rename_exe_cmd(&src_exe, &path)?,\n        import_config = get_import_config(&exe),'),
):
    if s.count(eski) != 1:
        raise SystemExit('YAMA BULUNAMADI: install_me rename_exe')
    s = s.replace(eski, yeni)
open(p, 'w', encoding='utf-8', newline='').write(s)
EOF

cp "$P/assets/icon.ico" res/icon.ico
cp "$P/assets/icon.ico" res/tray-icon.ico
cp "$P/assets/icon.png" res/icon.png
cp "$P/assets/icon.ico" flutter/windows/runner/resources/app_icon.ico
cp "$P/assets/icon.png" flutter/assets/icon.png
cp "$P/assets/logo.png" flutter/assets/logo.png
cp "$P/assets/logo.png" flutter/assets/logo_light.png
cp "$P/assets/logo_dark.png" flutter/assets/logo_dark.png

echo "Pegaso Destek yaması uygulandı: sunucu=$SUNUCU ad=$AD"
