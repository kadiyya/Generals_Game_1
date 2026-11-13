class_name Defs
extends RefCounted
## Sabitler ve o an oynanan senaryodan üretilen tablolar.
## Birim, bina, ülke ve harita verileri scenarios.gd içindedir. Para birimi dolardır ($).

const PLAYER := 0
const ENEMY := 1
const NEUTRAL := -1
const TEAM_COLORS: Array[Color] = [Color(0.1, 0.33, 0.85), Color(0.8, 0.15, 0.12)]

const MAP_W := 220.0
const MAP_H := 140.0
const POP_CAP := 40
const START_MONEY := 1000.0
const HQ_INCOME := 10.0
const AI_INCOME_MULT := 0.55      # yapay zekâ zorluğu: 1.0 = oyuncuyla eşit gelir
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

const BUILD_KINDS: Array[String] = ["santral", "maden", "kisla", "fabrika", "havaalani", "sam", "teknoloji", "fuze"]
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
static var SCN := {}


static func bid(team: int, kind: String) -> String:
	return "%s_%s" % [COUNTRY[team], kind]
