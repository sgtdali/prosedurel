# Sanayinin coğrafyası (değerlendirme, 2026-10-02)

Kaynak: ChatGPT ile yapılan araştırma konuşması (Transport Fever, Captain of Industry, Factorio oyuncu
motivasyonları) ve oyunun yönü üzerine sonuçları. Bu not o konuşmayı mevcut oyunla karşılaştırır.
**Durum: değerlendirme ve öneri; karar verilmedi.**

## Araştırmanın özeti

| Oyun | Döngü | Oyuncunun hazzı |
|---|---|---|
| Transport Fever | Kur → izle → talep büyür → darboğaz → iyileştir → genişle | "Benim ağım yaşıyor." |
| Captain of Industry | Kur → dengele → genişle → bozulur → teşhis et → yeniden kur | "Bu karmaşık sistemi kontrol edebiliyorum." |
| Factorio | Elle yap → otomatikleştir → ölçekle → yeni darboğaz → onu da otomatikleştir | "Artık bunu ben yapmıyorum." |

Ortak çekirdek: **başarılı çözüm oyunu sadeleştirmez, daha üst seviyede yeni bir problem üretir.**
Para, açılım ve görevler yardımcı katmandır; asıl tutan şey sahiplik, görünür simülasyon, kendiliğinden doğan
problemler, sürekli iyileştirme ve oyuncunun kendi koyduğu hedeflerdir.

Not: konuşmadaki oyuncu alıntıları ve yıldız puanları doğrulanmadı; genel desenler sezgi olarak alınmalı,
kanıt olarak değil.

## Vardığı yer zaten bizim yönümüz

Konuşmanın sonucu: "fabrikanın içini değil, sanayinin coğrafyasını kuruyorsun; az sayıda büyük kompleks,
içinde yuva seçimi, aralarında paylaşılan taşıma ağı." Bu, bantlı fabrika içinden vazgeçip geçtiğimiz hat
yuvalı yerleşkenin (`hat_fabrikasi.md`) karşılığıdır. Haritada zaten var olanlar: oyuncunun yerleştirdiği
maden, maden deposu ve fabrika; oyuncunun çizdiği yollar; gerçek şeritlerde giden kamyonlar; talep yaratan,
büyüyen ve küçülen kasabalar (`ilerleme_motivasyon.md`). Yön değişmiyor.

## "Transport Fever Lite" ile "kamyonlu Factorio" arasında

- Zincir 2–3 adım kalırsa ve tek fark fabrikayı oyuncunun koyması olursa: Transport Fever Lite.
- Her adım ayrı bina ve ayrı rota olursa: belt yerine kamyonlu Factorio.
- Derinlik zincirin uzunluğundan değil, kararların birbirini değiştirmesinden gelmeli.

Ayırıcı nokta: **Factorio'da mesafe bedavadır**, bant çekmenin ekonomik bedeli yoktur. Bizde her mesafe
kamyon, bakım ve yol demektir ve yol kasaba trafiğiyle paylaşılır. Mesafenin bedeli okunur olursa
"fabrikayı nereye koyayım?" gerçek bir karar olur; olmazsa oyun kamyonlu Factorio'ya kayar.

## Bugünkü durum: test geçilmiyor

Test sorusu: *çelik üretimini iki katına çıkarınca kaç yeni karar doğuyor?* Bugün cevap çoğunlukla
"rotaya kamyon ekle". Sebepler:

1. **Fabrikadan fabrikaya rota yok.** Çelik ve parça aynı yerleşkede dönüyor; "çeliği madenin yanında,
   parçayı şehrin yanında üret" kararı verilemiyor. Coğrafyanın önündeki en büyük eksik.
2. **Konum zayıf etkiliyor.** Kamyon bakımı araç başına sabit; mesafe yalnız daha uzun sefer = biraz daha
   fazla kamyon olarak hissediliyor.
3. **Madenler tükenmiyor.** Bir kez doğru kurulan düzen hep doğru kalıyor.

## Eldeki parçalarla ucuz kaldıraçlar

### Ağırlık kaybı → konum gerilimi
Tarifler bunu zaten taşıyor ama görünmüyor:

| Hat | Girdi | Çıktı | Oran |
|---|---|---|---|
| Çelik | 1 demir + 1 kömür /sn | 0,5 çelik /sn | 4'te 1 |
| Parça | 0,5 çelik + 0,5 bakır /sn | 0,5 parça /sn | 2'de 1 |

Ağırlık kaybettiren üretim hammaddeye, kaybettirmeyen pazara yakın kurulur. Çelik madene, parça şehre
yakın kurulunca doğal kümelenme çıkar. Gereken: fabrikadan fabrikaya rota ve kaynak/kasaba yerleşiminin bu
gerilimi besleyecek şekilde ayarlanması (bakır demir/kömürden uzakta, büyük kasaba arada).

