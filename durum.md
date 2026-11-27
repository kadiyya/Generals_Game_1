# Proje durumu

Son güncelleme: **27 Kasım 2026**. Bu dosya her oturumun sonunda güncellenir; yeni oturum işe buradan başlar.

## En güncel dal

**`claude/sleepy-wozniak-lcj6lg`** — bütün işler bu dalda birleşik. Oyun sürümü **0.19** (Android sürüm kodu 19).

Yeni bir oturum başka bir daldan açıldıysa (deponun varsayılan dalı `claude/adoring-faraday-ga7ahx` çok eskidir),
çalışmaya başlamadan önce en güncel dalı oturumun kendi dalına birleştir:

```bash
git fetch origin claude/sleepy-wozniak-lcj6lg
git merge origin/claude/sleepy-wozniak-lcj6lg     # oturumun kendi dalındayken
```

Başka dallarda bu dala alınmamış iş var mı diye bak: `git fetch origin && git branch -r -v`. Bu daldan daha yeni bir
commit taşıyan dal varsa (başka bir sohbette yapılmış iş), onu da birleştir ve buradaki "En güncel dal" satırını güncelle.

| Dal | Durum |
|---|---|
| `claude/sleepy-wozniak-lcj6lg` | **Güncel (0.19).** 0.18'in üstüne iki istek turu. Geçmişinde 0.10 tabanlı eski bir deneme (0.11) de var; içeriği 0.18 ile değiştirildi, işler 0.18 üstünde yeniden yapıldı. |
| `ccr-f541d790-8wiqi3` | 0.18. Güncel dala birleştirildi. |
| `ccr-23b978b4-5cb2r3` | Başka bir sohbetin işi (tutma süresi sıfırlama, Pakistan hedefleri, yumuşak ses). 26 Kasım'da güncel dala birleştirildi. |
| `claude/trusting-cannon-0uccd0` | Logo, yeni menü, büyük haritalar. Güncel dala birleştirildi. |
| `claude/adoring-faraday-ga7ahx` | Deponun varsayılan dalı; eski (0.8 civarı). |
| `claude/optimistic-edison-rb10qt` | Eski harita görsel denemesi; kullanılmıyor. |

## Oyun nedir

**Cephe Hattı** — Godot 4.3 (GL Compatibility) ile yazılmış, Android için gerçek zamanlı strateji. Bütün modeller,
dokular, sesler ve müzik kodla üretilir (dosya yok). Ayrıntılı tanıtım `README.md`, birim değerleri `docs/DENGE.md`.

Senaryolar: Rusya–Ukrayna (Harkiv), İran–İsrail (Huzistan, 4 bölgeli harita), Pakistan–Hindistan (Keşmir).

## Son oturumlarda yapılanlar (yeniden eskiye)

**0.19 (27 Kasım)** — İki istek turu:
- *Ukrayna dronları:* kamikazeler (FPV, Switchblade, Liutyi, Peklo) zırhlılara %70 (`kami_armor = 1.7`), silahlı
  İHA'lar ve Baba Yaga %35 (`drone_armor = 1.35`) fazla vurur; TB2 270 can/3 füze/9 sn silahlanma, Baba Yaga 85 can/3
  bomba, Mavic 55 can/34 görüş.
- *Rusya:* T-90M ve 2S19 Msta-S çıkarıldı (tank: T-72B3, T-14; topçu: Tornado-S). Zırhlı/Topçu yapay zekâsının hedef
  ordusu tank 8→5, topçu 3→0, roketatar 2→1, piyade 5→6, tanksavar 2→3.
