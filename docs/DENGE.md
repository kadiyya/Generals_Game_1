# Birim değerleri (koddan üretildi)

Bu dosya `tools/balance.gd` ile üretilir; elle değiştirme. Değerler `scripts/scenarios.gd` içindeki sınıf,
ülke ve doktrin tablolarından gelir. **Saniyede hasar (SnH)**: hasar ÷ atış aralığı × zırh çarpanı
(paket birimlerde adetle çarpılır). Kamikazelerde tek vuruş hasarı yazılır. Fiyat doktrin indirimi/cezasıyla.

Zırh sınıfları: piyade, hafif zırh (zırhlı araç, topçu, hava savunma araçları), tank, bina, uçak/İHA (büyük),
küçük dron. Hız birim/sn (piyade %10 artırılmış, kara araçları %5 düşürülmüş hâliyle).

## Sınıflar

| Sınıf | Tür | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| inf | Kara | 150 | 260 | 3.7 | 14 | 8 | 10 / 0.50 sn | 20 | 12 | 3 | 6 | – | 5 | nokta alır |
| at | Kara | 220 | 180 | 3.7 | 14 | 12 | 70 / 3.00 sn | 3 | 30 | 37 | 12 | – | – |  |
| ifv | Kara | 380 | 620 | 4.9 | 15 | 9 | 16 / 0.40 sn | 48 | 32 | 14 | 16 | – | 12 |  |
| tank | Kara | 700 | 1100 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| arty | Kara | 900 | 520 | 2.8 | 12 | 34 | 110 / 5.00 sn | 18 | 15 | 13 | 35 | – | – | alan 3.5; en az 9; kovalamaz |
| mlrs | Kara | 1100 | 420 | 3.4 | 12 | 42 | 95 / 8.00 sn | 14 | 12 | 5 | 14 | – | – | alan 7.5; en az 12; kovalamaz |
| spaag | Hava savunma | 550 | 560 | 4.0 | 14 | 14 | 22 / 0.35 sn | 69 | 47 | 9 | 16 | 38 | 63 |  |
| laser | Hava savunma | 1400 | 500 | 3.4 | 16 | 18 | 60 / 0.60 sn | 90 | 65 | 15 | 20 | 50 | 300 |  |
| ads | Hava savunma | 950 | 950 | 3.7 | 20 | 25 | 150 / 2.60 sn | 32 | 38 | 14 | 17 | 74 | 9 |  |
| ew | Hava savunma | 650 | 480 | 3.8 | 16 | – | – | – | – | – | – | – | – | EH 16: küçük dronları düşürür, büyükleri karıştırır |
| sdrone_recon | Hava | 120 | 40 | 6.0 | 30 | – | – | – | – | – | – | – | – |  |
| sdrone_fpv | Hava | 200 | 25 | 7.5 | 11 | – | 130 | 312 | 468 | 312 | 117 | – | – | kamikaze (SnH = tek vuruş); 3'li paket; uçuş 70 sn |
| sdrone_bomb | Hava | 320 | 70 | 5.0 | 20 | 3 | 90 / 2.00 sn | 54 | 45 | 27 | 22 | – | – | alan 2.5; 2 mühimmat |
| loiter | Hava | 260 | 35 | 8.5 | 15 | – | 280 | 112 | 364 | 280 | 112 | – | – | kamikaze (SnH = tek vuruş); uçuş 110 sn |
| uav_recon | Hava | 450 | 260 | 8.0 | 50 | – | – | – | – | – | – | – | – |  |
| uav_strike | Hava | 800 | 220 | 7.0 | 32 | 11 | 160 / 3.50 sn | 27 | 55 | 46 | 37 | – | – | 2 mühimmat |
| uav_heavy | Hava | 1300 | 340 | 7.5 | 36 | 13 | 190 / 3.00 sn | 38 | 76 | 70 | 63 | – | – | 4 mühimmat |
| uav_kami | Hava | 320 | 90 | 6.5 | 14 | – | 380 | 228 | 380 | 228 | 570 | – | – | kamikaze (SnH = tek vuruş); alan 3.0 |
| fighter | Hava | 1500 | 380 | 13.0 | 22 | 15 | 100 / 2.00 sn | 20 | 50 | 45 | 45 | 60 | 15 | 4 mühimmat |
| striker | Hava | 1800 | 470 | 12.0 | 22 | 14 | 195 / 2.50 sn | 62 | 94 | 86 | 109 | – | – | alan 3.0; 3 mühimmat |
| stealth | Hava | 2600 | 400 | 14.0 | 24 | 16 | 165 / 2.00 sn | 41 | 91 | 82 | 107 | 107 | 25 | 4 mühimmat; görünmez |

