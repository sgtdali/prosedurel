# Sayı dengesi

1 oyun günü = 2 sn (1x). Kamyon hesapları trafiksiz, anayolda 42 px/sn, yükleme + boşaltma 3 sn.

## Çıpa (2026-09-30)

Oyunun başında **1 demir + 1 kömür madeni ≈ ~5 kamyon ≈ 1 dengeli birim** (1 yüksek fırın + 2 konvertör).
Önceden madenler kamyonlara göre ~10 kat hızlıydı (arz bedava, fabrika içi tek birimde doyuyordu), çelik birimi
1 dakikada kendini ödüyordu.

| Değer | Önce | Şimdi | Dosya |
| --- | --- | --- | --- |
| Demir / kömür / bakır madeni (günde) | 10 / 12 / 8 | 2 / 2 / 2 (= 1/sn) | economy/mining.gd `RATES` |
| Çelik satış fiyatı | 350 | 200 | economy/hauling.gd `SALE_PRICES` |

Makine ve bant hızları, kamyon kapasitesi (20), bina fiyatları, başlangıç parası (50.000) aynı kaldı.

## Tablo (şimdiki değerlerle)

| | Değer |
| --- | --- |
| Maden | 1 cevher/sn |
| Yüksek fırın | 1 demir + 0,5 kömür/sn → 0,5 pik/sn |
| Konvertör | 0,25 pik + 0,25 kömür/sn → 0,25 çelik/sn |
| Dengeli birim (1 fırın + 2 konvertör) | 1 demir + 1 kömür/sn → 0,5 çelik/sn = 100 para/sn = **6.000/ay** |
| Kamyon, 500 / 1000 / 2000 px | 0,75 / 0,40 / 0,20 birim/sn |
| Bir maden çifti (2 cevher/sn), 1000 px'te | ~5 kamyon (2,5 depo) |
| En küçük zincir (2 maden, 1 maden deposu, fabrika, fırın, 1 konvertör, bantlar, 1 lojistik + 1 satış deposu) | ~35.000 |
| Bu zincir, 1 kamyon cevher + 1 kamyon çelik ile (1000 px) | 0,1 çelik/sn = 1.200/ay |
| Her ek cevher kamyonu (depo başına 1.500) | +~0,1 çelik/sn = +1.200/ay, maden çifti ~5 kamyonda doyar |
| Doymuş birimden sonra büyümek (2 maden + makineler + kamyonlar) | ~30.000 → +6.000/ay (~5 dk'da öder) |

## Oynarken bakılacaklar

- Darboğaz yer değiştiriyor mu: önce kamyonlar yetmez (maden deposu dolar), kamyon eklenince maden ya da fabrika?
- Para: ilk zincirden sonra ne zaman bir sonraki adıma yetiyor, bekleme sıkıcı mı?
- Mesafe: yakın maden (az kamyon) ile uzak maden (çok kamyon) arasında gerçek bir seçim var mı?

## Kasaba talebi (2026-09-30, docs/kasaba_talebi.md)

| Değer | | Dosya |
| --- | --- | --- |
| Talep | ev × 2 çelik/ay (başta ~10 ev → ~20/ay) | economy/town_demand.gd `PER_HOUSE` |
| Talebe kadar / fazlası | 200 / 50 (%25) | `OVERFLOW_SHARE` |
| Talep karşılanan ay sonunda | +3 ev, en çok 60 (= 120/ay) | `GROWTH`, `MAX_HOUSES` |

Dengeli birim ayda 30 çelik: başta bir kasabayı ~1,5 kez doyurur; kasaba büyüdükçe (13 ev → 26/ay …) üretim
ve yeni kasabalar gerekir.
