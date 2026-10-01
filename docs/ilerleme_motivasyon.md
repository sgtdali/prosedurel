# İlerleme ve motivasyon (tasarım taslağı, 2026-10-01)

Soru: oyuncu neden oynamaya, büyümeye devam etsin? Oyun iki türün karışımı ve ikisinin motivasyonu farklı:

- **Factorio:** araştırma için üretim gerekir (yeni araştırma → yeni üretim ağı); zamanla düşman saldırıları
  oyuncuyu gelişmeye zorlar.
- **Transport Fever:** araştırma yok; yıllar geçtikçe ve toplam nüfus arttıkça yeni şeyler açılır.

Bu doküman ikisini tek bir ilerleme eksenine bağlayan öneriyi ve verilmesi gereken kararları toplar.
**Durum: temel ilerleme yönü ve uygulama sırası onaylandı; kararlar aşağıdaki kayıtta yer alır. Sayısal denge değerleri ve kalan davranış ayrıntıları açıktır.**

## Ana fikir: kasaba = araştırma laboratuvarı

Factorio'da bilim paketi laboratuvara gider, açılım gelir. Bizde mal kasabaya gider, kasaba büyür; **toplam
nüfus** (haritadaki tüm kasabalar) açılımları getirir.

- Ayrı araştırma binası/ekranı yok. "Araştırma için üret" hissi, kasabaları besleyerek gelir.
- Ürün ve teknoloji açılımları tüm harita için geçerlidir; yeni mal talebi ise her kasabanın kendi
  büyüklüğüne göre başlar. Bir ürünün açılması bütün kasabaların onu istemesi anlamına gelmez.
- Yıla bağlı açılım yok: oyuncunun emeğini ödüllendirmiyor.
- Açılımlar diğer katmanın darboğazını çözer (bkz. araç ilerlemesi): yeni araç → harita rahatlar, fabrika
  yetişemez; yeni makine → fabrika rahatlar, taşıma yetişemez.

### Örnek kademe tablosu (taslak)

| Kademe | Kasaba ne ister | Toplam nüfus eşiği açar |
|---|---|---|
| Köy | Çelik | (başlangıç) |
| Kasaba | + Makine parçası (çelik + bakır) | Makine parçası tarifi + üretim makinesi |
| Şehir | + Kablo (bakır) | 2. fabrika boyutu, gelişmiş splitter |
| Büyük şehir | + çok adımlı ürün | Tren |

Çelikten sonraki ikinci ürünün makine parçası, girdilerinin çelik ve bakır olması onaylandı.
İlk toplam nüfus açılımı, makine parçası tarifini ve onu üreten makineyi birlikte açar.
Diğer ürünler, kademe eşikleri ve sonraki açılım ödülleri taslaktır; denge `denge.md` ile birlikte belirlenecek.

## Öneri parçaları

### 1. Kasaba kartında "sonraki ihtiyaç"
Kasaba kartında mevcut talebin yanında sonraki mal **kilitli rozet** olarak görünür (ör. makine parçası 🔒,
"150 nüfusta açılır"). Oyuncu hedefi zaten baktığı yerde görür. Okunabilirlik kuralı: yazı değil ikon/rozet.
(Kaynak: ChatGPT önerisi.)

### 2. Yeni mal haritadan yeni girdi ister
Yeni mal sadece çelikten yapılırsa yalnız fabrika içi büyür, harita aynı kalır. Bu yüzden her yeni mal yeni bir
harita girdisi ister: makine parçası = çelik + **bakır** (bakır şu an boşta). Her kademe = fabrikada yeni zincir
+ haritada yeni maden, rota, kamyon.

### 3. Paylaştırma kararı
Aynı fabrikanın çeliği: satılsın mı, yeni mala mı dönüşsün? Fabrika içinde gerçek bir denge sorusu.
(Kaynak: ChatGPT önerisi.)