## Silahlı bina

Hava Savunma binası: can 800, menzil 26, 140 hasar / 3.0 sn. SnH: piyade 26, hafif zırh 33, tank 15, bina 14, uçak/İHA 37, küçük dron 14. Balistik füze önleme çarpanı 1.00.

## Ukrayna — İHA Doktrini

Küçük dronlar %40, büyük İHA'lar %30 ucuz. Tank yok; zırhlı, topçu ve uçaklar %30-60 pahalı. Ülke farkı: dronlar zırhlılara %15 fazla vurur.


Yetenek: **Sürü Saldırısı** ($600, 120 sn bekleme) — Görülen bir noktaya, en yakın birliğinden 8 FPV dronu birden fırlatır. Hava savunmasını doyurur.

| Birim | Sınıf | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Piyade Mangası | inf | 150 | 260 | 3.7 | 14 | 8 | 10 / 0.50 sn | 20 | 12 | 3 | 6 | – | 5 | nokta alır |
| Javelin Timi | at | 220 | 180 | 3.7 | 14 | 12 | 70 / 3.00 sn | 3 | 30 | 37 | 12 | – | – |  |
| Bukovel-AD | ew | 650 | 480 | 3.8 | 16 | – | – | – | – | – | – | – | – | EH 16: küçük dronları düşürür, büyükleri karıştırır |
| DJI Mavic 3 | sdrone_recon | 72 | 40 | 6.0 | 30 | – | – | – | – | – | – | – | – |  |
| FPV Kamikaze | sdrone_fpv | 120 | 25 | 7.5 | 11 | – | 130 | 312 | 538 | 359 | 117 | – | – | kamikaze (SnH = tek vuruş); 3'li paket; uçuş 70 sn |
| Baba Yaga | sdrone_bomb | 192 | 70 | 5.0 | 20 | 3 | 90 / 2.00 sn | 54 | 52 | 31 | 22 | – | – | alan 2.5; 2 mühimmat |
| Switchblade 600 | loiter | 156 | 35 | 8.5 | 15 | – | 280 | 112 | 419 | 322 | 112 | – | – | kamikaze (SnH = tek vuruş); uçuş 110 sn |
| M2 Bradley | ifv | 494 | 620 | 4.9 | 15 | 9 | 16 / 0.40 sn | 48 | 32 | 14 | 16 | – | 12 |  |
| Gepard | spaag | 660 | 560 | 4.0 | 14 | 14 | 22 / 0.35 sn | 69 | 47 | 9 | 16 | 38 | 63 |  |
| Buk-M1 | ads | 950 | 950 | 3.7 | 20 | 25 | 150 / 2.60 sn | 32 | 38 | 14 | 17 | 74 | 9 |  |
| M142 HIMARS | mlrs | 1430 | 420 | 3.4 | 12 | 42 | 95 / 8.00 sn | 14 | 12 | 5 | 14 | – | – | alan 7.5; en az 12; kovalamaz |
| Bayraktar TB2 | uav_strike | 560 | 220 | 7.0 | 32 | 11 | 160 / 3.50 sn | 27 | 63 | 53 | 37 | – | – | 2 mühimmat |
| AN-196 Liutyi | uav_kami | 224 | 90 | 6.5 | 14 | – | 380 | 228 | 437 | 262 | 570 | – | – | kamikaze (SnH = tek vuruş); alan 3.0 |
| F-16 | fighter | 2250 | 380 | 13.0 | 22 | 15 | 100 / 2.00 sn | 20 | 50 | 45 | 45 | 60 | 15 | 4 mühimmat |
| Su-24M (Storm Shadow) | striker | 2880 | 470 | 12.0 | 22 | 14 | 195 / 2.50 sn | 62 | 94 | 86 | 109 | – | – | alan 3.0; 3 mühimmat |
| Peklo Füze-Drone (deneysel) | uav_kami | 735 | 143 | 10.0 | 14 | – | 630 | 378 | 724 | 435 | 945 | – | – | kamikaze (SnH = tek vuruş); alan 3.0 |

