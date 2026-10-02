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

## Haritada (2026-10-01)

Yerleşke png_map'teki tek fabrika: bantlı iç sahne ve kodu (`factory/`, `ui/factory_view.gd`, rozet, eski
fabrika görseli, ilgili testler) silindi.

- Bina: `visuals/factory_campus_map.gd` yerleşkeyi kapısı yola bakacak şekilde döndürür (harita ölçeği 0,31, `docs/sanayi_cografyasi.md` "Ölçek");
  yapı menüsü `visuals/factory_campus_thumb.gd` ile örnek yerleşkeyi gösterir. Fabrika 6.000, 4 boş parselle gelir.
- Kayıt: `buildings/depot_placer.gd` fabrika kaydında `factory` (LineFactory, cüzdandan öder). Parsel satın almak
  (`grow_factory`) yerleşkeyi yoldan uzağa bir parsel genişletir; yer yoksa nedeni ("Alan dolu", "Nehir üzerinde")
  farenin yanında görünür. Kaldırınca: binanın, hatların ve alınan parsellerin yarısı geri.
- Zaman: `economy/factories.gd` hatları oyun saatiyle çalıştırır; ekrandaki yerleşkeleri her kare yeniden çizer.
- Kamyonlar (`economy/hauling.gd`): fabrikanın hatlarının kullandığı cevheri getirir (hattı olmayan malı almaz),
  çıkış sahasından tam birimle yükler.
- Tıklama (`ui/campus_panel.gd`, sandbox ile ortak kurallar `ui/campus_actions.gd`): parsel, satılık parsel,
  makas; tepsi ve fiyatlar dik ve ekranda sabit boyutta kalır. Parça hattı nüfus açılımına kadar kilitli.
  Yerleşkenin başka yerine tıklamak bina kartını açar (hat sayısı, yığınlar, çıktı; Taşı / Kaldır).
- Harita balonları ve Tab katmanı yığınlardan ve akışlardan okur.
- Bilinen eksik: başka fabrikadan kamyonla çelik getirmek (fabrikadan fabrikaya rota) şimdilik yok; parça hattı
  çeliği yalnız kendi yerleşkesinin çelik hatlarından alır. Haritadaki kamyonlar kapıda durur, yerleşkenin
  içindeki şeritte görünmez.

## Uzmanlaşmış fabrikalar (deneme, 2026-10-02)

Sorun: bir yerleşkenin yuvalarına hem çelik hem parça hattı kurulabildiği için bütün zincir tek binada bitiyordu.
İkinci fabrikaya, fabrikadan fabrikaya taşımaya ve fabrikanın nerede durduğuna dair bir karar doğmuyordu
(`sanayi_cografyasi.md`). "Kamyonlu Factorio"ya kaymamak için iki kuralla birlikte:

**Karar: her yerleşke bir süreç türüdür**, türünü kurarken seçer; ne ürettiğini parsellerine kurulan hatlar
(modüller) belirler:
- Ergitme tesisi: cevherden metal. Şimdilik çelik hattı (demir + kömür → çelik); ileride bakır külçe vb.
- Montaj fabrikası: metalden ürün. Şimdilik parça hattı (çelik + bakır → makine parçası); ileride kablo, alet vb.
  Nüfus açılımına kadar kilitli.
- Montajın çeliği kamyonla bir ergitme tesisinden gelir (fabrikadan fabrikaya rota). Çelik makası kalktı.
- Giriş bunkerleri ve çıkış sahaları türün hatlarının girdi/çıktılarından oluşur; yeni modül gelince yerleşke
  kendiliğinden yeni bunker / saha gösterir. Aynı malı isteyen farklı hatlar stoğu ihtiyaçları oranında paylaşır.

Kurallar:
1. **Bir süreç = bir bina türü; bir hat, aynı binadaki başka bir hattın ürününü kullanamaz.** Hatlar yalnız
   kamyonla gelen bunkerlerden alır; tarifler buna göre kurulur (ergitme hammaddeden, montaj metalden). Böylece
   zincir haritada en az bir kez binadan binaya geçer; kısa tutulur (en çok 3–4 halka).
2. **Büyümek yuvayla olur.** Aynı malın üretimini artırmak için aynı yerleşkeye hat eklenir; yeni bina ve yeni rota
   gerekmez, mevcut rotaya kamyon eklenir. Haritadaki bina ve rota sayısı üretim hacmiyle değil mal çeşidiyle artar.

Ölçüt: oyuncunun zamanı "şunu şuna bağla" ile değil "parçayı nerede üreteyim, bu yol yetiyor mu, o kasabaya ulaşmaya
değer mi" ile geçmeli.

## Görseller: Blender (2026-10-01)

Yerleşkenin binaları ve zemin parçaları Blender'da modellenip tam yukarıdan render edilir (güneş sol üstten,
şeffaf arka plan); oyun bunları yerleşkenin düzenine göre yerleştirir. Ölçek: 1 m = 11,79 birim (fırının
5,6 m'lik karesi 66 birim).

- Fırın: `blender/scripts/render_furnace_topdown.py` → `visuals/art/furnace_top.png` (kızgın), `furnace_top_cold.png`.
- Kit: `blender/scripts/create_campus_kit.py` → `visuals/art/campus/`: kamyon şeridi parçası, parsel zemini (dolu /
  boş), bunker, 3 cevher × 5 doluluk yığını, 2 çıkış sahası × 6 doluluk (0–5), ofis, parça atölyesi (çalışıyor /
  duruyor). Betiğin başındaki ölçüler `factory_campus_visual.gd` düzeniyle eşleşmeli.
- Bant rafı da Blender parçası (`rack_tile`, parsel başına bir tane; olukları RACK şeritleriyle hizalı).
- Kodla kalanlar: raftaki bantlar ve akan noktalar (hatlara göre değişir), duman, fırının hazne ve döküm tavası, makas,
  seviye lambaları, balonlar, tepsi, çit, sandbox kamyonları.
- Katmanlar: zemin → Blender zemin resimleri → bantlar → Blender binaları (sönük/kızgın ya da karanlık/ışıklı resim,
  hat hızına göre karışır) → üstte kalanlar → dik tepsi.
- Bantlar modellerin gerçek giriş/çıkış noktalarına bağlanır: fırında besleme oluğunun ucu ve döküm ağzı, atölyede
  kuzey duvardaki iki giriş ve bir çıkış, bunkerde güney duvardaki boşaltma hunisi.
- Model değişince: Blender betiğini çalıştır, PNG'leri `visuals/art/` altına kopyala.

## Bakılacaklar

- Kararlar ilginç mi: hangi hat, kaç yuva, hızlandırma mı yeni yuva mı, paylaştırma oranı?
- Haritadaki akışı bozmuyor mu? Yerleşke haritada ne kadar yer kaplamalı?
- Çok fabrikada performans: her kare yeniden çizim yerine sabit ve hareketli katman ayrılmalı.
