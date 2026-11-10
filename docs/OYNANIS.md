# Oynanış Tasarımı (v0.1 – taslak)

Android için gerçek zamanlı strateji. Günümüz silahları, gerçek adlar, low-poly 3D.
Hedef: **kontrolü kolay, kararı zor** bir oyun. Maç süresi 10-15 dakika.

Bu dokümandaki bütün sayılar başlangıç değeridir; oynanabilir sürümde ayarlanacak.

## 1. Tasarım ilkeleri

1. **Parmak hızı değil karar kazandırır.** Tekrarlayan işler (kaynak toplama, yeniden silahlanma, hedef seçme) otomatiktir.
2. **Görmediğini vuramazsın.** Keşif, oyunun merkezindeki mekaniktir.
3. **Her birimin net bir karşılığı vardır.** Oyuncu ekrana bakınca neyin neyi yendiğini anlayabilmeli.
4. **Az birim, anlamlı birim.** Birim sınırı 40. Piyade manga olarak hareket eder.
5. **Harita kontrolü = gelir.** Üste oturan kaybeder.

## 2. Zafer koşulu

Düşman karargâhını yık. Karargâh yıkılınca maç biter.

## 3. Ekonomi

Tek kaynak: **İkmal**. Toplayıcı araç yok.

| Gelir kaynağı | Gelir | Not |
|---|---|---|
| Karargâh | 10 / sn | Her zaman gelir |
| İkmal noktası (haritada 5-7 adet) | +5 / sn | Piyade mangası ele geçirir, 10 sn sürer |
| Petrol tesisi (haritada 1-2 adet, ortada) | +10 / sn | Ele geçirmesi 20 sn, çok değerli |

- Noktalar savunmasızdır; düşman bir manga ile geri alabilir. Baskın (raid) bu yüzden geçerli bir stratejidir.
- **Enerji:** Santral sayısı kadar gelişmiş bina çalışır. Santral vurulursa radar ve uzun menzilli hava savunma kapanır. Bu, düşmana "önce santrali vur" seçeneği verir.

## 4. Üs

Üretim binaları karargâhın çevresindeki hazır **yuvalara** (6 yuva) kurulur: dokun, bina seç, biter.
Savunma yapıları (hava savunma, radar) ise kendi bölgende **serbestçe** yerleştirilir, çünkü nereye koyduğun stratejik bir karardır.

| Bina | Kademe | İşlev |
|---|---|---|
| Karargâh | – | Gelir, kademe yükseltme, destek yetenekleri |
| Santral | 1 | Enerji |
| Kışla | 1 | Piyade mangaları |
| Araç fabrikası | 1 | Zırhlı araç, tank, topçu, hava savunma aracı |
| İHA istasyonu | 2 | Keşif, silahlı ve kamikaze İHA |
| Radar | 2 | Geniş görüş, görünmez uçağı yakından tespit |
| Hava üssü | 3 | Savaş uçakları (4 pist = en çok 4 uçak) |

**Kademe:** Karargâh 1 → 2 → 3 yükseltilir. Her yükseltme pahalıdır ve o sırada ordu basamazsın: klasik "ekonomi mi, ordu mu, teknoloji mi" ikilemi.

## 5. Birimler (ortak havuz)

İlk sürümde iki taraf da aynı birimleri kullanır. Doktrinler bu havuzdan farklılaşır (bkz. bölüm 8).

### Kara

| Birim | Örnek | Güçlü | Zayıf |
|---|---|---|---|
| Piyade mangası | Tüfekli manga | Nokta ele geçirir, ucuz | Araçlar, topçu |
| Tanksavar timi | Javelin timi | Tank, zırhlı araç | Piyade, topçu |
| Zırhlı araç | Kirpi, Humvee | Piyade, hızlı baskın | Tank |
| Ana muharebe tankı | Altay, M1 Abrams, Leopard 2 | Araçlar, binalar | Hava, tanksavar |
| Obüs | Fırtına, M109 | Uzun menzil, bina, hava savunma | Yakın dövüş, hava |
| Çok namlulu roketatar | HIMARS | Alan hasarı, çok uzun menzil | Pahalı, yavaş dolar |