Füzeler: Hrim-2 ($1690, 1170 hasar, alan 7.0, 70 sn)

## Rusya — Zırhlı / Topçu

Tank ve topçu %20-25 ucuz ve daha dayanıklı. Dronlar ve İHA'lar %40 pahalı.


Yetenek: **Topçu Barajı** ($700, 120 sn bekleme) — Görülen bir alana 7 saniye boyunca 14 ağır top mermisi yağdırır. Siperleri ve toplu piyadeyi dağıtır.

| Birim | Sınıf | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Motorize Piyade | inf | 150 | 260 | 3.7 | 14 | 8 | 10 / 0.50 sn | 20 | 12 | 3 | 6 | – | 5 | nokta alır |
| Kornet Timi | at | 220 | 180 | 3.7 | 14 | 12 | 70 / 3.00 sn | 3 | 30 | 37 | 12 | – | – |  |
| Silok | ew | 650 | 480 | 3.8 | 16 | – | – | – | – | – | – | – | – | EH 16: küçük dronları düşürür, büyükleri karıştırır |
| Orlan-10 | sdrone_recon | 156 | 40 | 6.0 | 30 | – | – | – | – | – | – | – | – |  |
| FPV Kamikaze | sdrone_fpv | 280 | 25 | 7.5 | 11 | – | 130 | 312 | 468 | 312 | 117 | – | – | kamikaze (SnH = tek vuruş); 3'li paket; uçuş 70 sn |
| Lancet-3 | loiter | 364 | 35 | 8.5 | 15 | – | 280 | 112 | 364 | 280 | 112 | – | – | kamikaze (SnH = tek vuruş); uçuş 110 sn |
| BMP-3 | ifv | 323 | 620 | 4.9 | 15 | 9 | 16 / 0.40 sn | 48 | 32 | 14 | 16 | – | 12 |  |
| T-72B3 | tank | 525 | 1320 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| T-90M | tank | 638 | 1560 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| Pantsir-S1 | spaag | 550 | 560 | 4.0 | 14 | 14 | 22 / 0.35 sn | 69 | 47 | 9 | 16 | 38 | 63 |  |
| Buk-M3 | ads | 950 | 950 | 3.7 | 20 | 25 | 150 / 2.60 sn | 32 | 38 | 14 | 17 | 74 | 9 |  |
| 2S19 Msta-S | arty | 720 | 624 | 2.8 | 12 | 34 | 110 / 5.00 sn | 18 | 15 | 13 | 35 | – | – | alan 3.5; en az 9; kovalamaz |
| Tornado-S | mlrs | 880 | 504 | 3.4 | 12 | 42 | 95 / 8.00 sn | 14 | 12 | 5 | 14 | – | – | alan 7.5; en az 12; kovalamaz |
| Orion | uav_strike | 1120 | 220 | 7.0 | 32 | 11 | 160 / 3.50 sn | 27 | 55 | 46 | 37 | – | – | 2 mühimmat |
| Geran-2 | uav_kami | 448 | 90 | 6.5 | 14 | – | 380 | 228 | 380 | 228 | 570 | – | – | kamikaze (SnH = tek vuruş); alan 3.0 |
| Su-35 | fighter | 1725 | 380 | 13.0 | 22 | 15 | 100 / 2.00 sn | 20 | 50 | 45 | 45 | 60 | 15 | 4 mühimmat |
| Su-34 | striker | 1980 | 470 | 12.0 | 22 | 14 | 195 / 2.50 sn | 62 | 94 | 86 | 109 | – | – | alan 3.0; 3 mühimmat |
| Su-57 (deneysel) | stealth | 3900 | 520 | 14.0 | 24 | 16 | 247 / 2.00 sn | 62 | 136 | 124 | 161 | 161 | 37 | 4 mühimmat; görünmez |
| S-70 Okhotnik-B (deneysel) | uav_heavy | 3990 | 546 | 7.5 | 36 | 13 | 285 / 3.00 sn | 57 | 114 | 105 | 95 | – | – | 4 mühimmat; görünmez |
| T-14 Armata (deneysel) | tank | 1238 | 2262 | 4.0 | 14 | 10 | 112 / 2.20 sn | 41 | 61 | 51 | 51 | – | – |  |