### 4. Düşman yerine baskı
- Her kasabanın seviyesine göre ürün başına aylık tüketim ihtiyacı bulunur. Teslimatlar bu ihtiyaçla
  karşılaştırılır; nüfus değişimi ihtiyacın karşılanma oranına bağlıdır.
- İlk denemede, bütün ürün ihtiyaçlarının **3 ay arka arkaya tamamen karşılanması** nüfus artışı
  sağlar: kasabaya **3 ev eklenir**. Her tam karşılanan ay büyüme serisini ilerletir; herhangi bir ürünün eksik kaldığı ay seri
  sıfırlanır. Ciddi eksiklikte nüfus yavaşça azalır; aradaki durumda nüfus sabit kalır.
- **İlk denemede**, ihtiyaç duyulan ürünler arasında karşılama oranı en düşük olan ürün kasabanın
  durumunu belirler. Büyüme için bütün ürün ihtiyaçları tam karşılanmalıdır; herhangi bir üründe ciddi
  eksiklik küçülmeye yol açar. Bir üründen fazla teslimat diğer üründeki eksikliği telafi etmez.
  En düşük karşılama oranı **%30 ve altındaysa** küçülme koşulu oluşur; **%30'un üstünde ve %100'ün
  altındaysa** nüfus sabit kalır. %100 ve üzeri karşılama büyüme serisini ilerletir. Bu yaklaşım denemede
  fazla sert çıkarsa yeniden değerlendirilecek.
- Küçülme, %30 ve altı karşılama oluşan **ilk ayın sonunda** başlar; ek bekleme süresi yoktur.
  Bu koşul devam ettiği her ay **1 ev azalır**; asgari nüfus sınırında durur.
- Küçülme kuralı oyunun başından itibaren bütün kasabalarda geçerlidir; oyuncunun kasabayı beslemeye
  başlaması beklenmez. Her kasabanın başlangıç seviyesini koruyan bir **asgari nüfus sınırı** vardır;
  nüfus bu sınırın altına düşemez.
- Nüfus artışıyla kazanılmış ürün ve teknoloji açılımları kalıcıdır; nüfus düşse de geri alınmaz.
  Yeni bir nüfus eşiğine ulaşmak için toplam nüfusu yeniden artırmak gerekir.
- Örnek değerler: aylık 10 çelik ihtiyacı; yalnızca 3 çelik teslimatı (%30 karşılama) yavaş küçülme.
  Aylık 10 çelik tüketimi örnektir. Büyüme süresi 3 ay ve küçülme eşiği %30 ve altı ilk deneme için
  onaylandı. Büyüme başına +3 ev ve yetersiz ay başına −1 ev ilk deneme değerleridir; asgari nüfus
  sınırının değeri ayrıca belirlenecek.
- Kademe atlayan kasaba eski malları istemeye devam eder; yeni ürün talepleri mevcut taleplere eklenir.
  Böylece önceki üretim ve taşıma hatları kullanılmaya devam eder. Kademe başına tüketim miktarları ayrıca belirlenecek.
- Kamyon başına aylık sabit bakım masrafı vardır; gider rota uzunluğuna veya kat edilen mesafeye bağlı
  değildir. Bakım tutarı ve ödeme yapılamadığında ne olacağı henüz açık.
- Açık öneri: fabrika bakım masrafı.

### 5. Oyuncu nüfusu neden ister?
Nüfus amaç değil araç:
1. **Pazar (asıl sebep):** talebe kadar ürünün tam fiyatı, fazlası tam fiyatın %25'i. Çelik için 200 / 50
   korunur. "Fazla üretiyorum, ucuza gidiyor" → büyüt.
2. **Açılımlar:** yeni mal = yeni, tam fiyatlı pazar.
3. **Görsel tatmin:** köy → kasaba → şehir görünümü (yardımcı).

