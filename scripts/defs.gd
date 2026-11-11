class_name Defs
extends RefCounted
## Oyunun bütün sayıları ve adları burada durur. Dengeyi buradan ayarla.
## Para birimi dolardır ($).

const PLAYER := 0
const ENEMY := 1
const NEUTRAL := -1
const TEAM_COLORS: Array[Color] = [Color(0.1, 0.33, 0.85), Color(0.8, 0.15, 0.12)]
const TEAM_NAMES: Array[String] = ["Mavi", "Kızıl"]

const POP_CAP := 40
const AIR_HEIGHT := 9.0
const START_MONEY := 1000.0
const HQ_INCOME := 10.0
const AI_INCOME_MULT := 0.55     # yapay zekâ zorluğu: 1.0 = oyuncuyla eşit gelir
const TIER2_COST := 1000
const TIER2_TIME := 40.0
const BUILD_ZONE := 40.0
const MAX_QUEUE := 5
const CRANE_COST := 500
const MAX_CRANES := 3
const HEAL_RADIUS := 16.0        # karargâhın yanındaki birimler onarılır
const HEAL_RATE := 0.015         # saniyede azami canın oranı

# ---------------------------------------------------------------- harita
const MAP_W := 220.0
const MAP_H := 140.0
const BASES: Array[Vector3] = [Vector3(-90, 0, 0), Vector3(90, 0, 0)]
# Dikdörtgenler: [x0, z0, x1, z1]
const MOUNTAINS := [
	[-49.0, -62.0, -41.0, -14.0], [-49.0, 14.0, -41.0, 50.0],
	[41.0, -62.0, 49.0, -14.0], [41.0, 14.0, 49.0, 50.0],
	[-26.0, -16.0, -18.0, -8.0], [18.0, 8.0, 26.0, 16.0],
]
const WATER := [
	[-4.0, -70.0, 4.0, 70.0],        # nehir
	[-110.0, 58.0, 110.0, 70.0],     # deniz
]
const BRIDGES := [
	[-5.0, -44.0, 5.0, -36.0],       # kuzey köprüsü
	[-10.0, -10.0, 10.0, 10.0],      # orta geçit (petrol)
	[-5.0, 36.0, 5.0, 44.0],         # güney köprüsü
]
# x, z, gelir ($/sn), ele geçirme süresi, petrol mü
const POINTS := [
	[-68.0, -38.0, 5.0, 12.0, false],
	[-68.0, 38.0, 5.0, 12.0, false],
	[-24.0, -40.0, 5.0, 12.0, false],
	[-24.0, 40.0, 5.0, 12.0, false],
	[24.0, -40.0, 5.0, 12.0, false],
	[24.0, 40.0, 5.0, 12.0, false],
	[68.0, -38.0, 5.0, 12.0, false],
	[68.0, 38.0, 5.0, 12.0, false],
	[0.0, 0.0, 12.0, 25.0, true],
]

# ---------------------------------------------------------------- birimler
# armor: inf / light / heavy / bld / air
# targets: "ground" ya da "air"
# mult: zırh sınıfına göre hasar çarpanı (olmayan sınıfa ateş edemez)
const UNITS := {
	"manga": {
		name = "Piyade Mangası", cat = "kara", cost = 150, time = 10.0, tier = 1,
		hp = 260, speed = 3.4, vision = 14.0, radius = 1.0, armor = "inf",
		range = 8.0, dmg = 10.0, cd = 0.5, proj = "tracer", targets = "ground",
		mult = {inf = 1.0, light = 0.6, heavy = 0.15, bld = 0.3},
		capture = true,
	},
	"tanksavar": {
		name = "Javelin Timi", cat = "kara", cost = 220, time = 12.0, tier = 1,
		hp = 180, speed = 3.4, vision = 14.0, radius = 0.9, armor = "inf",
		range = 12.0, dmg = 70.0, cd = 3.0, proj = "missile", targets = "ground",
		mult = {inf = 0.15, light = 1.3, heavy = 1.6, bld = 0.5},
	},
	"tank": {
		name = "Altay", cat = "kara", cost = 700, time = 22.0, tier = 1,
		hp = 1100, speed = 4.2, vision = 14.0, radius = 1.5, armor = "heavy",
		range = 10.5, dmg = 75.0, cd = 2.2, proj = "shell", targets = "ground",
		mult = {inf = 0.8, light = 1.2, heavy = 1.0, bld = 1.0},
	},
	"obus": {
		name = "T-155 Fırtına", cat = "kara", cost = 900, time = 28.0, tier = 2,
		hp = 520, speed = 3.0, vision = 12.0, radius = 1.6, armor = "light",
		range = 34.0, min_range = 9.0, dmg = 110.0, cd = 5.0, proj = "arc", splash = 4.5,
		targets = "ground", no_chase = true,
		mult = {inf = 1.0, light = 1.0, heavy = 0.6, bld = 1.6},
	},
	"korkut": {
		name = "Korkut", cat = "hs", cost = 550, time = 18.0, tier = 1,
		hp = 560, speed = 4.2, vision = 14.0, radius = 1.5, armor = "light",
		range = 14.0, dmg = 22.0, cd = 0.35, proj = "tracer", targets = "air",
		mult = {air = 1.0},
	},
	"kesif": {
		name = "RQ-4 Global Hawk", cat = "hava", cost = 450, time = 18.0, tier = 2,
		hp = 260, speed = 8.0, vision = 30.0, radius = 1.6, armor = "air", air = true, icon_r = 4.6,
	},
	"tb2": {
		name = "Bayraktar TB2", cat = "hava", cost = 800, time = 26.0, tier = 2,
		hp = 220, speed = 7.0, vision = 17.0, radius = 1.4, armor = "air", air = true, icon_r = 2.9,
		range = 11.0, dmg = 160.0, cd = 3.5, proj = "missile", targets = "ground",
		mult = {inf = 0.6, light = 1.2, heavy = 1.0, bld = 0.8},
		ammo = 2, rearm = 10.0,
	},
}

# ---------------------------------------------------------------- binalar
# power: artı ise üretir, eksi ise tüketir
const BUILDINGS := {
	"hq": {
		name = "Karargâh", hp = 8000, vision = 20.0, radius = 5.5, armor = "bld", power = 2,
	},
	"santral": {
		name = "Santral", cost = 300, time = 15.0, tier = 1,
		hp = 900, vision = 10.0, radius = 3.0, armor = "bld", power = 3,
	},
	"kisla": {
		name = "Kışla", cost = 300, time = 15.0, tier = 1,
		hp = 1200, vision = 12.0, radius = 3.2, armor = "bld",
		produces = ["manga", "tanksavar"],
	},
	"fabrika": {
		name = "Fabrika", cost = 600, time = 22.0, tier = 1,
		hp = 1500, vision = 12.0, radius = 3.6, armor = "bld", power = -1,
		produces = ["tank", "korkut", "obus"],
	},
	"iha": {
		name = "İHA İstasyonu", cost = 700, time = 25.0, tier = 2,
		hp = 1000, vision = 12.0, radius = 3.6, armor = "bld", power = -2,
		produces = ["kesif", "tb2"],
	},
	"hisar": {
		name = "Hisar-O+", cost = 700, time = 20.0, tier = 2,
		hp = 800, vision = 14.0, radius = 2.2, armor = "bld", power = -1,
		range = 26.0, dmg = 140.0, cd = 3.0, proj = "missile", targets = "air",
		mult = {air = 1.0},
	},
}

const BUILD_MENU: Array[String] = ["santral", "kisla", "fabrika", "iha", "hisar"]
