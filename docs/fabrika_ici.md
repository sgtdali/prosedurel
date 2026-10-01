# Fabrika içi (bantlı üretim) tasarımı

2026-09-29 · beyin fırtınası sonucu

## Yön

Oyunun ana konusu **üretim zinciri akışı kurmak** (Factorio tarzı). Harita arz, talep ve biraz lojistik içeren strateji katmanıdır. Bu yüzden üretim haritanın içine sıkıştırılmaz: fabrikaya girilince harita ölçeğinden bağımsız, geniş bir üretim alanı açılır.

- **Harita (strateji):** Transport Fever tarzı kalır. Madenler, maden depoları, kasabalar, satış depoları, kamyon rotaları. Fabrikalar haritada kompakt bina + ürün rozeti.
- **Fabrika içi (ana oyun):** Makineler **bantlarla** bağlanır; ayırıcı ve birleştirici var. Görünüm Factorio gibi **açılı üstten** (3D, sabit eğim; makinelerin ön yüzü ve yüksekliği görünür). Harita kuş bakışı kalır.
- Yorgunluğa karşı: az ama derin fabrika, fabrikalar arası hızlı geçiş, ortak makine paleti, haritada uyarılar.
- Tesis modüllerindeki tarifler, makine hızları, oran dengeleme, komşuluk bonusu, kapı stokları fabrika içine taşınır.

## Adımlar (deneme sahnesinde: `sandbox/factory_floor_sandbox.tscn`)

1. Izgaralı fabrika zemini ve kamera ✔
2. Bant çizme ✔
3. Makineleri yerleştirme ve bantlara bağlama ✔
4. Akış simülasyonu ✔
5. Ayırıcı ve birleştirici ✔

## Durum

- Adım 1 (2026-09-29): `factory/factory_floor.gd` (40x24 hücre, hücre = 1 birim; ızgara tek düzlem + shader; duvarlar; batıda 2 giriş, doğuda 1 çıkış kapısı, zeminde turuncu ok plakaları), `factory/factory_camera.gd` (ortografik, 50° eğim, WASD / sağ-orta sürükle ile kaydırma, tekerlekle imlece doğru yakınlaştırma, zemin sınırında kalır), fare altındaki hücre vurgusu ve koordinatı. Test: `tools/tests/test_factory_floor.gd`.

- Adım 2 (2026-09-29): `factory/belts.gd`. Bant aracı (B): sol tık + sürükle hücre hücre döşer, her bant bir sonrakine bakar, sürükleme dönünce köşe; R bir sonraki bandı döndürür, tek tık tek parça. Sil aracı (X). Esc bırakır. Bantlar tek mesh: koyu yatak + akış yönünde kayan oklar (shader, 1,5 hücre/sn) + korkuluklar; yandan beslenen bant köşe olarak çizilir (dış korkuluk köşeyi çevirir). Hayalet bant fare altında. Test aynı dosyada.

- Adım 3 (2026-09-30): `factory/machines.gd`. Yüksek fırın 3x3, konvertör 2x2 (3D model). Her makinenin kenarında **tek ürünlü portlar** var: girişler batıda, çıkış doğuda (döndürünce birlikte döner). Port önündeki hücrede ürün renginde zemin plakası + akış okları + ürün adı (etiket); makinenin yanında ağız ve bant bağlanınca yanan yeşil lamba. Giriş portu, önündeki bant makineye bakıyorsa bağlı; çıkış portu, önünde geri dönmeyen bir bant varsa bağlı. Araçlar: 1 fırın, 2 konvertör (R döndürür, kırmızı hayalet = kurulamaz: zemin dışı, çakışma, bant üstü, kapı önü), X makineyi de siler, araçsız tıklama makineyi taşımak için alır (Esc yerine koyar). Makine üstüne gelince kartta tarif ve portların bağlı olup olmadığı. Bant makine hücrelerine döşenmez; makineye doğru sürüklenen bant makineye bakarak biter.

- Adım 4 (2026-09-30): `factory/flow.gd`. Her bant hücresinde sıralı mal kuyruğu (ilerleme 0 giriş kenarı → 1 çıkış kenarı), mallar arası en az 0,34 hücre (hücrede 3 mal), bant hızında (1,5 hücre/sn) ilerler, önündekinin arkasında bekler. Hücre sonunda: sonraki banda (arkadan ya da köşeden girişte başa, yandan girişte ortaya), makinenin doğru giriş portuna (yer varsa) ya da çıkış kapısından dışarı (sayılır). Yanlış mal porta girmez, bant tıkanır. Giriş kapıları (batı: Demir, Kömür; zeminde etiketli) kendi bandına saniyede 1,5 mal koyar. Makineler (`machines.gd`): her girdiden en fazla 4, çıktıdan 4 tutar; fırın 2 sn, konvertör 4 sn'de bir parti (1 fırın : 2 konvertör oranı korunur); çalışırken kızıllık yanar. Durum ve port stokları kartta. Sağ üstte çıkış kapısı sayacı, Boşluk duraklatır. Mallar açık renk tepsi üstünde renkli blok (iki MultiMesh; koyu kömür koyu bantta görünsün diye). Bant kaldırılınca üstündeki mallar kaybolur.

