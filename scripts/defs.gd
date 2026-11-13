class_name Defs
extends RefCounted
## Sabitler ve o an oynanan senaryodan üretilen tablolar.
## Birim, bina, ülke ve harita verileri scenarios.gd içindedir. Para birimi dolardır ($).

const PLAYER := 0
const ENEMY := 1          # ana düşman takımı (her zaman 1)
const NEUTRAL := -1
# Takım renkleri: oyuncu mavi, müttefik yeşil; düşmanlar kırmızı ve turuncu.
const COL_PLAYER := Color(0.1, 0.33, 0.85)
const COL_ALLY := Color(0.1, 0.62, 0.45)
const COL_FOES: Array[Color] = [Color(0.8, 0.15, 0.12), Color(0.9, 0.5, 0.08)]
# Maç düzenleri: her takımın tarafı (0 = oyuncunun tarafı, 1 = düşman tarafı). Takım 0 oyuncu, takım 1 ana düşman.
const MODES := [
	{id = "1v1", name = "Teke Tek", desc = "Bir düşman üssü.", sides = [0, 1]},
	{id = "1v2", name = "İki Düşman Üssü", desc = "Düşmanın iki ayrı üssü ve iki ordusu var.", sides = [0, 1, 1]},
	{id = "2v2", name = "Takım (2'ye 2)", desc = "Yanında müttefik bir yapay zekâ ordusu; karşında iki düşman üssü.", sides = [0, 1, 0, 1]},
]

const POP_CAP := 40
const START_MONEY := 1500.0
const HQ_INCOME := 6.0
# Yapay zekâ zorluğu. income: gelir çarpanı (1.0 = oyuncuyla eşit), first: ilk saldırı (sn),
# tier: kademe atlama aralığı (sn), wave: ilk dalga büyüklüğü, retreat: geri çekilme can eşiği,
# scout: keşif aralığı (sn), smart: zayıf noktayı seçme ve hava savunmasını önce vurma.
const DIFFS := [
	{name = "Kolay", income = 0.8, first = 520.0, tier = 300.0, wave = 5, retreat = 0.2, scout = 60.0, smart = false, think = 2.0, raid = false, expand = 1},
	{name = "Orta", income = 1.1, first = 380.0, tier = 220.0, wave = 7, retreat = 0.3, scout = 30.0, smart = true, think = 1.2, raid = true, expand = 2},
	{name = "Zor", income = 1.45, first = 280.0, tier = 160.0, wave = 8, retreat = 0.35, scout = 18.0, smart = true, think = 0.8, raid = true, expand = 3},
]
const MAX_TIER := 3
const TIER_COST := [0, 1000, 2000]     # [bulunulan kademe] -> bir üst kademenin bedeli
const TIER_TIME := [0.0, 40.0, 60.0]
const BUILD_ZONE := 42.0
const MAX_QUEUE := 5
const CRANE_COST := 500
const MAX_CRANES := 3
const MAX_MINES := 4
const PLANES_PER_AIRFIELD := 4
const HEAL_RADIUS := 16.0         # karargâhın yanındaki birimler onarılır
const HEAL_RATE := 0.015          # saniyede azami canın oranı
const INTERCEPT_CHANCE := 0.4     # menzildeki her hava savunmanın füzeyi önleme olasılığı

const BUILD_KINDS: Array[String] = ["santral", "kisla", "fabrika", "maden", "ileri", "havaalani", "sam", "teknoloji", "fuze"]
# Lojistik: ikmal kaynaklarının yarıçapı. İkmal hattı dışındaki kara birliği %30 az hasar verir, %10 yavaş gider
# ve onarılmaz. Kaynaklar: karargâh, ileri harekât üssü, sağlam ikmal noktaları.
const SUPPLY_HQ := 75.0
const SUPPLY_FOB := 55.0
const OOS_DMG := 0.7
const OOS_SPEED := 0.9
const FOB_ZONE := 26.0                                   # ileri üssün çevresinde kurulabilecek binalar
const FOB_KINDS: Array[String] = ["kisla", "santral", "sam"]
const PRESENCE_R := 28.0                                 # maden / ileri üs için yakında gereken birlik
# Kaynak yatakları: başta kaç tane, en çok kaç tane, kaç saniyede bir yenisi belirir, verim ve rezerv aralığı.
const DEPOSIT_FIRST := 3
const DEPOSIT_MAX := 7
const DEPOSIT_EVERY := Vector2(100.0, 170.0)
const DEPOSIT_RICH := Vector2(5.5, 9.0)
const DEPOSIT_RESERVE := Vector2(5000.0, 9000.0)
const PLANE_CLASSES: Array[String] = ["fighter", "striker", "stealth"]
const MAX_LANDMINES := 10
const MINE_COST := 100
const DIG_TIME := 8.0
const RANK_XP := [0.8, 2.2, 4.5]   # rütbe eşikleri: birimin kendi maliyetinin katı kadar verilen hasar
const RANK_NAMES := ["Er", "Çavuş", "Kıdemli", "Gazi"]

# Senaryo yüklenince Scenarios.setup() tarafından doldurulur.
static var UNITS := {}
static var BUILDINGS := {}
static var MAP := {}
static var COUNTRY: Array = ["ua", "ru"]     # [takım] -> ülke kodu
static var SIDE: Array = [0, 1]              # [takım] -> taraf
static var N := 2                            # takım sayısı
static var TEAM_COLORS: Array = [COL_PLAYER, COL_FOES[0]]
static var TEAM_NAMES: Array = ["", ""]
static var SCN := {}
static var MAP_W := 720.0
static var MAP_H := 440.0


static func bid(team: int, kind: String) -> String:
	return "%s_%s" % [COUNTRY[team], kind]


## İki takım birbirine düşman mı. Tarafsız (-1) kimseye düşman değildir.
static func foe(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and SIDE[a] != SIDE[b]


## Aynı taraftalar mı (kendisi dahil).
static func ally(a: int, b: int) -> bool:
	return a >= 0 and b >= 0 and SIDE[a] == SIDE[b]


## Takım oyuncunun tarafında mı.
static func friendly(t: int) -> bool:
	return t >= 0 and SIDE[t] == SIDE[PLAYER]


## Bir tarafın görev ilerlemesini tutan takım (taraftaki ilk takım).
static func leader(side: int) -> int:
	for t in N:
		if SIDE[t] == side:
			return t
	return 0
