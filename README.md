# Generals Game (çalışma adı)

Android için gerçek zamanlı strateji oyunu prototipi. Günümüz silahları, gerçek adlar, low-poly 3D.
Motor: **Godot 4.3** (GDScript, Compatibility/GLES3 işleyici).

Tasarım dokümanı: [docs/TASARIM.md](docs/TASARIM.md) (hedef ve yol haritası)

![İnşa menüsü](docs/ekran/us.png)

## Şu an oynanabilen

- Tek harita, yapay zekâya karşı 1'e 1 (sen Mavi, rakip Kızıl). Düşman karargâhını yıkan kazanır.
- **Arazi:** iki dağ sırası, ortada nehir ve üç geçit, güneyde deniz. Kara birimleri engellerin çevresinden yol bulur; İHA'lar üstünden uçar.
- **Ekonomi (dolar):** karargâh geliri, 8 ikmal noktası ve ortadaki petrol tesisi. Her noktanın üstünde kazancı yazar.
- **İnşa:** binalar sarı çemberin içinde istediğin yere kurulur. Vinç sayısı aynı anda kaç inşaat yürüdüğünü belirler.
- **Binalar:** Santral, Kışla, Fabrika, İHA İstasyonu, Hisar-O+.
- **Birimler:** Piyade Mangası, Javelin Timi, Altay, T-155 Fırtına, Korkut, RQ-4 Global Hawk, Bayraktar TB2.
- **Tempo:** Hız düğmesi Normal / Yavaş / Duraklat arasında geçer; duraklatılmışken emir verebilirsin.
- **Onarım:** karargâhın yanına çekilen birimler yavaşça onarılır.
- Savaş sisi: görmediğin yer hedefini vuramazsın.

Henüz yok: senaryo ve ülke seçimi, uçaklar ve hava alanı, küçük/büyük İHA ayrımı, teknoloji merkezi,
balistik füzeler, deneysel silahlar, ses, deniz. Hepsi tasarım dokümanında planlı.

## Kontroller

| Hareket | Sonuç |
|---|---|
| Dokun | Birim / bina seç. Birim seçiliyken: yere dokun = saldırarak ilerle, düşmana dokun = saldır |
| Çift dokun | Ekrandaki aynı tip birimlerin hepsini seç |
| Sürükle | Kamerayı kaydır |
| Basılı tut + sürükle | Kutu seçimi |
| İki parmak | Yakınlaştır / uzaklaştır (bilgisayarda fare tekerleği) |
| Küçük harita | Dokunduğun yere kamerayı götürür |
| Kara / Hava Sav. / Hava / Hepsi | O gruptaki bütün birimleri seçer |
| İnşa | Bina menüsünü açar; bina seç, sonra haritada yerini göster |
| Hız | Normal / Yavaş / Duraklat |
| Geri Çekil | Seçili birimler ateş etmeden üsse döner |

## Çalıştırma

1. [Godot 4.3](https://godotengine.org/download/archive/4.3-stable/) indir.
2. Godot'u aç, **Import** ile bu klasördeki `project.godot` dosyasını seç.
3. **F5** ile oyna. Fare dokunmatik gibi çalışır.

### Android APK

Godot'ta **Editor → Manage Export Templates** ile şablonları indir, **Editor Settings → Export → Android**
altında Android SDK ve Java yolunu göster, sonra **Project → Export → Android → Export Project**.
Dışa aktarma ayarı (`export_presets.cfg`) repoda hazırdır.

## Dosya düzeni

| Yol | İçerik |
|---|---|
| `scripts/defs.gd` | **Bütün sayılar ve adlar**: birim/bina değerleri, maliyetler, harita (dağ, su, köprü, noktalar). Denge buradan ayarlanır |
| `scripts/terrain.gd` | Arazi ve yol bulma |
| `scripts/game.gd` | Ana döngü, ekonomi, seçim, emirler, efektler |
| `scripts/unit.gd`, `air_unit.gd`, `building.gd`, `entity.gd` | Kara birimi, İHA, bina ve ortak taban |
| `scripts/models.gd` | Kodla üretilen low-poly modeller |
| `scripts/fog.gd` | Savaş sisi |
| `scripts/controls.gd`, `camera_rig.gd` | Dokunmatik kontroller ve kamera |
| `scripts/hud.gd` | Arayüz |
| `scripts/ai.gd` | Yapay zekâ rakip |
| `tools/` | Geliştirme testleri |

## Testler

```bash
godot --headless --path . --import
```

```bash
godot --headless --path . --fixed-fps 30 -- --autotest
```

```bash
godot --path . -- --inputtest
```

`--autotest` senaryolu bir maç oynatır (ekran görüntüsü için `--shots=KLASÖR` ekle ve `--headless` kullanma).
`--inputtest` dokunma hareketlerini taklit edip kontrolleri doğrular; gerçek pencere ister.
