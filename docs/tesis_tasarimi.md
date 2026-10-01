> **Not (2026-09-30):** Bu haritadaki tesis tasarımının yerini bantlı fabrika içi aldı; bkz. `docs/fabrika_ici.md`. Tesis kodu kaldırıldı, bu belge geçmiş kaydı olarak duruyor.

# Tesis (üretim alanı) tasarımı

2026-09-29 · beyin fırtınası sonucu

## Özet

Haritadaki tek bina "Fabrika" yerini **tesislere** bırakır. Oyuncu haritada çitli bir **tesis alanı** kurar, içine **makineleri** tek tek yerleştirir. Mal yalnızca yakındaki makineye akar; makinelerin hızları farklıdır. Oyuncunun tasarladığı şey: kaç makine (oran dengeleme) ve nereye (yerleşim / komşuluk). Ayrı fabrika ekranı ya da düğüm editörü yoktur; her şey haritada görünür.

## Anlaşılanlar

- Fabrika içi haritanın kendisidir (seçenek A); B (ayrı ekran kat planı) ve D (düğüm editörü) girip çıkma yorgunluğu ve araştırmayla gelen makineleri "hangi fabrikaya koysam" derdi yüzünden elendi.
- Bağlantı: alan mantığı (3) + menzille otomatik aktarım (1) birlikte.
- Mekanik: oran dengeleme + komşuluk/yerleşim. Altyapı kapsaması, tarif seçimi, yan ürünler sonra araştırmayla.
- Kamyonlar tesis kapısına cevher getirir, kapıdan ürün alır.
- Mekanikler ana haritada değil, ayrı bir deneme sahnesinde (sandbox) oturtulur; sonra ana haritaya taşınır.

## Varsayımlar (denemede ayarlanacak)

- Aktarım menzili: makine kenarından ~40 birim (neredeyse bitişik).
- Tesis kapısı bir birimdir; giriş ve çıkış stoğunu tutar. Hammadde oradan çekilir, ürün oraya döner.
- İlk tarifler: Yüksek fırın 2 demir + 1 kömür → 1 pik demir (10/gün); Konvertör 1 pik demir + 1 kömür → 1 çelik (5/gün). 1 fırın = 2 konvertör.
- Mevcut "Fabrika" binası tesis hazır olana dek kalır.

## Modüller

1. **Tesis alanı ve kapısı:** çitli alan kurulur, kapısı yola bakar; kamyon cevheri kapının giriş stoğuna indirir.
2. **Yüksek fırın:** yalnızca tesis içine kurulur; menzilindeki kapıdan çeker, pik demir üretir; dişli + akış çizgisi.
3. **Konvertör ve oran:** pik demir + kömür → çelik; bekleyen/tıkalı makineler işaretlenir.
4. **Komşuluk bonusu:** fırına bitişik konvertör daha hızlı.
5. **Satış:** kamyon "tesis → kasaba" rotasıyla çeliği satar.

Her modülün yeni bina görünüşü önce önizlemede onaylanır.

## Durum