Tuzak: baskı varken oyuncu "büyütmezsem başım ağrımaz" diyebilir. Talebi karşılamak her zaman aç bırakmaktan
belirgin şekilde kârlı olmalı (ayar: fiyat farkı ve yeni malın getirisi).

Para harcanacak yer bulmalı; döngünün bir halkası zayıfsa "bitti sanki oyun" hissi geri gelir.

### 6. Çok şehirli harita
Bir şehir doyunca baskı "kasabayı büyüt"ten **"başka şehre ulaş"a** dönüşür — haritanın görevi bu.
- Seçim: yakını büyüt (kısa rota, yavaş talep) ya da uzağa açıl (yeni satış deposu, uzun rota, yol).
- Kamyon bakım masrafı araç başına sabittir. Uzak şehre aynı teslimat hızını sağlamak için daha fazla
  kamyon gerekmesi, toplam aylık bakım giderini artırır. Yol yapımında yolun uzunluğuna göre bir defalık
  ücret alınır; birim ücret ayrıca belirlenecek. Başlangıç yol ağı 3 bağlantısız parça olduğundan yeni yol
  bağlantıları önemlidir.
- Toplam nüfus açılımı iki tarzı da ödüllendirir (bir büyük şehir ya da çok küçük şehir).
- Çok şehir doygunluğu erteler, kaldırmaz: ulaşılabilir şehirler doyunca yeni mal açmak doğal ihtiyaç olur.
  Erken oyun "yayıl", orta oyun "yeni mal aç".
- Temel ihtiyaçlar ortaktır; ileri ürün talepleri kasabaya göre farklılaşır. Çelik ve makine parçası ortak
  temel ürünlerdir. İleride aynı seviyedeki bir kasaba kablo, diğeri alet isteyebilir; bu ileri ürün isimleri
  örnektir. Hangi kasabayı büyütme ve hangi üretim zincirini kurma kararları birbirine bağlanır.
- Küçülme yerel kalır; oyuncu bazı şehirleri bilerek bırakabilir — öncelik kararı.

## Döngü

> Para → fabrika ve kamyon → üretim → pazar doyar → büyüt ya da yeni şehre açıl (yol, kamyon, masraf)
> → toplam nüfus yeni malı açar → yeterince büyümüş kasabalarda yeni pazar → yeni zincir, yeni rota

## Karar kaydı

