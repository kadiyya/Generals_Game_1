# Oyun Tasarımı (v0.2)

Android için gerçek zamanlı strateji. Günümüz silahları, gerçek adlar, low-poly 3D.
Bu doküman oyunun hedefini anlatır. Bugün neyin çalıştığı için bölüm 12'ye bak.

Önceki sürüm: [OYNANIS.md](OYNANIS.md) (v0.1, artık yalnızca tarihçe).

## 1. İlkeler

1. **Hızlı olan değil, doğru karar veren kazanır.** Oyun yavaş akar, duraklatılıp emir verilebilir.
2. **Birim üretmek de kaybetmek de kolay değil.** Birimler pahalı ve dayanıklıdır; geri çekilip onarılabilir (Company of Heroes etkisi).
3. **Görmediğini vuramazsın.** Keşif oyunun merkezindedir.
4. **Arazi önemlidir.** Dağlar, nehirler, köprüler ve deniz, geçitleri ve taktiği belirler.
5. **Her ülke kendi silahlarını kullanır.** Adlar doğrudan gerçek adlardır (F-16, F-35, T-90M).
6. **Doktrin, avantajın kaynağıdır.** Gerçek dünyadaki İHA savaşları, balistik füzeler ve hava gücü örnek alınır.
7. Para birimi dolardır. Şimdilik tek oyunculu; kara ve hava var, deniz sonra eklenecek.

## 2. Ekonomi

| Kaynak | Açıklama |
|---|---|
| Karargâh | Sabit gelir |
| İkmal noktası / petrol tesisi | Piyade ele geçirir; haritada kazancı `+$5/sn` gibi yazar |
| Kaynak binası | Maden ocağı, rafineri: doğrudan periyodik para kazandırır |
| Santral | Enerji üretir; gelişmiş binalar enerji ister |

## 3. Binalar

Binalar hazır yuvalara değil, **inşa bölgesinde istenen yere** kurulur.

| Bina | İşlev |
|---|---|
| Ana bina (Karargâh) | Vinç çıkarır. Vinç sayısı aynı anda kaç inşaat yürüdüğünü belirler |
| Piyade kışlası | Piyade ve elden atılan küçük İHA timleri |
| Fabrika | Tank ve mekanize birlikler, topçu, hareketli hava savunma |
| Hava alanı | Uçaklar ve büyük İHA'lar. Pist sayısı uçak sayısını sınırlar |
| Kaynak binası | Periyodik para |
| Santral | Enerji |
| Hava savunma | Sabit (bina) ya da hareketli (araç) olabilir |
| Teknoloji merkezi | Araştırmalar ve kademe yükseltme |
| Füze üssü | Balistik ve seyir füzeleri (doktrine bağlı) |

### Teknoloji merkezi araştırmaları (güncel konular)

| Araştırma | Etki |
|---|---|
| Fiber optik FPV | Küçük İHA'lar elektronik karıştırmadan etkilenmez |
| Elektronik harp (karıştırıcı) | Çevredeki düşman küçük İHA'ları düşer ya da sapar |
| Drone kafesi ve reaktif zırh | Zırhlılar kamikaze İHA'dan daha az hasar alır |
| Aktif koruma sistemi | Tanklar gelen ilk tanksavar füzesini savuşturur |
| Yapay zekâ hedef tanıma | İHA'lar hedefi daha uzaktan ve daha hızlı bulur |
| Sürü yapay zekâsı | Kamikaze sürüleri hava savunmayı paylaşarak doyurur |
| AESA radar | Uçakların ve hava savunmanın tespit menzili artar |
| Karşı batarya radarı | Ateş eden düşman topçusu haritada görünür |
| Güdümlü topçu mermisi | Obüslerin isabeti artar |
| Düşük görünürlük kaplaması | Görünmez uçaklar daha geç tespit edilir |
| Hipersonik süzülme | Balistik füzeler hava savunmayı daha kolay aşar |

## 4. Birim sınıfları

### Kara
- **Piyade:** nokta ele geçirir, ucuz. Tanksavar ve omuzdan atılan hava savunma timleri ayrıdır.
- **Hafif zırhlı araç:** hızlı, piyadeye karşı güçlü.
- **Tank:** araçlara ve binalara güçlü; makineli tüfeğiyle piyadeye de ateş eder.
- **Obüs ve top:** uzun menzil; hedefi başka bir birimin görmesi gerekir.
- **Çok namlulu roketatar:** alan hasarı.