Füzeler: İskender-M ($1690, 1235 hasar, alan 7.0, 70 sn)

## İsrail — Hava Üstünlüğü

Uçaklar %30 ucuz ve hızlı silahlanır, İHA'lar ucuz. Tank ve topçu %35-40 pahalı.


Yetenek: **Hava Akını** ($900, 150 sn bekleme) — İki bombardıman uçağı üssünden kalkar, görülen hedefe alçaktan girip 12 bomba bırakır ve geri döner. Hava alanı gerekmez. Hava savunması uçakları düşürebilir: düşen uçağın bombaları düşmez.

| Birim | Sınıf | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Piyade Mangası | inf | 150 | 260 | 3.7 | 14 | 8 | 10 / 0.50 sn | 20 | 12 | 3 | 6 | – | 5 | nokta alır |
| Spike Timi | at | 220 | 180 | 3.7 | 14 | 12 | 70 / 3.00 sn | 3 | 30 | 37 | 12 | – | – |  |
| Drone Dome | ew | 650 | 480 | 3.8 | 16 | – | – | – | – | – | – | – | – | EH 16: küçük dronları düşürür, büyükleri karıştırır |
| Orbiter | sdrone_recon | 120 | 40 | 6.0 | 30 | – | – | – | – | – | – | – | – |  |
| Hero-30 | loiter | 260 | 35 | 8.5 | 15 | – | 280 | 112 | 364 | 280 | 112 | – | – | kamikaze (SnH = tek vuruş); uçuş 110 sn |
| Namer | ifv | 528 | 760 | 4.9 | 15 | 9 | 16 / 0.40 sn | 48 | 32 | 14 | 16 | – | 12 |  |
| Merkava Mk 4 | tank | 1053 | 1250 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| Iron Dome | spaag | 550 | 560 | 3.0 | 14 | 17 | 65 / 1.00 sn | 72 | 49 | 10 | 16 | 39 | 65 |  |
| Machbet | ads | 950 | 950 | 3.7 | 20 | 25 | 150 / 2.60 sn | 32 | 38 | 14 | 17 | 74 | 9 |  |
| ATMOS 2000 | arty | 1260 | 520 | 2.8 | 12 | 34 | 110 / 5.00 sn | 18 | 15 | 13 | 35 | – | – | alan 3.5; en az 9; kovalamaz |
| Heron TP | uav_recon | 383 | 260 | 8.0 | 50 | – | – | – | – | – | – | – | – |  |
| Hermes 900 | uav_strike | 680 | 220 | 7.0 | 32 | 11 | 160 / 3.50 sn | 27 | 55 | 46 | 37 | – | – | 2 mühimmat |
| Harop | uav_kami | 320 | 90 | 6.5 | 14 | – | 380 | 228 | 380 | 228 | 570 | – | – | kamikaze (SnH = tek vuruş); alan 3.0 |
| F-16I Sufa | fighter | 1050 | 380 | 13.0 | 22 | 15 | 100 / 2.00 sn | 20 | 50 | 45 | 45 | 60 | 15 | 4 mühimmat |
| F-15I Ra'am | striker | 1260 | 470 | 12.0 | 22 | 14 | 195 / 2.50 sn | 62 | 94 | 86 | 109 | – | – | alan 3.0; 3 mühimmat |
| F-35I Adir (deneysel) | stealth | 2925 | 520 | 14.0 | 24 | 16 | 247 / 2.00 sn | 62 | 136 | 124 | 161 | 161 | 37 | 4 mühimmat; görünmez |
| Merkava Barak (deneysel) | tank | 2228 | 1885 | 4.0 | 14 | 10 | 112 / 2.20 sn | 41 | 61 | 51 | 51 | – | – |  |

