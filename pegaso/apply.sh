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
            '    pub static ref BUILTIN_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("register-device".to_owned(), "N".to_owned()), ("hide-powered-by-me".to_owned(), "Y".to_owned())]));'
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

# Arayüz markalaması (1.0.5): Pegaso kırmızısı, rustdesk.com bağlantıları pegaso.com.tr'ye, görünen ad
# "Pegaso Destek". APP_NAME (PegasoDestek) değişmez: hizmet adı, ayar klasörü ve pencere bulma ona bağlı.
# AGPL gereği Hakkında sayfasında RustDesk tabanı ve kaynak kod bağlantısı kalır.
degistir src/lang.rs '                    s = s.replace("RustDesk", &app_name);
                } else {' '                    s = s.replace("RustDesk", "Pegaso Destek");
                } else {'
F=flutter/lib/common.dart
degistir $F 'static const Color accent = Color(0xFF0071FF);' 'static const Color accent = Color(0xFFFF6B00);'
degistir $F 'static const Color accent50 = Color(0x770071FF);' 'static const Color accent50 = Color(0x77FF6B00);'
degistir $F 'static const Color accent80 = Color(0xAA0071FF);' 'static const Color accent80 = Color(0xAAFF6B00);'
degistir $F 'static const Color idColor = Color(0xFF00B6F0);' 'static const Color idColor = Color(0xFFFF6B00);'
degistir $F 'static const Color button = Color(0xFF2C8CFF);' 'static const Color button = Color(0xFFFF6B00);'
degistir $F '  return Color(0xFF2C8CFF);
}' '  return Color(0xFFFF6B00);
}'
degistir $F 'primary: Colors.blue, secondary: accent, background: grayBg),' 'primary: accent, secondary: accent, background: grayBg),'
degistir $F '      primary: Colors.blue,
      secondary: accent,' '      primary: accent,
      secondary: accent,'
degistir $F "launchUrl(Uri.parse('https://rustdesk.com'));" "launchUrl(Uri.parse('https://pegaso.com.tr'));"
degistir flutter/lib/desktop/pages/server_page.dart '            Color(0xff00bfe1),
            Color(0xff0071ff),' '            Color(0xffFF8A3D),
            Color(0xffE05500),'
degistir flutter/lib/desktop/widgets/tabbar_widget.dart '                              "RustDesk",' '                              "Pegaso Destek",'
degistir flutter/lib/desktop/pages/connection_page.dart 'const url = "https://rustdesk.com/pricing";' 'const url = "https://pegaso.com.tr";'
degistir flutter/lib/desktop/pages/install_page.dart "'https://rustdesk.com/privacy.html'" "'https://pegaso.com.tr/sayfa/gizlilik-politikasi'"
S=flutter/lib/desktop/pages/desktop_setting_page.dart
degistir $S "launchUrlString('https://rustdesk.com/privacy.html');" "launchUrlString('https://pegaso.com.tr/sayfa/gizlilik-politikasi');"
degistir $S "launchUrlString('https://rustdesk.com');" "launchUrlString('https://pegaso.com.tr');"
degistir $S "decoration: const BoxDecoration(color: Color(0xFF2c8cff))," "decoration: const BoxDecoration(color: Color(0xFFFF6B00)),"
degistir $S "Text('\${translate('Version')}: \$version')" "Text('\${translate('Version')}: ${PEGASO_SURUM:+$PEGASO_SURUM (çekirdek }\$version${PEGASO_SURUM:+)}')"
degistir $S "'Copyright © \${DateTime.now().toString().substring(0, 4)} Purslane Tech Pte. Ltd.\\n\$license'," \
            "'© \${DateTime.now().toString().substring(0, 4)} Pegaso Güvenlik · pegaso.com.tr\\nDestek: +90 850 259 77 47 · info@pegaso.com.tr\\nAçık kaynak RustDesk tabanlıdır (AGPL-3.0) · Kaynak kod: github.com/alialtug78-eng/pegaso-destek\\n\$license',"
degistir $S "                            translate('Slogan_tip')," "                            'Güvenli uzaktan destek',"

# Yeni ana ekran (1.0.6): kullanıcının verdiği tasarım (ekrangoruntusu/PegasoDestek.png) — koyu tema,
# iki kart, "Bağlan / Bağlantılarım" sekmeleri. Kur kartı, hizmet uyarıları ve durum çubuğu korunur.
cp "$P/flutter/pegaso_ana_sayfa.dart" flutter/lib/desktop/pages/pegaso_ana_sayfa.dart
H=flutter/lib/desktop/pages/desktop_home_page.dart
degistir $H "import '../widgets/button.dart';" "import '../widgets/button.dart';
import 'package:flutter_hbb/desktop/pages/pegaso_ana_sayfa.dart';"
degistir $H '    return _buildBlock(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLeftPane(context),
        if (!isIncomingOnly) const VerticalDivider(width: 1),
        if (!isIncomingOnly) Expanded(child: buildRightPane(context)),
      ],
    ));' '    if (!isIncomingOnly) {
      return _buildBlock(
          child: PegasoAnaSayfa(
              ustUyari: buildPresetPasswordWarning(),
              yardimKartlari: Obx(
                  () => buildHelpCards(stateGlobal.updateUrl.value))));
    }
    return _buildBlock(
        child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        buildLeftPane(context),
        if (!isIncomingOnly) const VerticalDivider(width: 1),
        if (!isIncomingOnly) Expanded(child: buildRightPane(context)),
      ],
    ));'
degistir $H '                  Color.fromARGB(255, 226, 66, 188),
                  Color.fromARGB(255, 244, 114, 124),' '                  Color(0xFFFF8A3D),
                  Color(0xFFE05500),'
# Varsayılan tema koyu; koyu temanın zeminleri tasarımdaki tonlara çekilir.
degistir $C '    pub static ref DEFAULT_LOCAL_SETTINGS: RwLock<HashMap<String, String>> = Default::default();' \
            '    pub static ref DEFAULT_LOCAL_SETTINGS: RwLock<HashMap<String, String>> = RwLock::new(HashMap::from([("theme".to_owned(), "dark".to_owned())]));'
degistir $F 'Color(0xFF18191E)' 'Color(0xFF141414)'
degistir $F 'Color(0xFF24252B)' 'Color(0xFF1E1E1E)'
# "Şifreyi kaydet": ana ekran bağlanmadan önce eş ayarına pegaso-sifre-kaydet=Y yazar; giriş başarılı
# olunca RustDesk'in kendi "remember" yolu şifreyi eş yapılandırmasına kaydeder.
degistir src/client.rs '        self.remember = !config.password.is_empty();' \
                       '        self.remember = !config.password.is_empty()
            || config.options.get("pegaso-sifre-kaydet").map_or(false, |v| v == "Y");'

cp "$P/assets/icon.ico" res/icon.ico
cp "$P/assets/icon.ico" res/tray-icon.ico
cp "$P/assets/icon.png" res/icon.png
cp "$P/assets/icon.ico" flutter/windows/runner/resources/app_icon.ico
cp "$P/assets/icon.png" flutter/assets/icon.png
cp "$P/assets/logo.png" flutter/assets/logo.png
cp "$P/assets/logo.png" flutter/assets/logo_light.png
cp "$P/assets/logo_dark.png" flutter/assets/logo_dark.png

echo "Pegaso Destek yaması uygulandı: sunucu=$SUNUCU ad=$AD"