- Adım 5 (2026-09-30): ayırıcı ve birleştirici, tek hücrelik bant parçaları (`belts.kinds`), üstlerinde renkli kemer (ayırıcı turuncu, birleştirici mavi) ve malın çıktığı/girdiği kenarlarda işaret. Ayırıcı yalnız arkadan alır; mal ortasına gelince sıradaki çıkışı (ön, sol, sağ) seçer, dolu ya da bağsız çıkışı atlar; boş bir çıkış varsa mal hiç beklemez, hepsi doluysa ortada bekler (kullanıcı isteği: boş kola her zaman versin). Birleştirici arkadan, soldan, sağdan alır; son aldığı giriş, başka girişte bekleyen mal varken sırasını bekler. Araçlar: 3 ayırıcı, 4 birleştirici (R döndürür, bandın üstüne konabilir); bant sürükleme bu parçaları değiştirmez. Üstüne gelince kartta ne yaptığı yazar. Makine portu ayırıcıdan da beslenir. Deneme: kömür hattına ayırıcı konup kolu konvertöre götürülünce tek kömür kapısıyla 60 sn'de 15 çelik.
- Yeraltı bandı (2026-09-30, oynarken çıkan istek: bantlar birbirini geçemiyordu): araç 5. Bir tık giriş, sonraki tık çıkış (girişin önünde, aynı hizada, en çok 5 hücre ileride; R ya da Esc yeni tünele başlar). Mal girişin ortasındaki çukura girer, yerin altından çıkışa gider; aradaki hücrelere başka bant ya da makine konabilir. Giriş en yakın aynı yönlü çıkışla eşleşir (arada aynı yönlü başka giriş varsa o alır). Tünel parçaları yalnız arkadan alır, çıkış yalnız girişinden. Çıkış kaldırılırsa yerin altındaki mallar gider, hat girişte durur. Her uç 50 (tamamı geri). Üstüne gelince kartta eşinin kaç hücre ötede olduğu ya da eşi olmadığı yazar. Test: `tools/tests/test_factory_tunnel.gd`, veri testi `test_factory_state.gd`.

## Haritaya bağlama (tasarım, 2026-09-30)

### Özet

- Haritadaki 300x200 tesis alanı kalkar; yerine kompakt **fabrika binası** (~90x70). Tıklayınca 40x24 sabit iç alan açılır.
- Fabrika genel amaçlı: oyuncu içeride **her giriş kapısına mal atar**; kamyonlar o malları kapı stoklarına getirir, çıkış kapılarından çıkan her şey çıktı stokuna gider, kamyonlar satış deposuna taşır.
- **Tek saat:** içerisi oyun saatiyle işler (duraklat / 2x / 4x içeriyi de etkiler). Bütün fabrikalar her zaman hesaplanır; oyuncu içerideyken harita akmaya devam eder.
- **1 bant malı = 1 harita birimi.** Kapı, stokta mal oldukça bandın alabildiği hızda besler (1 maden ≈ 1 dolu bant).

### Varsayımlar

3 giriş + 2 çıkış kapısı (satırlar sabit), kapı stoku 200; malı atanmamış kapıya kamyon getirmez. Maliyet: fırın 3000, konvertör 4000, bant hücresi 10, ayırıcı/birleştirici 100; bant sökülünce tam, makine yarı iade; üstündeki mallar kaybolur. Hedef: ≤10 fabrika, fabrika başına birkaç yüz mal, 4x'te akıcı. Kaydet/yükle kapsam dışı. Eski tesis/makine kodu kalkar (tarifler fabrika içine taşınır). Haritadaki binada durum dişlisi + çıktı özeti rozeti.

Kapsam dışı (sonra): fabrikalar arası hızlı geçiş, araştırmayla kapı artışı, karışık bant + filtreli ayırıcı.

### Tasarım