Füzeler: LORA ($1690, 1170 hasar, alan 6.5, 70 sn)

## İran — Balistik Füze

Füzeler %40 ucuz, çabuk hazır; Füze Üssü Kademe 2'de açılır. Kamikaze İHA'lar ucuz. Zırhlı ve uçaklar %35-40 pahalı.


Yetenek: **Doyurma Salvosu** ($1600, 180 sn bekleme) — Görülen bir noktaya aynı anda 4 balistik füze atar. Hava savunması her atışta yalnızca bir füzeye yetişir: doyurur.

| Birim | Sınıf | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Piyade Mangası | inf | 150 | 260 | 3.7 | 14 | 8 | 10 / 0.50 sn | 20 | 12 | 3 | 6 | – | 5 | nokta alır |
| Dehlaviyeh Timi | at | 220 | 180 | 3.7 | 14 | 12 | 70 / 3.00 sn | 3 | 30 | 37 | 12 | – | – |  |
| Kobra V8 | ew | 650 | 480 | 3.8 | 16 | – | – | – | – | – | – | – | – | EH 16: küçük dronları düşürür, büyükleri karıştırır |
| Ababil-2 | sdrone_recon | 120 | 40 | 6.0 | 30 | – | – | – | – | – | – | – | – |  |
| Meraj-521 | loiter | 221 | 35 | 8.5 | 15 | – | 280 | 112 | 364 | 280 | 112 | – | – | kamikaze (SnH = tek vuruş); uçuş 110 sn |
| Shahed-131 | sdrone_fpv | 176 | 25 | 7.5 | 11 | – | 170 | 272 | 408 | 272 | 102 | – | – | kamikaze (SnH = tek vuruş); 2'li paket; uçuş 70 sn |
| Boragh | ifv | 456 | 558 | 4.9 | 15 | 9 | 16 / 0.40 sn | 48 | 32 | 14 | 16 | – | 12 |  |
| Karrar | tank | 945 | 990 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| Tor-M1 | spaag | 550 | 560 | 4.0 | 14 | 14 | 60 / 1.00 sn | 66 | 45 | 9 | 15 | 36 | 60 |  |
| Herz-9 | ads | 950 | 950 | 3.7 | 20 | 25 | 150 / 2.60 sn | 32 | 38 | 14 | 17 | 74 | 9 |  |
| Fajr-5 | mlrs | 1100 | 420 | 3.4 | 12 | 42 | 95 / 8.00 sn | 14 | 12 | 5 | 14 | – | – | alan 7.5; en az 12; kovalamaz |
| Mohajer-6 | uav_strike | 800 | 220 | 7.0 | 32 | 11 | 160 / 3.50 sn | 27 | 55 | 46 | 37 | – | – | 2 mühimmat |
| Shahed-129 | uav_heavy | 1300 | 340 | 7.5 | 36 | 13 | 190 / 3.00 sn | 38 | 76 | 70 | 63 | – | – | 4 mühimmat |
| Shahed-136 | uav_kami | 224 | 90 | 6.5 | 14 | – | 380 | 228 | 380 | 228 | 570 | – | – | kamikaze (SnH = tek vuruş); alan 3.0 |
| F-14A Tomcat | fighter | 2100 | 380 | 13.0 | 22 | 15 | 100 / 2.00 sn | 20 | 50 | 45 | 45 | 60 | 15 | 4 mühimmat |
| Su-24MK | striker | 2520 | 470 | 12.0 | 22 | 14 | 195 / 2.50 sn | 62 | 94 | 86 | 109 | – | – | alan 3.0; 3 mühimmat |
| Shahed-238 (jet) (deneysel) | uav_kami | 735 | 143 | 11.0 | 14 | – | 660 | 396 | 660 | 396 | 990 | – | – | kamikaze (SnH = tek vuruş); alan 3.0 |