- *Kaynak yatakları:* başta 2, en çok 4, her 200-320 sn'de bir; köprülerin 14 birim yakınına çıkmaz.
- *Keşif dronu* (sdrone_recon) piyade ve tanksavar timince vurulamaz. *Piyade* hasarı 12→13,8 (%15).
- *Köprüler:* asıl takılma nedeni bulundu: 0.14'teki "önü su ise dur ve yolu yeniden hesapla" kuralı köprü kenarındaki
  birimi bir hücre köşesinde sonsuza dek durduruyordu. Artık engelin kenarı boyunca kayar, köşeye sıkışırsa hücrenin
  ortasına çekilir; `line_clear` iki kat sık örnekler. Ayrıca köprüler yoldan 4 birim geniş, tabliyede itişme yumuşak,
  köprüde ve uzak hedefte birim "vardım" deyip durmaz (uzakta 18 sn bekler), suya itilen birlik kenar boyunca kayar.
  Ölçüm (`--bridgetest --watch`, 10 dk, 2'ye 2 Zor): önce 3 takılan birlik, sonra 0.
- *Sahada onarım:* piyade/tanksavar yanındaki kendi binasını (%0,7/sn) ve zırhlısını (%1/sn) onarır; son vuruştan
  8 sn sonra başlar, ikmal dışında yarı hız; üstünde yeşil artı. Maden ve stratejik tesis hariç.
- *Birlik sınırı* 45 (Dengeli 57); sınır doluyken oyuncunun birimi kuyruğa girer, sırada bekler (yapay zekâ beklemez).
- *Füze Üssü düğmesi* (sol panel): üs kurulunca açılır, binayı seçer/kamerayı götürür (füze düğmeleri füzenin
  kademesine kadar gizli olduğu için kullanıcı üssü bulamıyordu).
- *Saldırı simgeleri* (sağda, Menü'nün altında): en çok 5, yeniden eskiye, basınca kamera gider; bina, kaynak ve
  birlik saldırıları; 25 sn vuruş yoksa kalkar.
- *Engel Kur* kaldırıldı (`order_task` "obstacle"u reddeder).
- *Karargâhı Yık* görevi eklendi (bölge, tutma, stratejik hedef yok). İran–İsrail'in 4 bölgesi ve bağımsız kuvvetleri
  yalnızca Senaryo Görevi'nde kurulur (`Scenarios.zones_on`).
- *Füzeler* yalnızca o an görülen yere atılır (bilinen kaynak/tesis istisnası kaldırıldı).
- *Binaya ateş:* hedef binanın kendi hücreleri görüş hattını kesiyordu (birlik binaya yürüyordu); `los_clear`'a hedef
  yarıçapı eklendi, binanın dibindeki birlik görüş aramadan ateş eder; açık saldırı emrindeki bina sis kenarında
  kaybolsa da hedefte kalır. `--firetest` dört ülkede bütün silahlı kara birliklerini dener.

**0.18 (26 Kasım)** — Paralel sohbetin dalı birleştirildi: tutma ve dört bölge görevlerinde süre kesintisizdir
(nokta ya da bir bölge kaybedilince süre sıfırlanır), Pakistan'ın hedefi Hindistan'ın ileri hattındaki 3 hazır üretim
tesisi (bağımsız savunucularıyla), bütün sesler ve müzik daha yumuşak (alçak geçiren süzgeç, daha pes arayüz sesleri).

**0.17** — İkmal noktaları yeniden $2/sn (bir ara $1'e indirilmişti; kullanıcı oyunu yavaşlattığı için geri istedi).
İkmal alanı 62 birim olarak kaldı.

**0.16 — Denge raporu uygulandı** (rapor: https://claude.ai/artifact/G5Yp8KNWSw5rArDmCUg575, maddeler 1-6;
7. madde, maden rezervini kısmak, kullanıcı istemedi):
- Tank 800$, hafif zırha çarpan 1,0; Rusya tank indirimi 0,85.
- Zırhlı araç tanka 0,6 (tanksavar füzesi) — tank tek başına yumuşatılınca zırhlı araç yine kaybediyordu.
- FPV paketi 280$, tanka 0,65; kamikaze İHA 450$.
- Roketatar 950$, 5,5 sn'de bir.
- Zırhlı hava savunmanın yer gücü geri çekildi (piyade 0,3, hafif 0,35); dron savar ve hava savunma binası güçlü kaldı.
- Piyade 300 can, 12 hasar.
- Doktrin fiyat çarpanları 0,75–1,3 aralığında (test bunu denetler).
- İran–İsrail bölgeli haritada kaynaklar bölgelerden en az 52 birim uzakta (bölgedeki birlikler vuramasın);
  rastgele maden yatakları da bölgelere yakın çıkmaz.

**0.15** — Hava savunma araçlarının yere hasarı ~2 kat; büyük hava savunmanın (bina, zırhlı HS) uçağa etkisi %20 az
(balistik füze önleme ayrı `missile` çarpanıyla aynı kaldı); Ukrayna dronları zırhlılara %15 fazla vurur; piyade %10
hızlı, kara araçları %5 yavaş; Füze Üssü varken füzeler sol paneldeki düğmelerden atılır.

**0.14** — Hava savunması yeri de vurur ve önce hava hedefine döner; dosta saldırı olunca yakındaki boştaki birlikler
yardıma gelir; yıkık köprüden geçilmez; inşaat iptali (para tam geri); uçaklar pistte onarılır; balistik füzelerin
canı var (hava savunması düşürür); yapay zekâ füze sıklığı sınırlı; "Havada Yakıt İkmali" yerine "Hava Akını";
menü müziği, katmanlı yeni sesler; parmakla kaydırma; telefonun güvenli alanı (çentik) ve elle "kenar boşluğu" ayarı.

**0.13** — İran–İsrail'de 4 bölge: bağımsız kuvvetler (üçüncü taraf, `Defs.IND`) iki orduya da saldırır, ölünce zayıf
olarak yeniden doğar; iki taraf da dört bölgeyi tutmaya çalışır. Kamikaze dronlar bölgelerine yaklaşan düşmana dalar;
birlikler görüş alanındaki düşmana kendiliğinden saldırır.

**0.12** — Gerçek ölçek (ağaçlar askerin 6-9 katı, yakın kamera, harita 0,72 ölçek), emir önceliği (yere dokunmak
"git" emridir, yolda ateş eder), tank tareti hedefi izler, piyadede kalça/diz animasyonu, yere yığılan askerler.

**Daha önce** — Yükseklik alanlı arazi, su, sallanan bitki örtüsü, kuşlar, bulut gölgeleri (`scripts/terrain.gd`,
`scripts/scenery.gd`, `scripts/birds.gd`).

## Açık konular ve öneriler

- **0.19 dengesi ölçülmedi:** Ukrayna dron artışı `tools/duel.gd` ile ölçülmedi (düello aynı ülkede çalışıyor, Ukrayna'nın
  tankı yok); oyunda fazla güçlü gelirse `kami_armor` 1,7 → 1,5 denenebilir.
- **"Karargâhı Yık" yorumu:** kullanıcı "karargâhı yık görevinde ele geçirilecek alanlar olmayacak" dedi; ayrı bir görev
  olarak eklendi ve bölgeler yalnızca Senaryo Görevi'ne bağlandı. İkmal noktaları (ekonomi) her görevde duruyor.

- **Doktrin fiyat farkı:** zıt doktrinli iki ülke arasında aynı birim hâlâ ~1,35 kat farklı (ör. Ukrayna zırhlı aracı
  437$, Rusya 323$). Kullanıcıya aralığı 0,85–1,2'ye daraltmak önerildi, cevap bekleniyor.
- **Yapay zekâ yavaş:** bölgeli haritada yapay zekâ orduyu yavaş kuruyor (ilk bölgeyi ~17. dakikada aldı).
- **Telefonda denenmedi:** kare hızı, kamera deliği güvenli alanı ve sesler yalnızca bilgisayarda/sayısal olarak denendi.
- **Varsayılan dal eski:** yeni oturumlar varsayılan daldan açılır; bu yüzden ilk iş en güncel dalı birleştirmek.

## Çalışma ortamı (bulut oturumu)

Kurulum her yeni konteynerde tekrar gerekir; komutlar scratchpad klasöründe (`$S`) çalışır:

```bash
# Godot 4.3
curl -sSL -o godot.zip https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_linux.x86_64.zip && unzip -o godot.zip
# APK için: dışa aktarma şablonları (~1 GB indirme; yalnızca android_* dosyaları gerekir)
curl -sSL -o tpl.tpz https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_export_templates.tpz
mkdir -p ~/.local/share/godot/export_templates/4.3.stable && unzip -o -j tpl.tpz 'templates/android_*' 'templates/version.txt' -d ~/.local/share/godot/export_templates/4.3.stable
# Android SDK
curl -sSL -o cmd.zip https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
mkdir -p sdk/cmdline-tools && unzip -q cmd.zip -d sdk/cmdline-tools && mv sdk/cmdline-tools/cmdline-tools sdk/cmdline-tools/latest
yes | sdk/cmdline-tools/latest/bin/sdkmanager --sdk_root=$S/sdk "platform-tools" "build-tools;34.0.0" "platforms;android-34"
# test anahtarı ve Godot editör ayarları (java_sdk_path, android_sdk_path, debug_keystore) -> ~/.config/godot/editor_settings-4.3.tres
keytool -genkeypair -keystore $S/debug.keystore -storepass android -keypass android -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US"
# APK (JAVA_TOOL_OPTIONS proxy ayarı bozar, kaldır)
unset JAVA_TOOL_OPTIONS; godot --headless --path . --export-debug "Android" GeneralsGame-0.19.apk
```

APK'lar test anahtarıyla imzalı; telefonda farklı imzalı sürüm varsa önce kaldırılmalı. Her yeni APK'da
`export_presets.cfg` içindeki `version/code` ve `version/name` bir artırılır. `*.apk` git'e girmez.

## Testler

Önce `godot --headless --path . --import`. Hepsi geçiyor (26 Kasım):

| Komut | Ne dener |
|---|---|
| `--mechtest --scn=0` | Bütün mekanikler (en kapsamlı); sonunda oyunu kaydeder |
| `--load --loadtest` | `--mechtest`'in kaydını yükler (hemen ardından çalıştır) |
| `--objtest --scn=0/1/2 [--side=1] [--goal=N]` | Görevler, bölgeler, bağımsız kuvvetler, tutma sıfırlama |
| `--tuttest --tutorial` | Eğitim |
| `--autotest --scn=N --end=300` | Bot oyuncuyla tam maç |
| `--maptest --scn=N` | Haritanın oynanabilirliği (yollar, köprüler) |
| `--inputtest --scn=2` (pencere, `xvfb-run`, 480x270) | Dokunmatik kontroller |
| `--animtest --scn=0 --side=1` (pencere) | Animasyon, emir önceliği, taret, kayıp |
| `--menutest` (pencere) | Menüde parmakla kaydırma, sesler, müzik |
| `--viewtest --scn=N --shots=KLASÖR` (pencere) | Harita görüntüleri |
| `--firetest --scn=N [--side=1]` | Bütün silahlı kara birlikleri düşman binasına ateş eder |
| `--bridgetest --scn=N [--n=20]` / `--watch --mode=2 --mins=10` | Köprü geçişi; gerçek maçta köprüde takılan birlik |
| `--duel --scn=N [--hepsi \| --cift=ifv,tank]` | Eşit bütçeli denge düelloları (her biri 4 tekrar) |
| `-s tools/balance.gd -- docs/DENGE.md` | Birim değer tablosunu yeniden üretir |

Testlerin hepsi `--fixed-fps 30` ile çalıştırılır. Pencere gerektirenler:
`xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -- ...`

## Kullanıcıyla çalışma notları

- Kullanıcı Türkçe yazar; cevaplar Türkçe.
- Her istekten sonra yeni APK üretilip gönderilir.
- Ekonomiyi yavaşlatan değişiklikler istenmiyor (maden rezervi kısılmadı, ikmal geliri geri $2 yapıldı).
- Denge değişikliklerinde `tools/duel.gd` ile öncesi/sonrası ölçülür, `docs/DENGE.md` yeniden üretilir.
