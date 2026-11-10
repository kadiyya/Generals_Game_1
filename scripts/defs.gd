class_name Defs
extends RefCounted
## Oyunun bütün sayıları ve adları burada durur. Dengeyi buradan ayarla.

const PLAYER := 0
const ENEMY := 1
const NEUTRAL := -1
const TEAM_COLORS: Array[Color] = [Color(0.1, 0.33, 0.85), Color(0.8, 0.15, 0.12)]
const TEAM_NAMES: Array[String] = ["Mavi", "Kızıl"]

const MAP_W := 140.0
const MAP_H := 90.0
const POP_CAP := 40
const AIR_HEIGHT := 9.0
const START_SUPPLY := 500.0
const HQ_INCOME := 10.0
const TIER2_COST := 600
const TIER2_TIME := 25.0
const BUILD_ZONE := 34.0
const MAX_QUEUE := 5

# armor: inf / light / heavy / bld / air
# targets: "ground" ya da "air"
# mult: zırh sınıfına göre hasar çarpanı (olmayan sınıfa ateş edemez)
const UNITS := {
	"manga": {
		name = "Piyade Mangası", cat = "kara", cost = 100, time = 6.0, tier = 1,
		hp = 160, speed = 4.5, vision = 13.0, radius = 1.0, armor = "inf",
		range = 8.0, dmg = 10.0, cd = 0.5, proj = "tracer", targets = "ground",
		mult = {inf = 1.0, light = 0.6, heavy = 0.15, bld = 0.3},
		capture = true,
	},
	"tanksavar": {
		name = "Javelin Timi", cat = "kara", cost = 150, time = 7.0, tier = 1,
		hp = 110, speed = 4.5, vision = 13.0, radius = 0.9, armor = "inf",
		range = 12.0, dmg = 70.0, cd = 3.0, proj = "missile", targets = "ground",
		mult = {inf = 0.15, light = 1.3, heavy = 1.6, bld = 0.5},
	},
	"tank": {
		name = "Altay Tankı", cat = "kara", cost = 400, time = 12.0, tier = 1,
		hp = 650, speed = 5.5, vision = 13.0, radius = 1.5, armor = "heavy",
		range = 10.5, dmg = 75.0, cd = 2.2, proj = "shell", targets = "ground",
		mult = {inf = 0.45, light = 1.2, heavy = 1.0, bld = 1.0},
	},
	"obus": {
		name = "Fırtına Obüsü", cat = "kara", cost = 500, time = 15.0, tier = 2,
		hp = 320, speed = 3.8, vision = 12.0, radius = 1.6, armor = "light",
		range = 32.0, min_range = 9.0, dmg = 110.0, cd = 5.0, proj = "arc", splash = 4.5,
		targets = "ground", no_chase = true,
		mult = {inf = 1.0, light = 1.0, heavy = 0.6, bld = 1.6},
	},
	"korkut": {
		name = "Korkut", cat = "hs", cost = 300, time = 10.0, tier = 1,
		hp = 350, speed = 5.5, vision = 13.0, radius = 1.5, armor = "light",
		range = 14.0, dmg = 22.0, cd = 0.35, proj = "tracer", targets = "air",
		mult = {air = 1.0},
	},
	"kesif": {
		name = "Global Hawk", cat = "hava", cost = 250, time = 10.0, tier = 2,
		hp = 160, speed = 9.0, vision = 30.0, radius = 1.6, armor = "air", air = true,
	},
	"tb2": {
		name = "Bayraktar TB2", cat = "hava", cost = 450, time = 14.0, tier = 2,
		hp = 130, speed = 8.0, vision = 17.0, radius = 1.4, armor = "air", air = true,
		range = 11.0, dmg = 160.0, cd = 3.5, proj = "missile", targets = "ground",
		mult = {inf = 0.6, light = 1.2, heavy = 1.0, bld = 0.8},
		ammo = 2, rearm = 9.0,
	},
}

# power: artı ise üretir, eksi ise tüketir
const BUILDINGS := {
	"hq": {
		name = "Karargâh", hp = 6000, vision = 20.0, radius = 5.5, armor = "bld", power = 2,
	},
	"santral": {
		name = "Santral", cost = 200, time = 10.0, tier = 1,
		hp = 600, vision = 10.0, radius = 3.0, armor = "bld", power = 3,
	},
	"kisla": {
		name = "Kışla", cost = 200, time = 10.0, tier = 1,
		hp = 800, vision = 12.0, radius = 3.2, armor = "bld",
		produces = ["manga", "tanksavar"],
	},
	"fabrika": {
		name = "Araç Fabrikası", cost = 350, time = 14.0, tier = 1,
		hp = 1000, vision = 12.0, radius = 3.6, armor = "bld", power = -1,
		produces = ["tank", "korkut", "obus"],
	},
	"iha": {
		name = "İHA İstasyonu", cost = 400, time = 16.0, tier = 2,
		hp = 700, vision = 12.0, radius = 3.6, armor = "bld", power = -2,
		produces = ["kesif", "tb2"],
	},
	"hisar": {
		name = "Hisar Hava Savunma", cost = 450, time = 14.0, tier = 2, free = true,
		hp = 550, vision = 14.0, radius = 2.2, armor = "bld", power = -1,
		range = 26.0, dmg = 140.0, cd = 3.0, proj = "missile", targets = "air",
		mult = {air = 1.0},
	},
}

const PAD_BUILDINGS: Array[String] = ["santral", "kisla", "fabrika", "iha"]

# x, z, gelir, ele geçirme süresi, petrol mü
const POINTS := [
	[-30.0, -26.0, 5.0, 10.0, false],
	[-30.0, 26.0, 5.0, 10.0, false],
	[30.0, -26.0, 5.0, 10.0, false],
	[30.0, 26.0, 5.0, 10.0, false],
	[0.0, -33.0, 5.0, 10.0, false],
	[0.0, 33.0, 5.0, 10.0, false],
	[0.0, 0.0, 10.0, 20.0, true],
]