### Trafik sıkışması
Kamyonlar gerçek şeritlerde, sağdan gelene yol vererek gidiyor (`traffic`). Hat büyüdükçe kasaba içinde
tıkanma görünürse oyuncu çevre yolu çizer: Transport Fever'ın "izle → darboğazı gör → düzelt" döngüsü
bizde fiziksel olarak var. Bugün gerçekten sıkışıp sıkışmadığı kontrol edilmeli.

### Maden tükenmesi (sonra)
Rezerv biter → yeni maden, uzun rota, belki fabrikayı taşıma kararı. Dünyayı hareketli tutar.

## Alınmayacaklar

- **Kamyonları kaldırıp koridor kapasitesi (t/gün):** "dünyada görünsün, web sitesi olmasın" kuralına ve
  trafik sistemine ters; "çalışan sistemi izlemek" en güçlü motivasyonlardan biri. Geç oyunda bir açılım
  olarak soyutlama (rota hedefi ver, kamyon sayısını oyun ayarlasın) düşünülebilir, şimdi değil.
- **Onay kutulu fabrika paneli:** yerleşke haritada yaşıyor, öyle kalmalı.
- **Kapsam:** rafineri ve çok çıktılı tesisler, cüruf, kirlilik, liman, ithalat ayrı birer proje;
  çekirdek döngü oturmadan girilmez.
- **Sert çöküş zinciri (death spiral):** kasaba küçülmesi ve asgari nüfus sınırı yeterli baskı.

## Ölçek (2026-10-02, uygulandı)

Oyunda görülen: iki kasaba arasına bir fabrika kurunca alan doluyor, yol yapmanın anlamı kalmıyor.
Ölçüler: komşu kasabalar ~1.100 arayla (bölge çemberleri arasında ~700 boşluk); 8 yuvalı yerleşke ~320
genişlikte, maden deposu menzili 600 çapında. Transport Fever'da mesafe bina boyunun ~30 katı, bizde 3–4
katıydı. Harita büyütülmedi (kamyon seferleri uzar, ekonomi baştan ayarlanır, harita pişirilmiş durumda);
binalar küçültüldü:

| Ayar | Önce | Sonra |
|---|---|---|
| Bina ölçeği (garaj, depo, satış deposu, fabrika, maden) | 0,62 | 0,31 |
| Maden deposu menzili | 300 | 150 |
| En yakın zoom | 2,4 | 5 |
| Sorun balonu (dünya / en az ekran pikseli) | 36 / 28 | 18 / 16 |
| Maden rozeti | sabit 12 yarıçap | 6, ekranda en az 5 piksel |
| Detay katmanı çipleri | 30 / 24 | 16 / 16 |
| Bina tıklama | merkezden 48 | binanın alanı (+6) |
| Yerleşkenin satılık levhası | hep aynı ekran boyu | uzakta küçülür, tüm haritada gizlenir |

Karşılaştırma: `img/olcek_karsilastirma.png` (aynı iki kasaba arasında önce 1, sonra 2 sanayi alanı;
ilkinde fabrika 4 yuvadan fazla büyüyemedi). Render: `tools/render_scale_compare.gd`.

Açık: binalar mevcut yolun 125 birim içine kendiliğinden bağlandığından her şey ana yolun dibine diziliyor;
yol çizmenin anlamı için ayrıca bakılacak.

## Önerilen sıra

1. **Oynanış denemesi** (`ilerleme_motivasyon.md` uygulama sırası adım 4, 20–30 dk) ve 20 ev civarındaki
   büyü-küçül salınımının düzeltilmesi (yeni ürün büyümeyi durdursun, küçültmesin).
2. **Fabrikadan fabrikaya çelik rotası.**
3. **Tarif ve kaynak yerleşiminin ağırlık kaybına göre ayarı.**
4. **Kamyon sıkışmasının kontrolü**; varsa görünür kılınması.
5. Sonra: maden tükenmesi, ardından tren (darboğazın harita ↔ fabrika arasında gidip gelmesi).

Ölçüt: çelik üretimi iki katına çıkınca en az şu kararlar doğmalı: yeni maden mi, mevcut maden mi; çelik
nerede işlensin; hangi yol yetmiyor; hangi kasabaya açılmalı.

## İlgili

- `ilerleme_motivasyon.md` — kasaba = laboratuvar, nüfus açılımları, baskı
- `hat_fabrikasi.md` — hat yuvalı yerleşke
- `denge.md` — üretim/taşıma dengesi
- `rotalar_okunabilirlik.md` — rotalar ve görünür okunabilirlik