### İHA'lar: iki sınıf

| Sınıf | Nereden çıkar | Özellik |
|---|---|---|
| **Küçük** (FPV, kamikaze, quadcopter) | Piyade kışlası; elden atılır | Ucuz, çok sayıda, az hasar, kısa menzil. Elektronik harbe duyarlı |
| **Büyük** (TB2, Akıncı, Global Hawk, Reaper) | **Hava alanı gerekir** | Pahalı, uzun menzil, güdümlü mühimmat ya da geniş keşif |

### Uçaklar
Hava alanından kalkar, görev alır (taarruz, hava devriyesi), mühimmatı bitince dönüp silahlanır.
Görünmez uçakları yalnızca yakındaki radar görür.

### Füzeler
Füze üssünden atılır; tek kullanımlık, pahalı, uzun bekleme süreli. Hedefin görülmüş olması gerekir.
Uzun menzilli hava savunma füzeleri önleyebilir.

## 5. Doktrinler

| Doktrin | Öne çıkanlar | Güçlü yanı | Zaafı |
|---|---|---|---|
| **Hava Üstünlüğü** | Görünmez uçak, stratejik keşif, uzun menzil hava savunma | Az sayıda, pahalı, çok güçlü birim | Her kayıp ağır; kara ordusu küçük |
| **İHA** | Küçük sürüler, silahlı İHA'lar | Ucuz, hızlı üretim, yıpratma savaşı | İnsanlı uçağı ve ağır zırhı zayıf |
| **Zırhlı / Topçu** | Tank, obüs, roketatar, katmanlı hava savunma | Yerde çok güçlü | Hava taarruzu sınırlı |
| **Balistik Füze** | Uzun menzilli füzeler | Haritanın her yerini vurur | Kara ordusu güçsüz; keşfe muhtaç |

## 6. Senaryolar

Oyuncu her senaryoda **iki tarafı da** oynayabilir.

| # | Senaryo | Durum |
|---|---|---|
| 1 | Rusya – Ukrayna (Harkiv açıkları) | Açık |
| 2 | İran – İsrail | Açık |
| 3 | Pakistan – Hindistan | Açık |
| 4 | Çin – ABD: Tayvan çıkarması | Kilitli (deniz modu) |
| 5 | Çin – ABD: okyanus | Kilitli (deniz modu) |
| 6 | Türkiye – Yunanistan: adalar | Kilitli (deniz modu) |

### 6.1 Rusya – Ukrayna
İki taraf da yoğun drone saldırıları yüzünden ilerleyemiyor.
- **Harita:** düz tarlalar, ağaç hatları, siperler, yıkık köyler; ortada "gri bölge". Açık arazide ilerleyen her şey İHA'ya hedef olur.
- **Ukrayna (İHA doktrini):** ucuz FPV sürüleri ve keşif İHA'larıyla yıpratır; zırhı az ama Batı yapımıdır.
- **Rusya (Zırhlı / Topçu):** ağır zırh, yoğun topçu, süzülme bombaları; İHA'ya karşı elektronik harp.

### 6.2 İran – İsrail
- **Harita:** iki uzak üs; arada geniş çöl ve dağlar. Kara çıkarması iki taraf için de mümkün ama çok pahalı ve yavaş.
- **İsrail (Hava Üstünlüğü):** görünmez uçaklarla hava savunmayı, füze üslerini ve komuta merkezlerini vurur; katmanlı füze savunması vardır.
- **İran (Balistik Füze):** füze ve kamikaze İHA dalgalarıyla savunmayı doyurur.

### 6.3 Pakistan – Hindistan
- **Harita:** dağlık kuzey (Keşmir benzeri vadiler, geçitler), güneyde düz ova ve nehir.
- **Pakistan (Balistik Füze):** füzeler öne çıkar.
- **Hindistan (dengeli):** insan gücü fazla; piyadesi ucuz, birlik sınırı daha yüksek.

### 6.4 – 6.6 Kilitli senaryolar
- **Çin – ABD, Tayvan çıkarması:** Çin Tayvan'a çıkmak ister, ABD denizde geçişi durdurmaya çalışır.
- **Çin – ABD, okyanus:** amaç karşı tarafın karadaki üslerini yok etmek.
- **Türkiye – Yunanistan:** Türkiye'nin silahları üstün; Yunanistan çok sayıda adayı silahlandırmış ve kaynağa erişimi kolay.

