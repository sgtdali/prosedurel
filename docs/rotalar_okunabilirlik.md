# Rotalar ve okunabilirlik (tasarım, 2026-09-30)

Oyun denemesinden çıkan iki sorun: (1) bir rotaya tek kamyon atanabiliyor, rota ile kamyon bağımsız olmalı;
(2) nereden nereye ne kadar ne gittiği, ne tükendiği / üretildiği, nerede duruş olduğu okunamıyor; yazısız,
görsel yollarla çözülmeli, hem haritada hem fabrika içinde.

## Anlaşılanlar

- Lojistik deposu garaj: kamyonlar depo panelinden tek tek alınır, depoda boşta bekler.
- Rota ayrı bir kayıt: Rotalar panelinden "Yeni rota" → yükleme yeri → boşaltma yeri. Rota kartında kamyon
  sayısı ve +/−; + boşta kamyonu olan en yakın depodan alır, − kendi deposuna yollar.
- Okunabilirlik: sorun işaretleri hep görünür, ayrıntı katmanı Tab ile (harita ve fabrika içi aynı kural).
- Kapsam dışı: yeni araç türleri, bakım gideri, rota mal filtresi, çok duraklı rota, istatistik tabloları.

## Varsayımlar

- Kamyon 1.500 (satınca yarısı), lojistik deposu 3.000 → 2.000 (kamyonsuz), depo en çok 8 kamyon.
- Rotalar tek yönlü; taşınan mal bugünkü gibi otomatik (fabrikanın en az olduğu cevher).
- Boşta kamyon yokken + soluk; basılırsa haritadaki depolar bir kez yanıp söner.
- Ayrıntı tuşu Tab. 50 kamyon / 20 rotaya kadar akıcı. Kayıt sistemi yok.

## Tasarım

### 1. Veri ve kurallar (economy/hauling.gd içinde)

- Rota `{pickup, dropoff, trucks[], color}`; rengi kendini tanıtır. Aynı çift ikinci kez kurulamaz (var olanın
  kartı açılır).
- Kamyon `{home, route, durum, yük}`; sürme / yükleme / boşaltma döngüsü aynı, rotayı kaydından okur.
- Kamyon al: depo panelinde, en çok 8. Sat: yalnız depoda boştaki, yarı fiyatına.
- +: boşta kamyonu olan depolardan yükleme yerine en yakınındaki; kamyon doğrudan yükleme yerine gider;
  rotadaki önceki kamyon kalktıktan birkaç saniye sonra kalkar.
- −: rotaya en son eklenen çıkar; yüklüyse önce teslim eder, sonra deposuna döner. Rota silme (çöp kutusu):
  hepsi böyle döner.
- Bir ucu kaldırılan rota silinir. Kaldırılan depo kamyonlarını götürür: depo yarısı + kamyonların satış bedeli.

### 2. Arayüz (1. konu)

- Sağ üstte Rotalar düğmesi (rota sayısıyla); solda Rotalar paneli: satır = renk şeridi, yükleme simgesi →
  boşaltma simgesi, taşınan malın çipi, kamyon sayısı ve −/+. Altta "Yeni rota": yükleme / boşaltma tıklanır
  (seçilebilenler halkayla parlar, fare altındakine önizleme çizgisi); yeni rota 0 kamyonla, + yanıp söner.
- Rota kartı (satıra ya da haritadaki çizgiye tık): büyük −/+, kamyon simgeleri (yük rengi, durum renk/şekil:
  yolda, yükleniyor, bekliyor, yol yok), çöp kutusu; rota kalın çizilir, uçlarda 1 / 2.
- Depo paneli: "Kamyon al · 1.500" + 8 kutuluk doluluk; kamyon simgeleri (rotadakiler rota renginde,
  boştakiler gri; boştakinin üstünde "Sat"); Taşı / Kaldır.
- Esc geri adım (rota kurma → kart → panel); R Rotalar panelini açar/kapatır.

### 3. Harita okunabilirliği

- Mal çipi: her malın rengi + şekli (demir külçe, kömür topak, bakır levha, pik kalın külçe, çelik kiriş), her
  yerde aynı.
- Hep görünen balonlar (binanın üstünde, içinde malın çipi):
  - Eksik: içi boş çip, kırmızı halka, yavaş yanıp söner.
  - Dolu / tıkalı: dolu çip + kırmızı çubuk.
  - Yol yok: kopuk yol simgesi (kamyonun üstünde ve rotanın kopuk yerinde).
  - Kamyonsuz rota soluk kesikli. Madenin "durdu" işareti bu dile geçer.
