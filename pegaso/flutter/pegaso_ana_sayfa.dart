// Pegaso Destek ana ekranı (1.0.6): "Bağlan" sekmesinde iki kart (Bu bilgisayar / Uzak bilgisayar),
// "Bağlantılarım" sekmesinde RustDesk'in kendi bağlantı sayfası (son bağlantılar, favoriler).
// ConnectionPage IndexedStack'te hep kurulu kalır: pencere kapanma dinleyicisi ve ID denetleyicisi ona bağlı.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hbb/common.dart';
import 'package:flutter_hbb/common/formatter/id_formatter.dart';
import 'package:flutter_hbb/desktop/pages/connection_page.dart';
import 'package:flutter_hbb/desktop/pages/desktop_home_page.dart';
import 'package:flutter_hbb/models/platform_model.dart';
import 'package:flutter_hbb/models/server_model.dart';
import 'package:provider/provider.dart';

const _turuncu = Color(0xFFFF6B00);
const _kart = Color(0xFF222222);
const _alan = Color(0xFF1A1A1A);
const _cerceve = Color(0xFF333333);
const _dugme = Color(0xFF2E2E2E);
const _soluk = Color(0xFFB0B0B0);
const _sifreKaydetAnahtari = 'pegaso-sifre-kaydet';

class PegasoAnaSayfa extends StatefulWidget {
  final Widget ustUyari;
  final Widget yardimKartlari;
  const PegasoAnaSayfa(
      {Key? key, required this.ustUyari, required this.yardimKartlari})
      : super(key: key);

  @override
  State<PegasoAnaSayfa> createState() => _PegasoAnaSayfaState();
}

class _PegasoAnaSayfaState extends State<PegasoAnaSayfa> {
  int _sekme = 0;
  final _uzakId = IDTextEditingController();
  final _uzakSifre = TextEditingController();
  bool _sifreGoster = false;
  bool _sifreKaydet = false;

  @override
  void dispose() {
    _uzakId.dispose();
    _uzakSifre.dispose();
    super.dispose();
  }