Füzeler: Fateh-110 ($480, 600 hasar, alan 6.0, 27 sn), Sejjil ($1170, 1430 hasar, alan 8.0, 48 sn), Fattah-2 ($1872, 1560 hasar, alan 7.0, 66 sn, hipersonik)

## Pakistan — Balistik Füze

Füzeler %40 ucuz, çabuk hazır; Füze Üssü Kademe 2'de açılır. Kamikaze İHA'lar ucuz. Zırhlı ve uçaklar %35-40 pahalı.


Yetenek: **Doyurma Salvosu** ($1600, 180 sn bekleme) — Görülen bir noktaya aynı anda 4 balistik füze atar. Hava savunması her atışta yalnızca bir füzeye yetişir: doyurur.

| Birim | Sınıf | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Piyade Mangası | inf | 150 | 260 | 3.7 | 14 | 8 | 10 / 0.50 sn | 20 | 12 | 3 | 6 | – | 5 | nokta alır |
| Baktar-Shikan Timi | at | 220 | 180 | 3.7 | 14 | 12 | 70 / 3.00 sn | 3 | 30 | 37 | 12 | – | – |  |
| EH Karıştırıcı | ew | 650 | 480 | 3.8 | 16 | – | – | – | – | – | – | – | – | EH 16: küçük dronları düşürür, büyükleri karıştırır |
| Uqab | sdrone_recon | 120 | 40 | 6.0 | 30 | – | – | – | – | – | – | – | – |  |
| Talha | ifv | 456 | 558 | 4.9 | 15 | 9 | 16 / 0.40 sn | 48 | 32 | 14 | 16 | – | 12 |  |
| Al-Khalid | tank | 945 | 990 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| VT-4 Haider | tank | 1148 | 1170 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| FM-90 | spaag | 550 | 560 | 4.0 | 14 | 14 | 60 / 1.00 sn | 66 | 45 | 9 | 15 | 36 | 60 |  |
| HQ-16FE | ads | 950 | 950 | 3.7 | 20 | 25 | 150 / 2.60 sn | 32 | 38 | 14 | 17 | 74 | 9 |  |
| A-100 | mlrs | 1100 | 420 | 3.4 | 12 | 42 | 95 / 8.00 sn | 14 | 12 | 5 | 14 | – | – | alan 7.5; en az 12; kovalamaz |
| Shahpar-II | uav_recon | 450 | 260 | 8.0 | 50 | – | – | – | – | – | – | – | – |  |
| Burraq | uav_strike | 800 | 220 | 7.0 | 32 | 11 | 160 / 3.50 sn | 27 | 55 | 46 | 37 | – | – | 2 mühimmat |
| Akıncı | uav_heavy | 1300 | 340 | 7.5 | 36 | 13 | 190 / 3.00 sn | 38 | 76 | 70 | 63 | – | – | 4 mühimmat |
| J-10C | fighter | 2310 | 380 | 13.0 | 22 | 15 | 110 / 2.00 sn | 22 | 55 | 50 | 50 | 66 | 16 | 4 mühimmat |
| JF-17 Block III | striker | 2520 | 470 | 12.0 | 22 | 14 | 195 / 2.50 sn | 62 | 94 | 86 | 109 | – | – | alan 3.0; 3 mühimmat |
| J-35 (deneysel) | stealth | 5460 | 520 | 14.0 | 24 | 16 | 247 / 2.00 sn | 62 | 136 | 124 | 161 | 161 | 37 | 4 mühimmat; görünmez |