- Tab: harita kararır; rotalar kendi renginde, üstünde malın renginde akan noktalar (1 → 2); kalınlık ve nokta
  sıklığı son 2 ayda taşınanla orantılı. Maden deposu / fabrika kapıları / çıkış stoğunda çip + dolum halkası
  (boş → kırmızı). Madende yukarı ok + cevher çipi; fabrikada girdi okları solda, ürün okları sağda; ok
  kalınlığı son 2 ayın hızı. Tıklama normal görünümdeki gibi.

### 4. Fabrika içi okunabilirlik

- Hep görünen (makinenin üstünde 3B balon): aç → eksik girdinin boş çipi; tıkalı → ürün çipi + kırmızı
  çubuk; durdurdan sorumlu bağsız portun yer oku kırmızı yanıp söner. Lamba: yeşil çalışıyor, sarı aç, kırmızı
  tıkalı. Giriş kapısı: malsızsa kesikli boş çip yuvası ("Mal seç" yazısı gider), stoğu bitince eksik balonu;
  çıkış stoğu doluysa kırmızı çubuk. Kapı yazıları yerine malın çipi + ince dolum çubuğu (hep).
- Tab: kımıldamayan bant hücreleri turuncu → kırmızı (kuyruğun başı görünür); her portta 4 noktalık arabellek,
  makinenin üstünde parti ilerleme halkası; port okları + çipleri (makine / bant aracı elindeyken de); kapı
  akış okları (kalınlık = son 60 sn'de geçen).
- Yazılı kartlar yerinde kalır ama okumak şart olmaz.

### 5. Ölçüm, sıra, test

- Sayaçlar: rota / kapı / maden için gün başına geçen, son 60 günün toplamı (fabrika içi: son 60 sn). Bütün
  kalınlıklar / sıklıklar bunlardan.
- Sıra (her adımda test + ekran görüntüsü):
  1. Rota ve kamyon verisi (+ veri testi)
  2. Rota arayüzü (Rotalar düğmesi / paneli, rota kartı, depo paneli, çizgiye tıklama)
  3. Mal çipleri ve balon dili (önce önizleme), haritadaki sorun işaretleri
  4. Harita Tab katmanı
  5. Fabrika içi: balonlar, lambalar, port okları, kapı çipleri; sonra Tab katmanı
- Uç durumlar: aynı yolu kullanan rotalar hafif kaydırılır; bir binada en çok 3 balon (yol yok > eksik > dolu);
  rotadan çıkarılıp yoldaki kamyon kartta soluk; fabrika içi açıkken harita sayaçları çalışır.
- Testler: test_hauling yeni modele (kamyon al, rota, + ile 2 kamyon, ikisi de taşır, −, rota silme, iadeler);
  sayaç testi; sorun işareti testi (kapı boşalınca eksik).

## Karar kaydı

| Karar | Alternatifler | Neden |
| --- | --- | --- |
| Kamyon depodan tek tek satın alınır | Depo sabit 2 kamyon; rotadan satın al | Sayıyı oyuncu belirler, bina ve kamyon maliyeti ayrı |
| Atama rota kartında +/− | Depo panelinden rotaya; ikisi birden | Karar "bu hatta kaç kamyon" sorusu, en az tıklama |
| Sorunlar hep, ayrıntı Tab ile | Hepsi hep açık; hepsi tuşla | Factorio gibi: sorun kaçmaz, görünüm sade |
| Rota hauling.gd içinde kayıt | Ayrı routes.gd düğümü | Çalışan kamyon döngüsü aynı kalır, iş az |
| Miktar = kalınlık / sıklık / dolum halkası | Sayılar | Yazısız okunabilirlik isteği |

## Durum

- Adım 1 ✔ (2026-09-30): `economy/hauling.gd` Route kaydı (renk paletinden), `buy_truck` / `sell_truck` / `can_sell`, `add_route` (aynı çift = aynı rota), `remove_route`, `add_truck` (yola göre en yakın boş kamyon, STAGGER 4 sn arayla kalkış), `remove_truck` (yükünü teslim edip eve döner); depo 2.000, kamyon 1.500, depo iadesi kamyonları sayar (`fleet_value`). Depo paneli geçici: Kamyon al / Sat. Rota kurma şimdilik yalnız kodda (`start_assign`), arayüz adım 2'de. Test: test_hauling (3 kamyon, 2'si aynı rotada ikisi de taşır, çıkarma, satma, rota silme, iade), test_building_edit.
- Adım 2 ✔ (2026-09-30): `ui/routes_panel.gd` (hız kartının solunda Rotalar düğmesi + rota sayısı; sağda kart: satır = renk şeridi, yükleme → boşaltma bina simgeleri, son taşınan malın çipi, −/sayı/+; seçili satırda kamyon simgeleri — rota renginde, yüklü, durum noktası: yeşil yolda, mavi yükleme, sarı bekliyor, kırmızı yol yok — ve çöp kutusu; + Yeni rota ve adım ipucu). `ui/depot_panel.gd` yeniden: Kamyon al + 8 kutuluk doluluk, kamyon simgeleri (rota renginde / gri), boştakinin üstüne gelince Sat. `ui/map_icons.gd`: bina, kamyon, mal çipi çizimleri (çip şekilleri adım 3'te). Harita: panel açıkken bütün rotalar ince (kamyonsuz kesikli), seçili kalın + 1/2; çizgiye tık rotayı seçer; + boşta kamyon yokken depoları yanıp söndürür. R paneli açar/kapar, Esc geri adım. Test: test_hauling paneller üzerinden.
- Adım 3 ✔ (2026-09-30): `ui/map_icons.gd` mal çipleri (krem disk + şekil: demir cevheri köşeli kaya — cevher olduğu için külçe değil —, kömür topak, bakır levha, pik kalın külçe, çelik I-kiriş; içi boş = eksik) ve `draw_balloon` (eksik: boş çip + yanıp sönen kırmızı hale; dolu: çip + üstünde kırmızı dolu çizgisi; yol yok: kopuk yol). Önizleme: `tools/render_signs_preview.gd`. `ui/map_signs.gd` (png_map MapSigns): fabrika eksik girdi / dolu çıktı, maden deposu dolu yığın, duran maden, 30 gündür mal gelmeyen satış deposu, yolu olmayan rota uçları ve kamyon; en çok 3 balon, ekranda en az 28 px. Madenin kırmızı çizgisi kalktı (gri dişli + balon). Kamyonsuz rotalar panel kapalıyken de soluk kesikli. Test: test_hauling (fabrika demir/kömür eksik, dolu yığın).
- Adım 4 ✔ (2026-09-30): `economy/flow_meter.gd` (son 60 günün gün başı sayımı, `per_day`); sayaçlar: rota (`Route.meter`, teslim edilen), satış deposu (`meter`), maden (`mine.meter`, `Mining.days` saati), fabrika (`layout.consumed` / `produced`, fabrikanın kendi `flow.elapsed` saati). `ui/map_overlay.gd` (png_map MapOverlay, Tab ya da Rotalar düğmesinin solundaki katman düğmesi): harita kararır; rotalar teslim hızı kalınlığında, üstünde malın renginde akan noktalar (çok taşıyan sık), hiç teslim etmemiş rota kesikli; madenin yanında cevher çipi + ok; maden deposunda yığın başına dolum halkalı çip; fabrikanın solunda girdi çipleri (kapı doluluğu halkası, içeri ok), sağında ürün çipleri (çıkış stoğu halkası, dışarı ok); satış deposunda sattığı malın çipi + ok. Halka %10'un altında kırmızı; ok kalınlığı = `width_for(günlük)`. Yapılmadı: aynı yolu paylaşan rotaları kaydırma (şimdilik üst üste). Test: test_hauling (sayaçlar, Tab).
- Adım 5 ✔ (2026-09-30): `factory/factory_signs.gd` (iç sahnenin HUD katmanında, kartların altında; 3B noktalar kamerayla ekrana izdüşürülüp haritanın çip/balon çizimleriyle çizilir). Hep: duran makinenin üstünde balon (aç → eksik girdinin boş çipi, tıkalı → ürün + dolu çizgisi); makineyi durduran bağsız portun pedi kırmızı halka + yön oku ile yanıp söner; giriş kapısında malın çipi + stok çubuğu (mal yoksa kesikli boş yuva, stok bitince eksik balonu); çıkış stoğu doluysa çıkış kapılarında dolu balonu. Makinelere direk üstünde durum lambası (yeşil çalışıyor, sarı aç, kırmızı tıkalı). Kapıların "Demir · 120/200" / "Mal seç" yazıları ve port adı yazıları kalktı. Tab: kımıldamayan bant hücreleri turuncu → kırmızı (`flow_sim.stuck`, 0,6 → 4 sn), makine üstünde parti ilerleme halkası, portlarda 4 noktalık arabellek, kapıda içeri akış oku; port çipleri Tab'da ya da bant/makine aracı elindeyken. Test: `tools/tests/test_factory_signs.gd`.

Rotalar ve okunabilirlik tamamlandı.