| Konu | Karar | Alternatif | Gerekçe |
|---|---|---|---|
| A1 — Açılım sistemi (2026-10-01) | Yeni ürün ve teknolojiler, haritadaki tüm kasabaların toplam nüfus eşikleriyle açılır. Ayrı araştırma sistemi kullanılmaz. | Ayrı araştırma binası, arayüzü ve maliyeti | Üretim ve teslimatla sağlanan kasaba büyümesi, yeni üretim imkânlarını aynı ilerleme döngüsünde açar. |
| A2 — Talep kademeleri (2026-10-01) | Yeni mal talepleri kasaba bazındadır; her kasaba kendi büyüklüğüne göre yeni mal ister. | Ürün açılınca tüm kasabalarda yeni talep başlaması | Küçük kasabalara temel ürün taşıma ile büyük kasabalara daha çeşitli ürün sağlama farklı gelişim seçenekleri sunar. |
| B3 — Tüketim ve nüfus değişimi (2026-10-01) | Düzenli tam karşılama büyüme, düşük karşılama yavaş küçülme sağlar. Küçülme baştan bütün kasabalarda geçerlidir; nüfus başlangıç seviyesini koruyan asgari sınırın altına düşmez. Kazanılmış ürün ve teknolojiler geri alınmaz. | Yalnızca büyümenin durması; küçülmenin oyuncu beslemeye başladıktan sonra etkinleşmesi | Kasabaların gelişimi tedarike bağlı olur; başlangıç seviyesi ve kazanılmış geliştirmeler korunur. Sayısal değerler ayrıca belirlenecek. |
| B3a — Birden fazla ürünün değerlendirilmesi (2026-10-01, ilk deneme) | En az karşılanan ürün belirleyicidir: bütün ihtiyaçlar tam karşılanırsa büyüme süreci ilerler; herhangi bir ürün ciddi ölçüde eksikse küçülme, aradaki durumda sabit nüfus. | Ürünlerin karşılama oranlarının ortalamasını kullanmak | Fazla teslim edilen bir ürün diğer üründeki eksikliği kapatmaz; bütün zincirleri çalışır tutma ihtiyacı doğar. Denemeden sonra yeniden değerlendirilebilir. |
| B3b — Büyüme süresi (2026-10-01, ilk deneme) | Bütün ürün ihtiyaçları 3 ay üst üste tam karşılanınca nüfus artar. Eksik kalan ay büyüme serisini sıfırlar. | Farklı bir süre veya kesintiye rağmen serinin korunması | Büyüme tek seferlik yüksek teslimat yerine düzenli tedarikle kazanılır. |
| B3c — Küçülme eşiği (2026-10-01, ilk deneme) | En az karşılanan ürünün oranı %30 ve altındaysa küçülme koşulu oluşur. %30'un üstü ile %100'ün altı arasında nüfus sabit kalır; %100 ve üzeri büyüme serisini ilerletir. | Farklı bir küçülme eşiği | Ciddi tedarik eksikliği ile büyümeye yetmeyen kısmi tedarik ayrılır. |
| B3d — Küçülmenin başlaması (2026-10-01, ilk deneme) | %30 ve altı karşılama olan ilk ayın sonunda nüfus kaybı uygulanır. Koşul sürdüğü her ay küçülme devam eder; asgari nüfus sınırında durur. | Birkaç ay üst üste yetersiz tedarik beklemek | Ciddi tedarik eksikliği aylık küçük kayıplarla etkisini gösterir. |
| B3e — Nüfus değişim miktarları (2026-10-01, ilk deneme) | Mevcut ev sayısı üzerinden, 3 aylık tam karşılama tamamlanınca +3 ev; %30 ve altı karşılama olan her ay −1 ev uygulanır. Asgari sınır korunur. | Farklı artış/azalış miktarları | Gelişim görünür bir adım, gerileme yavaş bir süreç olur. Değerler denemeden sonra yeniden değerlendirilebilir. |
| B4 — Eski ürün talepleri (2026-10-01) | Kasaba kademe atladığında eski ürünleri istemeye devam eder; yeni talepler mevcut taleplere eklenir. | Eski ürün taleplerinin yerini yeni ürünün alması | Önceki üretim ve taşıma hatlarının değeri korunur; büyüme mevcut ağın üzerine yeni zincirler ekler. |
| C5 — Kamyon bakım masrafı (2026-10-01) | Kamyon başına aylık sabit bakım masrafı uygulanır. Rota uzunluğu veya kat edilen mesafe gideri doğrudan değiştirmez. | Bakım masrafı olmaması; mesafeye bağlı gider | Filo büyüdükçe düzenli gider artar; araç başına gider sabit ve anlaşılır kalır. Tutar ve ödenememe durumu ayrıca belirlenecek. |
| C6 — Yol yapım ücreti (2026-10-01) | Yol yapımında uzunluğa göre bir defalık ücret alınır. | Ücretsiz yol yapımı | Yeni kasabalara ulaşmak yatırım gerektirir; bağlantının maliyeti beklenen satış geliriyle birlikte değerlendirilir. Birim ücret ayrıca belirlenecek. |
| C7 — Talep fazlası satış fiyatı (2026-10-01) | Talebe kadar tam fiyat, talep fazlasına tam fiyatın %25'i ödenir. Çelik için 200 / 50 kuralı korunur. | Talep fazlasına tam fiyat ödenmesi veya fazlanın satın alınmaması | Fazla üretim gelir getirmeye devam ederken kasabayı büyütmek ve yeni pazarlara ulaşmak daha kazançlı olur. |
| D8 — İkinci ürün (2026-10-01) | Çelikten sonra makine parçası gelir; çelik ve bakırdan üretilir. | Farklı bir ikinci ürün veya yalnızca çelik kullanan tarif | Mevcut çeliği satış ile yeni üretim arasında paylaştırma kararı getirir; bakır üretimini ve taşımacılığını zincire ekler. Üretim makinesi ve tarif miktarları henüz açık. |
| D9 — İlk nüfus açılımı (2026-10-01) | Makine parçası tarifi ve onu üreten makine aynı toplam nüfus eşiğinde birlikte açılır. | Önce bir taşıma geliştirmesinin açılması | İlk çelik hattıyla sağlanan büyüme, doğrudan yeni bir üretim zinciri kurma imkânı verir. Eşik değeri ve makinenin türü ayrıca belirlenecek. |
| D10 — Kasabalar arasında ürün çeşitliliği (2026-10-01) | Çelik ve makine parçası gibi temel ihtiyaçlar ortaktır; ileri ürün talepleri kasabaya göre farklılaşır. | Aynı seviyedeki bütün kasabaların aynı ürünleri istemesi | Oyuncu büyüteceği kasabayı konumuyla birlikte gerektirdiği üretim zincirine göre seçer. İleri ürünler ve kasabalara dağılımı ayrıca belirlenecek. |
| E11 — Uygulama sırası (2026-10-01) | Kasaba tüketimi ve nüfus → ilk nüfus açılımı ve makine parçası zinciri → hedeflerin görünmesi → ekonomi giderleri ve oynanış denemesi. | Bakım masrafıyla başlayıp yeni üretim açılımını daha sonra eklemek | Kasaba büyümesinin yeni üretim kurma isteği doğurup doğurmadığı erken değerlendirilir. |