1. **Veri / görüntü ayrımı.** `factory/factory_state.gd` (RefCounted, 3D yok): `grid` (belt_grid.gd: bantlar, türler, kurallar, `changed` sinyali), `machines` (machine_set.gd: kayıtlar, portlar, yerleştirme, kabul, üretim), `flow` (flow_sim.gd: kuyruklar, sıra, `step(dt)`), giriş kapılarının malı ve stoku, ortak çıktı stoku (mal başına 200; dolunca çıkış bandı tıkanır). Görüntü yalnız iç sahnede tek kopya: belts_view.gd, machines_view.gd, items_view.gd bir `FactoryState`'e bağlanıp okur; araçlar veriye yazar. Zaman: `step(dt)`, dt = gerçek süre × hız (duraklatınca 0), sabit 1/60 adımlar; değerler "1x'te saniye" olarak kalır (2 sn = 1 gün).
2. **Harita.** Yapı çubuğunda tek "Fabrika" (6000); bina yola bakan kapıyla, önce önizlemede onay. Rozet: dişli (bir makine çalışıyorsa döner) + çıktı özeti. `economy/factories.gd` bütün fabrikaları ilerletir. Kamyonlar: fabrikanın ihtiyacı = atanmış ve dolmamış kapı malları; teslim o kapının stokuna (aynı mal iki kapıdaysa daha boş olana); yükleme çıktı stokundan (eskisi gibi). Panel: "İçeri gir", kapılar ve stokları, çıktı stoku, Taşı (içerisi aynen kalır) / Kaldır (onaylı; bina + makineler yarı, bantlar tam iade).
3. **İç sahne.** Harita üstünde tam ekran SubViewport; harita arkada çalışır, girdisi kapanır. Kamera fabrika başına son konumunda açılır. Esc önce aracı bırakır, sonra haritaya döner; "← Haritaya dön" düğmesi. Üst çubuk (tarih, para, hız) içeride de görünür. Palette fiyatlar; para yetmezse soluk + "Yetersiz para"; bant sürüklerken hücre başına ücret, para bitince durur. Giriş kapısına tıklayınca mal seçici (değişince eski stok onayla silinir); kapı yazısı "Demir · 120/200", boşsa "Mal seç", stok bitince kırmızı.
4. **Uç durumlar.** Kapı malı değişince yoldaki kamyon için stok dolu sayılır. Fabrika taşınınca/kaldırılınca rotalar mevcut sinyallerle güncellenir/silinir. Karede en fazla 0,1 sn oyun zamanı işlenir.

### Testler

test_factory_floor.gd ayrımdan sonra aynı sonuçlar; yeni test_factory_state.gd (görüntüsüz: kapı stoku → bant, çıktı stoku dolunca tıkanma, 1x/4x/duraklatmada aynı sonuç); test_hauling.gd tam zincir (maden → kapı → içeride çelik → satış deposu); ekran görüntüleri. Yol testleri gerekmez.

### İş sırası

1. Veri ayrımı (deneme sahnesi `FactoryState` ile; mevcut test geçer) ✔ 2026-09-30: veri `factory_layout.gd` (zemin, kapılar), `belt_grid.gd`, `machine_set.gd`, `flow_sim.gd`, hepsi `factory_state.gd` içinde (`advance`: oyun süresi, 1/60 adım, kare başına en fazla 0,1 sn); çizim `belts_view.gd`, `machines_view.gd`, `items_view.gd`, `factory_floor.gd` (layout okur). Eski belts/machines/flow.gd silindi. Test aynı sonuçları veriyor (4 çelik; ayırıcıyla 60 sn’de 15).
2. Kapı ve çıktı stokları, oyun saati, ücretler (deneme sahnesinde, yeni test) ✔ 2026-09-30: 3 giriş (satır 6, 12, 17) + 2 çıkış (12, 17); `factory_layout.gd` giriş stokları (`set_in_good` stoku siler, `deliver` en boş kapıya, `room_for`), ortak çıktı stoku (`store_out`, `take_out`, mal başına 200); kapı stoktan bandın aldığı hızda besler (1,5/sn sınırı kalktı; tek bant ≈ 4,3/sn); çıktı stoku dolunca bant durur. Ücretler `FactoryState.cost_of / refund_of / contents_refund`; deneme sahnesinde cüzdan, palette fiyatlar, yetmeyen araç soluk, bant hücre başına 10 (para bitince çizim durur). Zemindeki kapı yazısı "Demir · 120/200", boşsa "Mal seç", stok bitince kırmızı. Deneme sahnesi giriş stoklarını dolu tutar (K kapatır). Test: `test_factory_state.gd` (görüntüsüz; 1x ile 4x aynı sonuç, duraklatma).
3. Fabrika binası önizlemesi (onay)
4. Haritaya bağlama: bina, yönetici, panel, kamyonlar; eski tesis kodunu kaldırma; test_hauling ✔ 2026-09-30: tarifler `factory/recipes.gd`; placer'da tek "Fabrika" (6000, `production_factory_visual.gd` ölçek 0,8, yola bakar, kaydında `state` + `badge`; iade = yarı bina + içindekiler); `economy/factories.gd` (png_map `Factories` düğümü) tüm fabrikaları oyun saatiyle ilerletir, rozet dişlisi/çıktı etiketi ve baca dumanını günceller; kamyonlar giriş kapılarının mallarına göre yük seçer, `deliver`/`take_out` ile boşaltır/yükler; panelde kapılar, çıktı stoku, makine/bant sayısı, fabrika kaldırmada "Emin misin?"; yapı çubuğunda tek Fabrika. Eski tesis, makine, tesis kapısı çizimi, tesis deneme sahnesi ve testi silindi. Kamyon ↔ trafik aracı döngüsü çıkışta kırılıyor (sızıntı yok). Testler: test_hauling (maden → kapı → içeride çelik → satış), test_building_edit (fabrika taşıma/kaldırma).
5. İç sahneyi haritadan açma: geçiş, üst çubuk, kapı seçici; ekran görüntüleri ✔ 2026-09-30: deneme sahnesinin kodu `factory/factory_interior.gd` oldu (deneme sahnesi aynı betik + `sandbox = true`). Haritada `ui/factory_view.gd` (png_map `FactoryView`, HUD bir katman üstte): panelde "İçeri gir" → tam ekran SubViewport; harita arkada çalışır ama girdisi kapanır (kamera durur, yapı çubuğu ve paneller gizlenir; tarih, para, hız kartları kalır). Tuşlar görünüm üzerinden fabrikaya iletilir. Esc önce aracı/menüyü bırakır, sonra haritaya döner; "← Haritaya dön" düğmesi. Boşluk oyunu duraklatır (hız kartıyla aynı). Kamera görünümü fabrika başına saklanır. Giriş kapısına tık → mal menüsü (kapıda stok varsa "Değişirse kapıdaki N … gider" uyarısı; seçmek onay). İçeride harcanan para oyunun cüzdanından. Test: `test_factory_view.gd`.