  void _baglan() {
    final id = _uzakId.id;
    if (id.isEmpty) return;
    final sifre = _uzakSifre.text;
    bind.mainSetPeerOptionSync(
        id: id, key: _sifreKaydetAnahtari, value: _sifreKaydet ? 'Y' : '');
    connect(context, id, password: sifre.isEmpty ? null : sifre);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Row(children: [
              _sekmeBasligi('Bağlan', 0),
              _sekmeBasligi('Bağlantılarım', 1),
            ]),
          ),
          Expanded(
            child: IndexedStack(
              index: _sekme,
              children: [
                _baglanSekmesi(context),
                ConnectionPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sekmeBasligi(String yazi, int no) {
    final secili = _sekme == no;
    return InkWell(
      onTap: () => setState(() => _sekme = no),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
                color: secili ? _turuncu : Colors.transparent, width: 2),
          ),
        ),
        child: Text(yazi,
            style: TextStyle(
                fontSize: 13,
                fontWeight: secili ? FontWeight.w600 : FontWeight.normal,
                color: secili
                    ? Theme.of(context).textTheme.titleLarge?.color
                    : _soluk)),
      ),
    );
  }

  Widget _baglanSekmesi(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          widget.ustUyari,
          LayoutBuilder(builder: (context, c) {
            final bu = ChangeNotifierProvider.value(
              value: gFFI.serverModel,
              child: Consumer<ServerModel>(
                  builder: (context, model, _) => _buBilgisayar(model)),
            );
            final uzak = _uzakBilgisayar();
            if (c.maxWidth < 700) {
              return Column(children: [bu, const SizedBox(height: 20), uzak]);
            }
            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: bu),
                  const SizedBox(width: 20),
                  Expanded(child: uzak),
                ],
              ),
            );
          }),
          widget.yardimKartlari,
          const SizedBox(height: 12),
          const OnlineStatusWidget(),
        ],
      ),
    );
  }

  Widget _kartKutusu(String baslik, String aciklama, List<Widget> icerik) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
      decoration: BoxDecoration(
          color: _kart, borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(baslik,
              style: const TextStyle(
                  color: _turuncu,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3)),
          const SizedBox(height: 6),
          Text(aciklama,
              style: const TextStyle(color: _soluk, fontSize: 12.5)),
          const SizedBox(height: 18),
          ...icerik,
        ],
      ),
    );
  }

  Widget _etiket(String yazi) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(yazi, style: const TextStyle(color: _soluk, fontSize: 12.5)),
      );

  Widget _ipucu(String yazi) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(yazi, style: const TextStyle(color: _soluk, fontSize: 11.5)),
      );

  Widget _yanDugme(String yazi, VoidCallback? onTap) => SizedBox(
        height: 54,
        child: TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            backgroundColor: _dugme,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6)),
          ),
          child: Text(yazi, style: const TextStyle(fontSize: 12.5)),
        ),
      );

  Widget _degerKutusu(String deger, {double boyut = 24}) => Container(
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _alan,
          border: Border.all(color: _cerceve),
          borderRadius: BorderRadius.circular(6),
        ),
        child: SelectableText(deger,
            style: TextStyle(
                color: Colors.white,
                fontSize: boyut,
                fontWeight: FontWeight.w700,
                letterSpacing: 1)),
      );

  InputDecoration _girisSusu() => InputDecoration(
        filled: true,
        fillColor: _alan,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _cerceve),
            borderRadius: BorderRadius.circular(6)),
        focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: _turuncu),
            borderRadius: BorderRadius.circular(6)),
      );

  Widget _buBilgisayar(ServerModel model) {
    final tekKullanimlik = model.approveMode != 'click' &&
        model.verificationMethod != kUsePermanentPassword;
    final ayarlarAcik = !bind.isDisableSettings();
    return _kartKutusu(
        'BU BİLGİSAYAR', 'Karşı taraf kimliğinizi ve şifrenizi girerek bağlanır.', [
      _etiket('Kimliğiniz'),
      Row(children: [
        Expanded(child: _degerKutusu(model.serverId.text)),
        const SizedBox(width: 8),
        _yanDugme('Kopyala', () {
          Clipboard.setData(ClipboardData(text: model.serverId.text));
          showToast(translate('Copied'));
        }),
      ]),
      _ipucu('Bu kimlik ve şifre ile size bağlanılır.'),
      const SizedBox(height: 16),
      _etiket('Şifre'),
      Row(children: [
        Expanded(child: _degerKutusu(model.serverPasswd.text, boyut: 17)),
        if (tekKullanimlik) const SizedBox(width: 8),
        if (tekKullanimlik)
          _yanDugme('Yenile', () => bind.mainUpdateTemporaryPassword()),
      ]),
      const SizedBox(height: 24),
      if (ayarlarAcik)
        SizedBox(
          height: 36,
          child: TextButton(
            onPressed: () => setPasswordDialog(),
            style: TextButton.styleFrom(
              backgroundColor: _dugme,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('Sabit şifre ata',
                style: TextStyle(fontSize: 12.5)),
          ),
        ),
    ]);
  }

  Widget _uzakBilgisayar() {
    return _kartKutusu('UZAK BİLGİSAYAR', 'Kimliği ve şifreyi girin.', [
      _etiket('Partner kimliği'),
      SizedBox(
        height: 54,
        child: TextField(
          controller: _uzakId,
          inputFormatters: [IDTextInputFormatter()],
          textAlign: TextAlign.center,
          style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: 1),
          decoration: _girisSusu(),
          onSubmitted: (_) => _baglan(),
        ),
      ),
      _ipucu('Boşluksuz da yazabilirsiniz, otomatik 123 456 789 olur.'),
      const SizedBox(height: 16),
      _etiket('Şifre'),
      Row(children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: TextField(
              controller: _uzakSifre,
              obscureText: !_sifreGoster,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: _girisSusu(),
              onSubmitted: (_) => _baglan(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        _yanDugme(_sifreGoster ? 'Gizle' : 'Göster',
            () => setState(() => _sifreGoster = !_sifreGoster)),
      ]),
      const SizedBox(height: 8),
      InkWell(
        onTap: () => setState(() => _sifreKaydet = !_sifreKaydet),
        child: Row(children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: _sifreKaydet,
              activeColor: _turuncu,
              onChanged: (v) => setState(() => _sifreKaydet = v ?? false),
            ),
          ),
          const SizedBox(width: 6),
          const Text('Şifreyi kaydet',
              style: TextStyle(color: _soluk, fontSize: 12.5)),
        ]),
      ),
      const SizedBox(height: 14),
      SizedBox(
        height: 36,
        child: TextButton(
          onPressed: _baglan,
          style: TextButton.styleFrom(
            backgroundColor: _turuncu,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
          ),
          child: const Text('Bağlan',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        ),
      ),
    ]);
  }
}