## 7. Ülke envanterleri

Her ülke yalnızca gerçekte kullandığı (ya da sipariş ettiği) sistemleri kullanır.

### Ukrayna
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | FPV kamikaze drone, DJI Mavic 3 (keşif), Baba Yaga (Vampire) bombardıman dronu, Leleka-100, Shark, RAM II |
| Büyük İHA | Bayraktar TB2, UJ-22 Airborne, UJ-26 Bober, AN-196 Liutyi |
| Uçak | F-16, Mirage 2000-5, Su-27, MiG-29 |
| Tank | T-64BV, T-72, Leopard 2A6, M1A1 Abrams, Challenger 2 |
| Zırhlı araç | BMP-2, M2 Bradley, Stryker, Kozak-2 |
| Topçu | 2S22 Bohdana, M777, CAESAR, PzH 2000, M142 HIMARS |
| Hava savunma | Gepard, IRIS-T SLM, NASAMS, Patriot, S-300 |
| Füze | Neptune, Storm Shadow, ATACMS |

### Rusya
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | FPV kamikaze drone, Lancet-3, Orlan-10 (keşif), ZALA 421 |
| Büyük İHA | Geran-2 (Shahed-136), Forpost-R, Orion |
| Uçak | Su-35, Su-34, Su-57 |
| Tank | T-72B3, T-80BVM, T-90M |
| Zırhlı araç | BMP-3, BTR-82A, Tigr-M |
| Topçu | 2S19 Msta-S, 2S7 Pion, BM-27 Uragan, Tornado-S, TOS-1A |
| Hava savunma | Pantsir-S1, Tor-M2, Buk-M3, S-400 |
| Füze | 9K720 İskender-M, Kalibr, Kh-101 |

### İsrail
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | Hero-30, SkyStriker, Orbiter |
| Büyük İHA | Hermes 450, Hermes 900, Heron TP (Eitan), Harop |
| Uçak | F-35I Adir, F-15I Ra'am, F-16I Sufa |
| Tank | Merkava Mk 4 |
| Zırhlı araç | Namer, Eitan |
| Topçu | M109 Doher, ATMOS 2000, PULS |
| Hava savunma | Iron Dome, David's Sling, Arrow 3 |
| Füze | LORA, Delilah |

### İran
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | Ababil-2, Meraj-521, Shahed-131 |
| Büyük İHA | Shahed-136, Shahed-129, Shahed-149 Gaza, Mohajer-6, Mohajer-10, Ababil-3, Ababil-5, Arash-2, Kaman-22, Fotros, Karrar |
| Uçak | F-14A Tomcat, MiG-29, F-4E Phantom II |
| Tank | Karrar, Zulfiqar, T-72S |
| Zırhlı araç | Boragh, BMP-2 |
| Topçu | Raad-2, HM-41, Fajr-5 |
| Hava savunma | Bavar-373, 3. Hordad, S-300PMU2, Tor-M1 |
| Füze | Fateh-110, Zolfaghar, Emad, Ghadr, Sejjil, Kheibar Shekan, Fattah-1, Paveh |

### Pakistan
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | Uqab, loitering mühimmatlar |
| Büyük İHA | Shahpar-II, Burraq, Bayraktar TB2, Akıncı, Wing Loong II, CH-4 |
| Uçak | JF-17 Thunder, J-10C, F-16, Mirage III/5, Chengdu F-7 (J-7) |
| Tank | Al-Khalid, VT-4 Haider, T-80UD |
| Zırhlı araç | Talha, Viper |
| Topçu | SH-15, M109, A-100, Fatah-I |
| Hava savunma | HQ-9/P, LY-80, FM-90 |
| Füze | Shaheen-II, Shaheen-III, Ghauri, Abdali, Nasr, Fatah-II, Babur |