Haritaya bağlama tamamlandı.

## Karar kaydı

| Karar | Alternatifler | Neden |
| --- | --- | --- |
| Üretim ayrı fabrika içinde, harita strateji katmanı | Haritada tesis (büyük ya da ızgaralı küçük) | Ana oyun üretim akışı; harita ölçeği Factorio tarzı zincirlere yetmiyor, ikisi de içe sinmedi |
| Akış bulmacası = bantlar | Yerleşim/komşuluk, düğüm kabloları | "Üretim zinciri akışı oluşturma" hissine en yakın, akış gözle görülür |
| Fabrika içi açılı üstten (3D) | Harita gibi kuş bakışı | Factorio hissi, "içeri girdim" ayrımı; dağ/ormandaki 3D yaklaşımla aynı altyapı |
| Önce deneme sahnesi | Doğrudan oyuna | Hızlı deneme, küçük adımlar |
| Makine portları tek ürünlü ve sabit yerde | Her giriş her ürünü alır (Factorio kolu) | "Ne girer ne çıkar" haritada da istenen netlik; bulmaca bantların yönlendirilmesinde |
| Fabrika içi zaman gerçek saniye | Harita günü (GameClock) | Akışı gözle izlemek için; harita bağlantısında gün ↔ saniye çevrimi yapılacak |
| Ayırıcı/birleştirici tek hücre, sıra ile dağıtım | Factorio gibi 2 hücre genişlik, şerit (lane) sistemi | Izgarada basit, tek şeritli bantla uyumlu; öğrenmesi kolay |
| Haritada kompakt fabrika binası, sabit 40x24 iç alan | Boy seçmeli bina; tesis çiti kalsın | En basit; harita ölçeği sorunu tamamen biter |
| Oyuncu giriş kapısına mal atar | Fabrika tipi kapıları sabitler; karışık tek kapı | Tasarım özgürlüğü; karışık bant sonra araştırmayla |
| Fabrika içi oyun saatiyle (tek saat) | İçerisi hep gerçek zaman | Duraklatma/hız tutarlı, harita-fabrika dengesi bozulmaz (önceki "gerçek saniye" kararının yerine) |
| 1 bant malı = 1 harita birimi | 1 mal = kasa; günü uzatmak | Sayılar birebir; bugünkü değerlerle 1 maden ≈ 1 dolu bant |
| İçerideyken zaman akar | Girince duraklat; ayar | Factorio gibi; isteyen duraklatır |
| Veri/görüntü ayrımı (FactoryState + tek iç sahne) | Her fabrikaya gizli 3D sahne; sahne değiştirme | Görünmeyen fabrikalar ucuz, zaman ve ileride kayıt tek yerde; sahne değiştirme haritayı durdurur |
| İç sahne harita üstünde tam ekran açılır | Ayrı sahneye geçiş | Harita ve kamyonlar arkada çalışmaya devam eder |
| Bant kesişmesi yeraltı bandıyla (giriş + çıkış, en çok 5 hücre) | Köprü bant; tek hücrelik kavşak | Factorio'daki gibi; aradaki hücreler tamamen serbest (kullanıcı seçimi) |