### Hava savunma

| Birim | Örnek | Güçlü | Zayıf |
|---|---|---|---|
| Kısa menzil (araç) | Korkut, Gepard | İHA, kamikaze sürüsü, helikopter | Uçak (yüksekten vurur), tank |
| Uzun menzil (yapı) | Patriot, S-400, Hisar | Uçak, büyük İHA | Sürü (mühimmatı tükenir), topçu |

### Hava

| Birim | Örnek | Rol |
|---|---|---|
| Keşif İHA | Global Hawk | Silahsız, çok geniş görüş, gizli hava savunmayı açığa çıkarır |
| Silahlı İHA | Bayraktar TB2, Akıncı | Bölgede döner, 2-4 mühimmat, tek hedeflere hassas vuruş |
| Kamikaze İHA | Ababil, Shahed tipi | 5'li sürü halinde üretilir, tek kullanımlık |
| Taarruz helikopteri | Atak, Apache | Tank avcısı, haritada serbest dolaşır |
| Çok amaçlı uçak | F-16 | Hava-hava ve hava-yer, orta fiyat |
| Görünmez uçak | F-35 | Yalnızca yakındaki radar görür, pahalı, tek vuruşta bina yıkar |

## 6. Hava harekâtı: görev tabanlı

Mobilde uçağı tek tek sürmek işkencedir. Bu yüzden hava araçları **görev** alır:

- **Uçak (F-16, F-35):** Uçağı seç, hedefe ya da bölgeye dokun. Kalkar, vurur, döner, pistte silahlanır (yaklaşık 20 sn). Havada kontrol edilmez.
  - *Taarruz:* yer hedefini vur.
  - *Hava devriyesi:* bir bölgenin üstünde dön, giren hava aracını düşür.
- **İHA:** Bir bölgeye atanır, orada döner, gördüğü hedefi kendisi vurur. Mühimmatı bitince istasyona döner.
- **Kamikaze:** Hedef bölge seç, sürü gider ve patlar.

Böylece hava gücü tek dokunuşluk bir karardır: *nereye, ne zaman, neyle?*

## 7. Strateji nereden çıkıyor?

### Keşif → bastırma → vuruş zinciri
Düşman hava savunması sis altında gizlidir. Körlemesine F-16 gönderirsen düşer.
1. Keşif İHA'sı ile hava savunmanın yerini bul.
2. Topçu ya da kamikaze sürüsüyle onu sustur.
3. Uçakların yolu açılır, üssü vur.

Savunan taraf da buna karşı oynar: hava savunmayı gizler, yerini değiştirir, keşif İHA'sını avlamak için hava devriyesi atar.

### Karşılık üçgeni
- **Hava** → kara birimlerini ezer
- **Hava savunma** → havayı durdurur
- **Kara / topçu** → hava savunmayı yok eder
- **Kamikaze sürüsü** → pahalı uzun menzil savunmayı ucuza tüketir; kısa menzil savunma sürüyü durdurur

### Dört büyük karar
1. **Genişle ya da saldır:** İkmal noktalarına yayılmak gelir getirir ama orduyu böler.
2. **Kademe zamanlaması:** Erken kademe atlayan güçlü birimlere ulaşır ama o arada savunmasızdır.
3. **Hava mı kara mı:** Bütçe ikisine birden yetmez. Rakibin ne yaptığını görmek için keşif şarttır.
4. **Nereye vuracağın:** Santral (savunmayı kapatır), ikmal noktaları (geliri keser), üretim (orduyu keser) ya da doğrudan karargâh.

## 8. Doktrinler

Maç başında seçilir. Her doktrin ortak havuzun bir kısmını kullanır ve tek bir özel kurala sahiptir.