### Hindistan
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | Nagastra-1, SkyStriker |
| Büyük İHA | Heron, Harop, MQ-9B, TAPAS |
| Uçak | Su-30MKI, Rafale, Mirage 2000, Tejas, MiG-29 |
| Tank | T-90S Bhishma, Arjun, T-72 Ajeya |
| Zırhlı araç | BMP-2 Sarath |
| Topçu | K9 Vajra, Dhanush, Bofors FH-77, Pinaka |
| Hava savunma | S-400, Akash, Barak-8 |
| Füze | BrahMos, Agni, Prithvi, Pralay |

### Türkiye (kilitli senaryo)
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | Kargu, Alpagu |
| Büyük İHA | Bayraktar TB2, TB3, Akıncı, Anka, Aksungur |
| Uçak | F-16, Eurofighter Typhoon |
| Tank | Altay, Leopard 2A4, M60T Sabra |
| Zırhlı araç | Kirpi, Ejder Yalçın, Kaplan |
| Topçu | T-155 Fırtına, T-122 Sakarya, TRG-300 Kaplan |
| Hava savunma | Korkut, Hisar-A+, Hisar-O+, Siper, S-400 |
| Füze | Bora, Tayfun, SOM |

### Yunanistan (kilitli senaryo)
| Sınıf | Sistemler |
|---|---|
| Büyük İHA | Heron, Pegasus II |
| Uçak | F-16 Viper, Rafale, Mirage 2000-5 |
| Tank | Leopard 2A6 HEL, Leopard 1A5 |
| Topçu | PzH 2000, M109, RM-70 |
| Hava savunma | Patriot, S-300 PMU-1, Tor-M1, Crotale |

### ABD (kilitli senaryo)
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | Switchblade 300, Switchblade 600 |
| Büyük İHA | RQ-4 Global Hawk, MQ-9 Reaper |
| Uçak | F-22, F-35, F-16, F-15EX |
| Tank | M1A2 Abrams |
| Zırhlı araç | M2 Bradley, Stryker, JLTV |
| Topçu | M109A7 Paladin, M142 HIMARS |
| Hava savunma | Patriot, THAAD, NASAMS |
| Füze | ATACMS, PrSM, Tomahawk |

### Çin (kilitli senaryo)
| Sınıf | Sistemler |
|---|---|
| Küçük İHA | CH-901 |
| Büyük İHA | Wing Loong II, CH-4, WZ-7, GJ-11 |
| Uçak | Chengdu J-7, Chengdu J-10, J-16, Chengdu J-20, J-35 |
| Tank | Type 99A, Type 15 |
| Topçu | PCL-181, PHL-16 |
| Hava savunma | HQ-9B, HQ-17 |
| Füze | DF-17, DF-21D, DF-26 |

## 8. Deneysel silahlar (son kademe)

Her ülke son kademede bir ya da iki deneysel sistem açabilir. Pahalı, tek ya da az sayıda.

| Ülke | Sistem | Rol |
|---|---|---|
| ABD | Ravn X | Havadan fırlatma İHA'sı: uzak noktaya anında keşif ya da vuruş |
| ABD | XQ-58A Valkyrie, YFQ-42A | Uçağa eşlik eden insansız kanat adamı |
| ABD | Leonidas (yüksek güçlü mikrodalga) | Alan etkili drone katili |
| İsrail | Iron Beam (lazer) | Füze ve İHA'ya karşı mühimmatsız savunma |
| Çin | FH-97A | Sadık kanat adamı |
| Çin | Chengdu J-36 | Altıncı nesil ağır görünmez uçak |
| Çin | LW-30 lazer | Drone katili |
| Türkiye | Kızılelma | İnsansız savaş uçağı |
| Türkiye | KAAN | Beşinci nesil savaş uçağı |
| Türkiye | Gökberk lazer, Alka | Drone katili |
| Rusya | S-70 Okhotnik-B | Ağır görünmez İHA |
| Rusya | Kinzhal, Zircon | Hipersonik füze |
| Ukrayna | Tryzub lazer | Drone katili |
| Ukrayna | Magura / deniz dronları | (deniz moduyla) |
| İran | Fattah-2 | Hipersonik süzülme başlıklı füze |
| Hindistan | Ghatak | Görünmez insansız savaş uçağı |
| Pakistan | Fatah-IV | Uzun menzilli seyir füzesi |

## 9. Haritalar