Füzeler: Nasr ($420, 500 hasar, alan 6.0, 24 sn), Shaheen-II ($1170, 1430 hasar, alan 8.0, 48 sn), Fatah-IV ($1716, 1300 hasar, alan 6.0, 60 sn, hipersonik)

## Hindistan — Dengeli / İnsan Gücü

Piyade %35, tanksavar %25 ucuz, birlik sınırı yüksek. Pahalı doktrin cezası yok.


Yetenek: **Seferberlik** ($400, 150 sn bekleme) — Karargâhın yanında anında 4 piyade mangası toplar (birlik sınırı izin verdiği kadar).

| Birim | Sınıf | Fiyat | Can | Hız | Görüş | Menzil | Hasar / aralık | SnH: piyade | hafif | tank | bina | uçak | dron | Not |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Piyade Mangası | inf | 98 | 260 | 3.7 | 14 | 8 | 10 / 0.50 sn | 20 | 12 | 3 | 6 | – | 5 | nokta alır |
| Nag Timi | at | 165 | 180 | 3.7 | 14 | 12 | 70 / 3.00 sn | 3 | 30 | 37 | 12 | – | – |  |
| D4 Drone Sistemi | ew | 650 | 480 | 3.8 | 16 | – | – | – | – | – | – | – | – | EH 16: küçük dronları düşürür, büyükleri karıştırır |
| Switch UAV | sdrone_recon | 120 | 40 | 6.0 | 30 | – | – | – | – | – | – | – | – |  |
| Nagastra-1 | loiter | 260 | 35 | 8.5 | 15 | – | 280 | 112 | 364 | 280 | 112 | – | – | kamikaze (SnH = tek vuruş); uçuş 110 sn |
| BMP-2 Sarath | ifv | 342 | 620 | 4.9 | 15 | 9 | 16 / 0.40 sn | 48 | 32 | 14 | 16 | – | 12 |  |
| T-90S Bhishma | tank | 700 | 1100 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| Arjun Mk1A | tank | 880 | 1350 | 4.0 | 14 | 10 | 75 / 2.20 sn | 27 | 41 | 34 | 34 | – | – |  |
| ZSU-23-4 Shilka | spaag | 550 | 560 | 4.0 | 14 | 14 | 22 / 0.35 sn | 69 | 47 | 9 | 16 | 38 | 63 |  |
| Akash | ads | 950 | 950 | 3.7 | 20 | 25 | 150 / 2.60 sn | 32 | 38 | 14 | 17 | 74 | 9 |  |
| Pinaka | mlrs | 1100 | 420 | 3.4 | 12 | 42 | 95 / 8.00 sn | 14 | 12 | 5 | 14 | – | – | alan 7.5; en az 12; kovalamaz |
| Heron | uav_recon | 450 | 260 | 8.0 | 50 | – | – | – | – | – | – | – | – |  |
| Harop | uav_kami | 320 | 90 | 6.5 | 14 | – | 380 | 228 | 380 | 228 | 570 | – | – | kamikaze (SnH = tek vuruş); alan 3.0 |
| MQ-9B | uav_heavy | 1300 | 340 | 7.5 | 36 | 13 | 190 / 3.00 sn | 38 | 76 | 70 | 63 | – | – | 4 mühimmat |
| Rafale | fighter | 1750 | 380 | 13.0 | 22 | 15 | 115 / 2.00 sn | 23 | 58 | 52 | 52 | 69 | 17 | 4 mühimmat |
| Su-30MKI | striker | 1800 | 520 | 12.0 | 22 | 14 | 195 / 2.50 sn | 62 | 94 | 86 | 109 | – | – | alan 3.0; 3 mühimmat |
| Ghatak (deneysel) | uav_heavy | 2850 | 546 | 7.5 | 36 | 13 | 285 / 3.00 sn | 57 | 114 | 105 | 95 | – | – | 4 mühimmat; görünmez |

Füzeler: Pralay ($1690, 1170 hasar, alan 7.0, 70 sn), BrahMos ($2600, 1300 hasar, alan 5.5, 95 sn, hipersonik)