| Doktrin | Öne çıkan birimler | Özel kural | Zaafı |
|---|---|---|---|
| **Hava Üstünlüğü** | F-35, F-16, Global Hawk, Patriot | Uçaklar %30 daha hızlı silahlanır | Kara ordusu pahalı, az sayıda |
| **İHA Doktrini** | TB2, Akıncı, kamikaze sürüleri, Korkut | İHA'lar %25 ucuz, kamikaze sürüsü 5 yerine 7 | İnsanlı uçağı yok, ağır zırhı zayıf |
| **Zırhlı / Topçu** | Altay, Fırtına, HIMARS, S-400 | Tank ve topçu %20 dayanıklı | Hava saldırı gücü çok sınırlı |

## 9. Destek yetenekleri

Savaştıkça (hasar verdikçe, nokta tuttukça) **komuta puanı** dolar. Karargâhtan harcanır.

| Yetenek | Etki | Bekleme |
|---|---|---|
| Uydu taraması | Seçilen bölgeyi 15 sn açar | 60 sn |
| Elektronik karıştırma | Bölgedeki düşman İHA'ları ve radarı 10 sn kör eder | 90 sn |
| Hava indirme | Seçilen noktaya 2 piyade mangası | 120 sn |
| Seyir füzesi | Tek binaya ağır hasar | 180 sn |

## 10. Kontroller

- Yatay ekran. Tek parmak kaydırır, iki parmak yakınlaştırır.
- Dokun: seç. Çift dokun: ekrandaki aynı tip birimlerin hepsi. Basılı tutup sürükle: kutu seçimi.
- Sol kenar: grup düğmeleri (Kara / Hava savunma / Hava / Hepsi).
- Sağ kenar: üretim ve destek yetenekleri.
- Akıllı komut: düşmana dokun saldırır, yere dokun gider, noktaya dokun ele geçirir.
- Birimler menzile giren düşmana kendiliğinden ateş eder; en uygun hedefi kendisi seçer.
- Küçük harita her zaman görünür; dokununca kamera oraya gider.

## 11. Örnek maç akışı

| Süre | Olan |
|---|---|
| 0-2 dk | Kışla kur, 2-3 manga bas, en yakın ikmal noktalarını al |
| 2-5 dk | Araç fabrikası, ilk çatışmalar noktalar için. Kademe 2'ye geçme kararı |
| 5-9 dk | İHA'lar sahaya çıkar. Keşif savaşı başlar, hava savunma kurulur, ortadaki petrol tesisi için büyük kavga |
| 9-15 dk | Kademe 3, uçaklar ve destek yetenekleri. Hava savunması çöken taraf hızla kaybeder |

## 12. İlk oynanabilir sürüm (prototip)

Durum: **yapıldı**, Godot 4.3 ile. Çalıştırma ve kontroller için [README](../README.md).

İçinde olanlar:
- Tek harita, yapay zekâya karşı 1'e 1.
- 7 birim: manga, Javelin timi, Altay, Fırtına, Korkut, Global Hawk, Bayraktar TB2. Yapı olarak Hisar.
- Sis, ikmal noktaları, petrol tesisi, enerji, kademe 1-2.

Tasarımdan bilinçli sapmalar (prototipi küçük tutmak için):
- Radar binası yok; hava savunma silahları hava hedefini sis olmadan görür.
- Zırhlı araç, çok namlulu roketatar ve helikopter yok.
- Harita düz; engel ve yol bulma yok.
- Yere dokunmak "saldırarak ilerle" emridir. Ateş etmeden çekilmek için "Geri Çekil" düğmesi var.

Sonraki aşamalar: insanlı uçaklar ve hava üssü, doktrin seçimi, destek yetenekleri, ses, çok oyunculu mod.

## 13. Kurgu

Karar: **hayali bir çatışma**. Gerçek ülkeler taraf olarak yer almaz; ekipman adları gerçektir.
Prototipte taraflar yalnızca "Mavi" ve "Kızıl" olarak geçer. Hikâye, taraf adları ve harita kurgusu ayrıca yazılacak.

## 14. Açık sorular

- Deniz birimleri olacak mı? (Öneri: ilk sürümde hayır.)
- Maç içi ilerleme dışında kalıcı ilerleme (birim açma, seviye) olacak mı?
- Hikâye: tarafların adı, çatışmanın nedeni, haritaların geçtiği bölge.