- Modül 1 (2026-09-29): deneme sahnesinde (`sandbox/facility_sandbox.tscn`) tesis alanı + kapı + giriş stoğu; kamyonlar kapıya cevher getiriyor.
- Modül 2 (2026-09-29): yüksek fırın (`facility/machine.gd`, `visuals/blast_furnace_visual.gd`). Aktarım menzili 40 birim, fırın 2 demir + 1 kömür → 1 pik demir, **günde 2** (oyun günü 2 sn olduğu için dokümandaki 10/gün yerine; genel ekonomi dengesi sonra). Durumlar: çalışıyor / girdi yok / çıkış dolu / kapıya uzak.
- Modül 3 (2026-09-29): konvertör (`visuals/converter_visual.gd`): 1 pik demir + 1 kömür → 1 çelik, günde 1; 1 fırın = 2 konvertör. Pik demiri komşu fırından, kömürü kapıdan alır, yani ikisine de yetişmeli. Her makinenin köşesinde dişli + hız etiketi ("2/gün"), oranlar gözle okunur.
- Modül 4 (2026-09-29): komşuluk bonusu. Fırına bitişik (kenar kenara ≤ 12 birim; aktarım menzili 40) konvertör sıcak metalle %50 hızlı (1,5/gün). Hız etiketi yeşil, aralarında turuncu sıcak metal bağı; kurarken önizlemede ve ipucunda "+%50". Bonuslu iki konvertör 3 pik demir ister, bir fırın 2 verir: oyuncu fırın ekler ya da bonusu nerede kullanacağını seçer. Makine çıktısını komşularına adil dağıtır (her birimi en az girdisi olana).
- Modül 5 (2026-09-29): satış. Deneme sahnesinde yolun doğu ucunda kasaba; yalnızca çelik alır (350/birim, ham mal satılmaz). Mavi kabinli satış kamyonları tesisin çıkış stoğundan en az yarım yük (10) bekleyip alır, 12 sn bekledikten sonra elindekiyle çıkar; satınca kazanç kasabanın üstünde yükselir. Kasaba talebi/doygunluk henüz yok.
- Ana haritaya taşındı (2026-09-29): "Fabrikalar" sekmesinde Tesis alanı (300x200; ana harita için 360x240 fazla büyüktü) + Yüksek fırın + Konvertör; eski Fabrika menüden kalktı (kodu duruyor). Kasabalara sabit bölge (ZONE_RADIUS 200) verildi, kasaba bu bölgeyi aşamaz; **satış deposu** yalnızca bir kasaba bölgesine kurulur ve o kasabaya satar (kamyon doğrudan kasabaya satmaz). Rotalar: yükleme = maden deposu ya da tesis, boşaltma = tesis ya da satış deposu (maden deposu → satış deposu olmaz). Tesis yalnızca makinelerinin kullandığı malı kabul eder. Test: `tools/tests/test_hauling.gd`.
- Ana haritada tıklama / taşıma / kaldırma (2026-09-29): lojistik depo → depo paneli (+Taşı/Kaldır); diğer binalar → `ui/building_panel.gd`. Test: `tools/tests/test_building_edit.gd`.
- Bilinen: başlangıç yol ağı 3 kopuk parçadan oluşuyor (6/4/4 kasaba), orman değişikliğinden önce de böyleydi; oyuncu yol çizerek birleştirebilir.
- Okunabilirlik (2026-09-29): her makinenin alt kenarında tarif şeridi ("2 ● + 1 ● → 1 ●"), üzerine gelince bilgi kartı, kurarken ipucunda tarif; akış çizgileri sadece gerçekten olan aktarımları gösterir. Kapı yalnızca kamyonların getirdiği mallar için kaynak sayılır.
- Seçme / taşıma / kaldırma (2026-09-29, deneme sahnesinde): tıklayınca seçilir ve solda panel açılır; Taşı ücretsiz, aynı kurallarla; Kaldır yarı parayı geri verir, tesis makineleriyle birlikte kalkar. Ana haritadaki binalara da taşınacak.
- Test: `tools/tests/test_facility_sandbox.gd` (~1 sn).

## Karar kaydı

| Karar | Alternatifler | Neden |
| --- | --- | --- |
| Üretim haritada, tesis alanında (A) | B kat planı ekranı, D düğüm editörü, C sadece yapılandırma | Tek ekran; araştırmayla gelen makine doğrudan haritaya kurulur; çizim tarzına uyar |
| Alan + menzille otomatik aktarım | Oyuncu bant çizer; sadece alan içinde her şey bağlı | Maden → maden deposu ile aynı dil; mevcut kodla hızlı; yerleşim yine önemli |
| Oran dengeleme + komşuluk ilk mekanik | Altyapı kapsaması, tarif seçimi, yan ürün | "Kaç tane" ve "nereye" sorularını birlikte getirir; diğerleri araştırma katmanı olur |
| Ayrı deneme sahnesi | Doğrudan ana harita | Ana harita yavaş yükleniyor; mekanik hızlı denenmeli |