## Karar verilmesi gerekenler

**B. Baskı**

3. Asgari nüfus sınırı ne olsun?

**C. Ekonomi ve mesafe**

5. Sabit kamyon bakım tutarı ve bakım ödenemediğinde uygulanacak kural ne olsun?
6. Yol yapımının birim ücreti ne olsun?

**D. İçerik**

8. Makine parçasının üretim makinesi ve tarif miktarları ne olsun?
9. İlk toplam nüfus eşiği ve sonraki açılımların sırası ne olsun?
10. İleri ürünler ve kasabalar arasındaki talep dağılımı nasıl belirlensin?

## Uygulama sırası (onaylı)

1. **Kasaba tüketimi ve nüfus:** düzenli karşılamayla büyüme, eksiklikte küçülme, asgari nüfus sınırı.
2. **İlk ilerleme döngüsü:** toplam nüfusla makine parçası tarifi ve üretim makinesinin birlikte açılması;
   yeterince büyüyen kasabalarda makine parçası talebinin başlaması ve üretim/teslimat zinciri.
3. **Hedeflerin görünmesi:** kasaba kartında tüketim oranları, büyüme durumu ve sonraki ihtiyaç;
   toplam nüfusun sonraki açılıma uzaklığı.
4. **Ekonomi ve deneme:** sabit kamyon bakımı, uzunluğa göre bir defalık yol yapım ücreti ve ardından
   20–30 dakikalık oynanış denemesi.

Değerlendirilecek döngü: "Kasabayı büyüttüm → yeni üretim açıldı → yeni hattı kurmak istiyorum."

## İlgili

- `kasaba_talebi.md` — mevcut talep ve büyüme kuralları
- `denge.md` — üretim/taşıma dengesi
- `fabrika_ici.md` — fabrika içi bant zincirleri
- Araç ilerlemesi (kamyon → büyük kamyon → tren): darboğaz harita ↔ fabrika arasında gidip gelir; çekirdek
  döngü oturunca ele alınacak.