- Mevcut prototipten belirgin biçimde büyük.
- Dağlar ve su kara birimleri için geçilmezdir; köprüler ve geçitler darboğaz oluşturur.
- Hava birimleri araziden etkilenmez; bu, hava gücünü ve hava savunmayı değerli kılar.
- Her senaryo haritası gerçek coğrafyadan ilham alır (bölüm 6).
- İleride: yüksek arazide görüş avantajı, ormanda piyadeye gizlenme, yol üzerinde hız artışı.

## 10. Tempo ve kontrol

- Varsayılan oyun hızı yavaş; birimler dayanıklı, üretim uzun.
- **Hız düğmesi:** Normal / Yavaş / Duraklat. Duraklatılmışken emir verilebilir.
- Karargâhın yanına çekilen birimler onarılır: kaybetmek yerine geri çekmek ödüllendirilir.
- Yapay zekâ zorluk seviyesi seçilebilir olacak (şimdilik kolay ayarda).

## 11. Arayüz

- Seçim düğmelerinde birimin ya da binanın küçük resmi bulunur.
- Kaynak noktalarının üstünde saniyede kazandırdığı dolar yazar.
- Bütün tutarlar dolar cinsindendir.

## 12. Uygulama durumu

| Özellik | Durum |
|---|---|
| Yavaş tempo, dayanıklı ve pahalı birimler, karargâh yanında onarım | Yapıldı |
| Hız düğmesi ve duraklatıp emir verme | Yapıldı |
| Büyük haritalar, engeller, yol bulma | Yapıldı (3 harita) |
| Binaları istenen yere kurma, vinç | Yapıldı |
| Düğmelerde küçük resimler, dolar, `+$/sn` | Yapıldı |
| Senaryo ve taraf seçimi; iki taraf da oynanabilir | Yapıldı (3 senaryo açık, 3 kilitli) |
| Ülke envanterleri (gerçek adlar) | Yapıldı: Ukrayna, Rusya, İsrail, İran, Pakistan, Hindistan |
| Hava alanı ve uçaklar, pist sınırı, görünmez uçak | Yapıldı |
| Küçük / büyük İHA ayrımı, kamikaze ve dolanan mühimmat | Yapıldı |
| Gerçeğine benzeyen modeller | Yapıldı (16 uçak silueti, ülkeye özel tank ve araçlar) |
| Teknoloji merkezi ve araştırmalar | Yapıldı (6 araştırma) |
| Kaynak binası (Maden Ocağı) | Yapıldı |
| Balistik füzeler, hava savunmayla önleme, hipersonik | Yapıldı |
| Doktrin farkları | Yapıldı (maliyet / dayanıklılık / füze çarpanları) |
| Deneysel silahlar (Kademe 3) | Kısmen: lazer drone katili, görünmez İHA, hipersonik füze. Ravn X, FH-97, Kızılelma kilitli ülkelerle gelecek |
| Tablodaki bütün sistemler | Kısmen: her ülkede 16-18 birim oyunda; bölüm 7'deki listelerin kalanı sonra |
| Taktik arazi: tepe, orman, yol, görüş hattı | Yapıldı |
| Elektronik harp ve fiber optik FPV | Yapıldı |
| Siper, köy evleri, mayın, tanksavar engeli | Yapıldı |
| Tecrübe / rütbe, geri çekilme | Yapıldı |
| Doktrin yetenekleri | Yapıldı (doktrin başına bir yetenek) |
| Senaryoya özel görev hedefleri | Yapıldı (her tarafa ayrı görev) |
| Birim kartı: özellikler ve ipucu | Yapıldı |
| Karşı batarya radarı | Sonra |
| Yapay zekâ: zorluk seçimi, keşif, zayıf nokta, önce hava savunması, geri çekilme, doktrine göre ordu | Yapıldı |
| Eğitim bölümü | Yapıldı (11 adım) |
| Bina önizlemesi, toplanma noktası, devriye, birlik grupları | Yapıldı |
| Kayıt ve devam | Yapıldı (otomatik kayıt, tek kayıt yuvası) |
| Ses | Sonra |
| Deniz modu ve kilitli senaryolar (ABD, Çin, Türkiye, Yunanistan) | En son |

## 13. Açık sorular

- Uygulama mağazası: süren savaşları konu alan oyunlar mağaza kurallarına takılabilir. Yayın aşamasında senaryo adlarını gözden geçirmek gerekebilir.
- Gerçek üretici adları ve logoları kullanılmayacak; yalnızca sistem adları.
