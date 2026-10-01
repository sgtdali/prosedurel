# Kasaba talebi (önceki tasarım, 2026-09-30)

> Bu dosya ilk çelik talebi uygulamasının tarihsel kaydıdır. 2026-10-01 tarihli güncel kurallar
> [ilerleme_motivasyon.md](ilerleme_motivasyon.md) içindedir: üç tam ayda büyüme, küçülme,
> ürün başına talep ve kalıcı toplam nüfus açılımı önceki kuralların yerini almıştır.

Oyun denemesi: ilk zincir kurulunca oyuncu bekliyor, ne yapacağını bilmiyor ("bitti sanki oyun"). Hedef,
baskı ve sonrası yok. Çözüm: kasabaların aylık çelik talebi; talebi karşılanan kasaba büyür.

## Anlaşılanlar

- Her kasabanın aylık çelik talebi var. Kasabalar kendiliğinden büyümez; ayın talebi karşılanınca birkaç ev
  ekler, talebi artar. Karşılanmazsa yerinde sayar (küçülmez).
- Talebe kadar tam fiyat (200), fazlası %25 (50).
- Şimdilik sadece çelik; yeni mallar sonraki adım.
- Kapsam dışı: yeni mallar/tarifler, küçülme, rakipler, hedef listesi.

## Varsayımlar

- Talep = ev × 2 çelik/ay (ay = 30 gün = 60 sn). 12 evlik kasaba 24/ay; ilk küçük zincir ~6/ay, dengeli birim 30/ay.
- Karşılanan ay sonunda +3 ev, en çok 60 (60 ev = 120/ay = 4 dengeli birim).
- Satış deposu kuralı aynı (kasaba bölgesinde).

## Tasarım

### 1. Veri ve kurallar

- `economy/town_demand.gd` (png_map "Demand"): kasaba başına `demand` (ev × 2), `delivered` (bu ay), `grown`.
- Ay sonu (GameClock ay değişimi): `delivered >= demand` ise kasaba 3 ev ekler (`cities.grow`), kutlama; her
  durumda `delivered` sıfırlanır, talep yeni ev sayısından.
- Satış: hauling satış deposunda `demand.sell(town, "steel", amount)` → para (talepte kalan 200, fazlası 50).
  Para yazısı ucuza satışta soluk sarı.
- cities.gd: kendiliğinden büyüme kapanır, `grow(town, count)` eklenir (ev ekleme aynı).

### 2. Görünüm (yazısız)

- Her kasabanın üstünde hep görünen rozet: çelik çipi; halka = bu ay gelen / talep (dolunca yeşil); dışında
  her 10 ev için bir ev işareti (en çok 6); satış deposu yoksa çip içi boş, halka yok (fırsat); 60 evde yıldız.
- Ay sonu büyüme: rozet bir kez parlar, "+3 ev" yeşil ev simgesi yükselip kaybolur, evler belirir.
- Tab: rozetler büyür, halka kalınlaşır.
- Ekranda en az 24 px.

### 3. Sıra, uç durumlar, test

- Sıra: 1) veri + `grow` + satış fiyatı + denge.md + veri testi; 2) rozet/kutlama önizlemesi, onaydan sonra harita.
- Uç durumlar: iki satış deposu aynı talebi doldurur (talep kasabanın); ilk ay normal; 60 evde büyüme yok,
  talep 120'de sabit; depo kaldırılınca o ayki teslim sayılı kalır; duraklatılınca ay ilerlemez; arsa yoksa
  sığan kadar ev (yeni sokak arsa açar).
- Testler: talep = ev × 2; ay içi 200 / 50 bölüşümü; karşılanan ay +3 ev ve yeni talep; karşılanmayan ay aynı;
  60'ta durur; test_hauling satış parası talep üzerinden; test_towns `grow` ile.

## Karar kaydı

| Karar | Alternatifler | Neden |
| --- | --- | --- |
| Hedef = kasaba talebi | Hedef listesi; ikisi birlikte | Transport Fever mantığı, iki katmanı da zorlar, bitmez |
| Büyüme talebe bağlı, küçülme yok | Kendiliğinden büyüme; karşılanmazsa küçülme | Oyuncu kasabayı eliyle büyütür, ceza yok |
| Fazlası %25 fiyata | Alınmaz (depo dolar); tam fiyat | Fazla üretim boşa gitmez ama yeni kasaba daha kârlı |
| Önce sadece çelik | Büyüyünce ikinci mal | Döngü önce denensin |
| Ayrı talep düğümü | cities.gd içinde | Ekonomi kararları tek yerde, ikinci mal kolay |

## Durum

- Adım 1 ✔ (2026-09-30): `economy/town_demand.gd` (png_map "Demand": `demand_of` = ev × 2, `sell` 200 / 50 bölüşümü, ay sonu = saatin 1. günü, +3 ev `cities.grow`, `town_grew` sinyali; sayım kasaba kaydında `delivered`, `grown`). `towns/cities.gd`: kendiliğinden büyüme ve `growing` kalktı, `grow(town, count)`. `economy/hauling.gd`: satış parası talepten, ucuza satışta para yazısı soluk sarı. Başlangıçta 138 ev (kasaba başına ~10 → ~20 çelik/ay). Test: `tools/tests/test_town_demand.gd`; test_hauling, test_building_edit, test_towns geçti.
- Adım 2 ✔ (2026-09-30): `ui/map_icons.gd` `draw_town_badge` / `draw_house_mark` / `draw_star` / `draw_grew_mark` (önizleme `tools/render_town_badge_preview.gd`). `ui/map_signs.gd`: her kasabanın merkezinin üstünde rozet (`badge_of`: satış deposu var mı, ay dolumu, tam mı, büyüme parlaması), büyüyünce 1,8 sn parlama + yükselen yeşil ev; Tab açıkken ×1,35. Test: test_town_demand (büyüme parlaması), test_hauling (satış depolu kasaba dolu, diğeri boş rozet).

Kasaba talebi tamamlandı.
- Kasaba kartı (2026-09-30, kullanıcı isteği: "şehirleri tıklamak ve bir şeyler görmek istiyor insan"): `ui/town_panel.gd`. Binası olmayan yerde kasabaya tık (kasaba alanı + 20) kartı açar (building_panel.gd devreder). Kart: ad, ev işareti + "24 / 60 ev" (tamsa yıldız); bu ay: çelik çipi + gelen/talep çubuğu (talep çizgisi, karşılanınca yeşil, fazlası soluk sarı) + ayın geçen kısmı saat halkası; son 12 ay sütunları (`town_demand` `history`: gelen, talep çizgisi, karşılanan yeşil, büyüdüğü ay ev işareti); besleyen rotalar (renk şeridi, yükleme binası, mal çipi, kamyonlar; kart açıkken haritada çizilir, `hauling.highlighted`); satış deposu yoksa "Satış deposu kur". Test: test_hauling (kasabaya tık → kart, çelik rotası listede), test_town_demand (geçmiş, kart görüntüsü).
