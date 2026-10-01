# Hat fabrikası (deneme, 2026-10-01)

Oyun denemesi: fabrika içinde bant çekmek angarya, oyunun tarzına uymuyor. Sebep ölçek çatışması:
haritada kafa makro lojistikte (kasaba, kömür, yol, kamyon); fabrikaya girince port yönü, R, splitter gibi
mikro tesisata düşülüyor ve oyunun akışı bozuluyor. Bantlar, haritadaki taşıma bulmacasını küçük ölçekte
tekrarlıyor.

**Karar: fabrika içi (bantlı iç sahne) kalkıyor.** Fabrika kararları haritadaki kararlarla aynı ölçekte olmalı:

| Haritada | Fabrikada |
|---|---|
| Kaç kamyon? | Kaç üretim hattı? |
| Hangi kasabaya satayım? | Çeliği satayım mı, parçaya mı çevireyim? |
| Yeni yol yapayım mı? | Yuva açayım mı, yeni fabrika mı kurayım? |

## Deneme: haritada büyüyen fabrika yerleşkesi

İlk deneme kartlı bir panel ekranıydı; "web sitesi gibi, oyun gibi değil" bulundu ve silindi. Şimdiki deneme
yerleşkeyi haritadaki çizim diliyle gösterir, her şey yerleşkeye tıklanarak yapılır.

- Sandbox: `sandbox/factory_campus_sandbox.tscn` (F6). Haritanın kamerası, para ve hız panelleri, cüzdan ve
  oyun saati kullanılır.
- Görsel: `visuals/factory_campus_visual.gd` (önizleme `visuals/factory_campus_preview.tscn`, ilk taslak
  `visuals/factory_campus_sketch.png`). Kurallar `economy/line_factory.gd`, test `tools/tests/test_line_factory.gd`,
  ekran görüntüsü `tools/render_factory_campus.gd`. Harita kodu değişmedi.

Yerleşke (soldan sağa mal akışı):
- Üstte kamyon şeridi; solda giriş yığınları (demir, kömür, bakır; stokla büyür), sağda çıkış sahası (çelik
  rulosu ve parça sandığı, stok kadar).
- Ortada bant rafını oyun kendi çizer; akan noktalar ne aktığını, seyrekliği az aktığını gösterir.
- Altta parseller (yuva başına bir parsel):
  - Çelik hattı (11.000): 1 demir + 1 kömür → 0,5 çelik /sn. Seviye başına bir fırın; çalışırken fırın
    kızarır, baca tüter.
  - Parça hattı (9.000): 0,5 çelik + 0,5 bakır → 0,5 parça /sn. Atölyenin çatısındaki dişli döner.
  - Seviye lambaları köşede; hat durursa balon eksik malı (ya da dolu sandığı) gösterir.
- Çelik makası: ilk parça hattından önce çelik bandında sarı elmas; halkası parçaya giden payı gösterir.
- Çitin dışında satılık parsel (5.000); alınınca yerleşke bir parsel genişler (en çok 8).

Tıklamalar: boş parsel → çelik / parça hattı tepsisi (fiyatlı); hat → hızlandır / kaldır (yarısı geri);
satılık parsel → satın al; makas → payı %25 artır (sonra sıfıra döner); yığın / saha → kamyon sıklığı (sadece
sandbox'ta, haritanın rotalarının yerine). Fare üstündeyken kısa bir ipucu çıkar. Kamyonlar yoldan gelip
yığına boşaltır ya da sahadan yükleyip satar (çelik 200, parça 600).

Kurallar: hızlandırma seviye 1 / 2 / 3 = 1× / 1,5× / 2× (seviye n+1, hattın yarı fiyatı × n); ortak giriş
ve çıkış depoları 200; aynı türden hatlar eksik girdiyi ihtiyaçlarına göre paylaşır; makasın parça hattına
gönderip kullanılamayan çeliği satışa döner.

## Bakılacaklar

- Kararlar ilginç mi: hangi hat, kaç yuva, hızlandırma mı yeni yuva mı, paylaştırma oranı?
- Haritadaki akışı bozmuyor mu? Yerleşke haritada ne kadar yer kaplamalı?
- Haritaya bağlanırsa: mevcut "Fabrika" binasının yerine yerleşke kurulur, kamyonlar gerçek rotalardan gelir;
  her kare yeniden çizim yerine sabit ve hareketli katman ayrılmalı.
  O zaman bant kodu (flow_sim, belt_grid, belts_view, splitter/merger/tünel, factory_interior) kaldırılır.
