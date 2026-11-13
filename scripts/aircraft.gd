class_name Aircraft
extends RefCounted
## Uçak ve İHA modelleri. Hepsi gerçek ölçüyle (metre) yazılır, sonra oyundaki boyuta ölçeklenir. Ön +Z, üst +Y.
## Gövdeler yuvarlatılmış kesitlerden, kanat ve kuyruklar profilli (sivri hücum ve firar kenarlı) kesitlerden kurulur.
## Hareketli parçalar Kit.begin_part ile ayrı mesh olur; AirUnit bunları adlarına göre oynatır:
##   ail_l/r: kanatçık (yatışta zıt yönde), stab_l/r ve can_l/r: tümü oynar yatay kuyruk ve kanard,
##   rud*: dikey dümen, burn*: art yakıcı alevi, strobe: çakar ışık, eo: kamera tareti, store*: dış yükler (cephane).
## Pervaneler ayrı kurucuya (pk) bir kez çizilir; design() göbeklerin [konum, döndürme] listesini döndürür.
## Not: bu dosya yalnızca Kit çağrıları ve düz hesap içerir; geliştirme önizleme aracı da aynı kodu okur.

# Jetler, metre cinsinden. L: boy, game: oyundaki boy. fam: light (tek gövde) / heavy (ayrık motor naselli).
# W, H: ön gövdenin yarı genişliği ve yarı yüksekliği. can: kanopi [ön z, arka z, yarı genişlik, yükseklik, taban y,
# koltuk, altın camlı]. intake: [tür, x, y, ön z, arka z, yarı genişlik, yarı yükseklik]. pods: nasel [x, y, r, ön z, arka z].
# noz: lüle [x, y, r, z]. wing / stab / canard: [kök x, kök hücum z, kök firar z, uç x, uç hücum z, uç firar z, y, kalınlık
# oranı, dihedral, kanatçık başı, kanatçık sonu (span oranı)]. fin / ventral: [x, yatıklık, kök hücum z, kök firar z, kök y,
# uç hücum z, uç firar z, uç y]; x > 0 ise iki tane. lerx: [kök x, burun z, kanat kökü x, kanat kökü z, arka z].
const AIRFRAMES := {
	"f16": {"L": 15.0, "game": 5.0, "fam": "light", "W": 0.74, "H": 0.66, "scheme": "grey", "pitot": true,
		"can": [5.9, 2.9, 0.44, 0.62, 0.62, 1, true],
		"intake": ["chin", 0.0, -0.98, 4.3, 0.3, 0.6, 0.42],
		"noz": [0.0, 0.0, 0.56, -6.7],
		"wing": [0.75, 1.4, -3.4, 4.7, -1.85, -3.15, 0.0, 0.05, 0.0, 0.1, 0.62],
		"stab": [0.75, -4.6, -6.7, 2.95, -6.1, -7.0, -0.15, 0.05, -10.0],
		"fin": [0.0, 0.0, -2.9, -6.9, 0.6, -6.1, -7.25, 3.5],
		"ventral": [0.6, 18.0, -3.6, -4.9, -0.55, -4.5, -5.1, -1.2],
		"lerx": [0.55, 4.7, 1.2, 1.4, 0.4], "tips": true},
	"jf17": {"L": 14.0, "game": 4.8, "fam": "light", "W": 0.72, "H": 0.66, "scheme": "grey2",
		"can": [5.5, 2.9, 0.42, 0.6, 0.6, 1, false],
		"intake": ["side", 0.95, -0.15, 3.4, 0.2, 0.32, 0.5],
		"noz": [0.0, 0.0, 0.55, -6.2],
		"wing": [0.8, 1.0, -3.2, 4.5, -1.95, -2.95, -0.05, 0.05, 0.0, 0.12, 0.6],
		"stab": [0.75, -4.2, -6.2, 2.65, -5.7, -6.55, -0.1, 0.05, 0.0],
		"fin": [0.0, 0.0, -2.8, -6.4, 0.6, -5.7, -6.8, 3.2],
		"lerx": [0.6, 3.9, 1.1, 1.0, 0.0], "tips": true},
	"mirage": {"L": 14.4, "game": 4.9, "fam": "light", "W": 0.7, "H": 0.7, "scheme": "grey2", "pitot": true,
		"can": [5.3, 2.4, 0.42, 0.62, 0.66, 1, false],
		"intake": ["semi", 0.95, -0.05, 3.2, -0.4, 0.36, 0.55],
		"noz": [0.0, 0.0, 0.52, -6.4],
		"wing": [0.8, 3.6, -5.9, 4.55, -5.0, -5.9, -0.2, 0.045, 0.0, 0.15, 0.95],
		"fin": [0.0, 0.0, -1.9, -6.3, 0.7, -5.3, -6.7, 3.6], "tips": false},
	"tejas": {"L": 13.2, "game": 4.1, "fam": "light", "W": 0.64, "H": 0.62, "scheme": "grey2",
		"can": [4.6, 2.0, 0.4, 0.56, 0.6, 1, false],
		"intake": ["semi", 0.85, -0.1, 2.6, -0.6, 0.32, 0.48],
		"noz": [0.0, 0.0, 0.5, -5.8],
		"wing": [0.7, 3.2, -5.5, 4.1, -4.4, -5.5, -0.2, 0.045, 0.0, 0.12, 0.95],
		"fin": [0.0, 0.0, -2.0, -5.7, 0.62, -4.9, -6.0, 3.3], "tips": false},
	"mig21": {"L": 14.1, "game": 4.4, "fam": "light", "W": 0.6, "H": 0.62, "scheme": "grey2", "pitot": true,
		"can": [3.7, 2.0, 0.38, 0.5, 0.58, 1, false], "spine": [2.0, -2.5, 0.34, 0.95],
		"intake": ["nose", 0.0, 0.0, 7.05, 6.4, 0.5, 0.5],
		"noz": [0.0, 0.0, 0.5, -6.3],
		"wing": [0.6, 1.3, -3.6, 3.6, -2.8, -3.5, -0.15, 0.04, -2.0, 0.3, 0.9],
		"stab": [0.55, -4.6, -6.0, 1.9, -5.7, -6.2, -0.05, 0.05, 0.0],
		"fin": [0.0, 0.0, -3.0, -6.5, 0.6, -5.6, -6.7, 2.9],
		"ventral": [0.0, 0.0, -4.4, -5.6, -0.55, -5.2, -5.7, -1.2], "tips": false},
	"j10": {"L": 16.9, "game": 5.0, "fam": "light", "W": 0.8, "H": 0.72, "scheme": "grey2",
		"can": [6.2, 3.3, 0.45, 0.65, 0.7, 1, true],
		"intake": ["chin", 0.0, -1.05, 3.9, 0.3, 0.7, 0.45],
		"noz": [0.0, 0.0, 0.58, -7.6],
		"wing": [0.85, 1.0, -5.6, 4.85, -4.6, -5.6, -0.1, 0.045, 0.0, 0.12, 0.92],
		"canard": [0.85, 4.4, 2.9, 2.6, 3.0, 2.5, 0.25, 0.05, 0.0],
		"fin": [0.0, 0.0, -3.2, -7.4, 0.7, -6.3, -7.8, 3.5],
		"ventral": [0.65, 20.0, -4.6, -6.0, -0.6, -5.6, -6.2, -1.25], "tips": true},
	"rafale": {"L": 15.3, "game": 5.0, "fam": "light", "W": 0.82, "H": 0.66, "scheme": "grey2",
		"can": [5.6, 2.6, 0.42, 0.6, 0.62, 1, false],
		"intake": ["side", 0.85, -0.5, 3.4, 0.3, 0.32, 0.4],
		"noz": [0.48, 0.0, 0.46, -6.9],
		"wing": [0.9, 0.9, -6.1, 5.45, -5.2, -6.1, -0.1, 0.045, 0.0, 0.12, 0.92],
		"canard": [0.9, 3.4, 2.0, 2.6, 2.3, 1.75, 0.3, 0.05, 6.0],
		"fin": [0.0, 0.0, -2.3, -6.8, 0.66, -5.8, -7.2, 3.4], "tips": true},
	"f35": {"L": 15.7, "game": 4.9, "fam": "light", "W": 1.25, "H": 0.75, "scheme": "stealth", "facet": true,
		"can": [5.6, 3.0, 0.48, 0.6, 0.66, 1, true],
		"intake": ["side", 1.25, -0.05, 3.9, 1.0, 0.4, 0.55],
		"noz": [0.0, 0.0, 0.62, -6.9],
		"wing": [1.4, 1.6, -3.4, 5.35, -1.6, -2.9, -0.05, 0.05, 0.0, 0.15, 0.6],
		"stab": [1.3, -4.9, -7.2, 3.3, -6.4, -7.4, 0.0, 0.05, 0.0],
		"fin": [1.15, 25.0, -3.6, -6.4, 0.7, -5.4, -6.9, 2.9], "tips": false},
	"f15": {"L": 19.4, "game": 5.9, "fam": "heavy", "W": 0.75, "H": 0.75, "scheme": "grey",
		"can": [6.5, 2.4, 0.46, 0.66, 0.68, 2, false],
		"intake": ["box", 1.3, 0.05, 4.8, 1.0, 0.5, 0.62],
		"pods": [0.62, 0.0, 0.6, 1.0, -8.3],
		"noz": [0.62, 0.0, 0.56, -8.3],
		"wing": [1.6, 1.2, -3.9, 6.5, -3.7, -4.9, 0.3, 0.045, -1.0, 0.45, 0.95],
		"stab": [1.6, -5.7, -8.3, 4.3, -7.6, -8.6, 0.0, 0.05, 0.0],
		"fin": [1.35, 2.0, -4.2, -8.0, 0.6, -6.8, -8.6, 3.4], "tips": false},
	"f14": {"L": 19.1, "game": 6.0, "fam": "heavy", "W": 0.75, "H": 0.75, "scheme": "grey",
		"can": [6.2, 2.3, 0.46, 0.66, 0.68, 2, false],
		"intake": ["box", 1.45, -0.1, 3.0, 0.6, 0.55, 0.62],
		"pods": [1.45, -0.1, 0.62, 0.6, -8.0],
		"noz": [1.45, -0.1, 0.56, -8.0],
		"glove": [0.9, 4.0, -2.4, 2.7, 0.3, -2.9],
		"wing": [2.7, 0.3, -2.9, 6.0, -3.2, -4.3, 0.15, 0.04, 0.0, 0.3, 0.95],
		"stab": [2.1, -5.4, -8.0, 5.0, -7.6, -8.6, -0.05, 0.05, 0.0],
		"fin": [1.5, 5.0, -4.6, -7.9, 0.55, -6.9, -8.6, 3.5], "tips": false},
	"f4": {"L": 19.2, "game": 5.6, "fam": "light", "W": 0.95, "H": 0.8, "scheme": "grey", "pitot": false,
		"can": [6.0, 2.0, 0.46, 0.62, 0.78, 2, false],
		"intake": ["side", 1.15, 0.05, 4.8, 1.0, 0.36, 0.7],
		"noz": [0.55, -0.15, 0.5, -7.4],
		"wing": [1.0, 1.3, -3.2, 5.85, -2.6, -4.0, -0.25, 0.05, 5.0, 0.55, 0.95],
		"stab": [0.8, -6.2, -8.4, 3.0, -7.6, -8.6, 0.55, 0.05, -23.0],
		"fin": [0.0, 0.0, -4.8, -8.3, 0.7, -7.4, -8.7, 3.3], "tips": false},
	"su35": {"L": 21.9, "game": 6.4, "fam": "heavy", "W": 0.8, "H": 0.78, "scheme": "ru",
		"can": [7.3, 3.4, 0.46, 0.68, 0.72, 1, false], "stinger": -10.9,
		"intake": ["box", 1.25, -0.62, 3.4, 0.6, 0.55, 0.62],
		"pods": [1.25, -0.4, 0.66, 0.6, -8.4],
		"noz": [1.25, -0.4, 0.6, -8.4],
		"wing": [2.0, 1.0, -4.0, 7.6, -4.4, -5.4, -0.05, 0.045, -2.0, 0.45, 0.92],
		"stab": [1.9, -6.6, -9.0, 4.4, -8.8, -9.8, -0.35, 0.05, 0.0],
		"fin": [1.75, 0.0, -5.2, -8.6, 0.0, -7.6, -9.3, 4.0],
		"lerx": [0.9, 5.8, 2.0, 1.0, 0.0], "tips": true},
	"su30": {"L": 21.9, "game": 6.4, "fam": "heavy", "W": 0.82, "H": 0.8, "scheme": "ru",
		"can": [7.4, 2.6, 0.46, 0.68, 0.72, 2, false], "stinger": -10.9,
		"intake": ["box", 1.25, -0.62, 3.4, 0.6, 0.55, 0.62],
		"pods": [1.25, -0.4, 0.66, 0.6, -8.4],
		"noz": [1.25, -0.4, 0.6, -8.4],
		"wing": [2.0, 1.0, -4.0, 7.6, -4.4, -5.4, -0.05, 0.045, -2.0, 0.45, 0.92],
		"stab": [1.9, -6.6, -9.0, 4.4, -8.8, -9.8, -0.35, 0.05, 0.0],
		"canard": [1.0, 4.6, 3.3, 3.0, 3.3, 2.85, 0.15, 0.05, 0.0],
		"fin": [1.75, 0.0, -5.2, -8.6, 0.0, -7.6, -9.3, 4.0],
		"lerx": [0.9, 5.8, 2.0, 1.0, 0.0], "tips": true},
	"su34": {"L": 23.3, "game": 6.6, "fam": "heavy", "W": 1.1, "H": 0.85, "scheme": "ru", "flat": true,
		"can": [7.9, 4.6, 0.85, 0.66, 0.8, 3, false], "stinger": -11.9,
		"intake": ["box", 1.3, -0.62, 3.4, 0.6, 0.55, 0.62],
		"pods": [1.3, -0.4, 0.66, 0.6, -8.8],
		"noz": [1.3, -0.4, 0.6, -8.8],
		"wing": [2.1, 1.0, -4.2, 7.3, -4.2, -5.5, -0.05, 0.045, -2.0, 0.45, 0.92],
		"stab": [2.0, -7.0, -9.4, 4.5, -9.2, -10.2, -0.35, 0.05, 0.0],
		"canard": [1.15, 4.8, 3.5, 3.0, 3.5, 3.05, 0.15, 0.05, 0.0],
		"fin": [1.8, 0.0, -5.6, -9.0, 0.0, -8.0, -9.7, 4.1],
		"lerx": [1.0, 6.0, 2.1, 1.0, 0.0], "tips": true},
	"mig29": {"L": 17.3, "game": 5.3, "fam": "heavy", "W": 0.7, "H": 0.72, "scheme": "ru",
		"can": [5.8, 2.6, 0.42, 0.62, 0.66, 1, false],
		"intake": ["box", 1.0, -0.6, 2.9, 0.6, 0.48, 0.55],
		"pods": [1.0, -0.38, 0.56, 0.6, -6.9],
		"noz": [1.0, -0.38, 0.52, -6.9],
		"wing": [1.7, 0.8, -3.4, 5.7, -3.6, -4.6, -0.05, 0.045, -2.0, 0.45, 0.92],
		"stab": [1.6, -5.6, -7.6, 3.8, -7.2, -8.0, -0.3, 0.05, 0.0],
		"fin": [1.45, 6.0, -4.0, -6.9, 0.05, -6.0, -7.5, 3.3],
		"lerx": [0.75, 4.7, 1.7, 0.8, -0.3], "tips": false},
	"su57": {"L": 20.1, "game": 6.2, "fam": "heavy", "W": 0.95, "H": 0.6, "scheme": "split", "flat": true, "facet": true,
		"can": [6.8, 3.6, 0.48, 0.58, 0.55, 1, false],
		"intake": ["box", 1.55, -0.45, 3.4, 0.9, 0.5, 0.5],
		"pods": [1.6, -0.35, 0.6, 0.9, -8.6],
		"noz": [1.6, -0.35, 0.56, -8.6],
		"wing": [2.4, 2.0, -4.6, 7.05, -3.6, -4.9, -0.05, 0.04, 0.0, 0.35, 0.92],
		"stab": [2.5, -6.0, -8.6, 4.6, -7.9, -9.2, -0.2, 0.04, 0.0],
		"fin": [2.0, 26.0, -6.0, -8.4, 0.0, -7.6, -8.9, 3.0],
		"lerx": [1.2, 5.0, 2.4, 2.0, 1.4], "tips": false},
}

const DRONES := ["quad", "hexa", "small_plane", "xwing", "shahed", "shahed_s", "harop", "tb2", "twinboom", "mohajer6",
	"liutyi", "vtail", "akinci", "flyingwing"]

# Oyun stili (RTS kamerasından okunurluk için): boy aynı kalır (BIG), gövde ve kanat açıklığı biraz genişletilir (STY),
# kanat ve kuyruk yüzeyleri gerçekteki inceliklerinden kalın çizilir (TK).
const BIG := 1.0
const STY := Vector3(1.06, 1.06, 1.0)
const TK := 1.7
const FIN_T := 0.07
# Takım rengi: kanat uçlarında şerit (açıklığın son BAND kadarı), dikey kuyrukların üst kısmı.
const BAND := 0.2

# Gövde kesit şablonları: [z / L, yarı genişlik / W, üst / H, alt / H, merkez y / H, köşelilik]
const LIGHT := [[0.49, 0.1, 0.1, 0.08, -0.05, 2.0], [0.477, 0.46, 0.46, 0.42, -0.04, 2.0], [0.45, 0.7, 0.68, 0.62, -0.02, 2.1],
	[0.4, 0.84, 0.82, 0.76, 0.0, 2.2], [0.29, 0.86, 0.88, 0.75, 0.04, 2.3], [0.2, 0.93, 0.92, 0.82, 0.05, 2.4],
	[0.1, 0.98, 0.86, 0.88, 0.03, 2.6], [0.0, 1.0, 0.82, 0.9, 0.0, 2.7], [-0.15, 0.97, 0.8, 0.88, 0.0, 2.6],
	[-0.32, 0.86, 0.76, 0.78, 0.0, 2.4], [-0.44, 0.74, 0.72, 0.72, 0.0, 2.0]]
const HEAVY := [[0.49, 0.1, 0.1, 0.08, -0.05, 2.0], [0.477, 0.46, 0.46, 0.42, -0.04, 2.0], [0.45, 0.7, 0.68, 0.62, -0.02, 2.1],
	[0.4, 0.84, 0.82, 0.76, 0.0, 2.2], [0.29, 0.86, 0.9, 0.75, 0.05, 2.3], [0.2, 0.92, 0.96, 0.78, 0.08, 2.4],
	[0.1, 0.9, 0.86, 0.68, 0.08, 2.6], [-0.05, 0.78, 0.72, 0.5, 0.08, 2.7], [-0.25, 0.58, 0.56, 0.36, 0.08, 2.6],
	[-0.44, 0.36, 0.36, 0.26, 0.05, 2.2]]


static func has(id: String) -> bool:
	return AIRFRAMES.has(id) or id in DRONES


## Boya şeması: [malzeme türü, renk]. Kamuflajlı türlerde renk dokudan gelir, köşe rengi açık gridir.
static func scheme(id: String, cc: String, ac: Color) -> Array:
	var sc := "grey"
	if AIRFRAMES.has(id):
		sc = AIRFRAMES[id]["scheme"]
	if cc == "il" and (id == "f16" or id == "f15"):
		sc = "il"
	if cc == "ir" and (id == "f4" or id == "f14"):
		sc = "desert"
	if cc == "in" and id == "su30":
		sc = "ru"
	if sc == "ru":
		return ["camo_ru", Color(0.95, 0.95, 0.95)]
	if sc == "desert":
		return ["camo_desert", Color(0.95, 0.95, 0.95)]
	if sc == "il":
		return ["camo_il", Color(0.95, 0.95, 0.95)]
	if sc == "split":
		return ["camo_split", Color(0.95, 0.95, 0.95)]
	if sc == "stealth":
		return ["paint", Color(0.42, 0.44, 0.46)]
	if sc == "grey2":
		return ["paint", ac.lerp(Color(0.5, 0.55, 0.6), 0.3)]
	return ["paint", ac]


## Renk yuvaları. sk: scheme() sonucu.
static func slots(k: Kit, ac: Color, tc: Color, sk: Array) -> void:
	var base: Color = sk[1]
	k.slot("skin", sk[0], base, 0.0)
	k.slot("skin2", "paint", ac.darkened(0.16), 0.0)
	k.slot("radome", "paint", ac.lerp(Color(0.36, 0.38, 0.4), 0.4), 0.0)
	k.slot("steel", "steel", Color(0.42, 0.41, 0.4), 0.0)
	k.slot("burnt", "steel", Color(0.3, 0.27, 0.25), 0.0)
	k.slot("dark", "steel", Color(0.06, 0.06, 0.07), 0.0)
	k.slot("plastic", "paint", Color(0.17, 0.18, 0.18), 0.0)
	k.slot("glass", "optic", Color(0.13, 0.18, 0.25), 0.0)
	k.slot("gold", "optic", Color(0.5, 0.38, 0.15), 0.0)
	k.slot("team", "paint", tc, 0.0)
	k.slot("white", "paint", Color(0.9, 0.9, 0.87), 0.0)
	k.slot("bomb", "paint", Color(0.36, 0.37, 0.3), 0.0)
	k.slot("rotor", "steel", Color(0.12, 0.12, 0.12), 0.0)
	k.slot("stealth", "paint", Color(0.25, 0.27, 0.29), 0.0)
	k.slot("navr", "emit", Color(1.0, 0.15, 0.1), 0.0)
	k.slot("navg", "emit", Color(0.2, 1.0, 0.3), 0.0)
	k.slot("navw", "emit", Color(1.0, 1.0, 0.95), 0.0)
	k.slot("flame", "emit", Color(1.0, 0.55, 0.16), 0.0)
	k.slot("flame2", "emit", Color(1.0, 0.93, 0.7), 0.0)
	k.slot("glow", "emit", Color(0.95, 0.42, 0.12), 0.0)
	k.slot("lens", "emit", Color(0.35, 0.75, 1.0), 0.0)


## id modelini k'ye (gövde) ve pk'ye (pervane) çizer; pervane göbeklerini döndürür.
## cls: birim sınıfı (silah yükü için), ammo: dış yük sayısı.
static func design(id: String, k: Kit, pk: Kit, cls: String, ammo: int) -> Array:
	if AIRFRAMES.has(id):
		_jet(k, AIRFRAMES[id], cls, ammo)
		return []
	if id == "quad":
		return _quad(k, pk)
	if id == "hexa":
		return _hexa(k, pk, ammo)
	if id == "small_plane":
		return _orlan(k, pk)
	if id == "xwing":
		return _lancet(k, pk)
	if id == "shahed":
		return _shahed(k, pk, 0.85)
	if id == "shahed_s":
		return _shahed(k, pk, 0.5)
	if id == "harop":
		return _harop(k, pk)
	if id == "tb2":
		return _tb2(k, pk, ammo)
	if id == "twinboom":
		return _heron(k, pk)
	if id == "mohajer6":
		return _mohajer(k, pk, ammo)
	if id == "liutyi":
		return _liutyi(k, pk)
	if id == "vtail":
		return _mq9(k, pk, ammo)
	if id == "akinci":
		return _akinci(k, pk, ammo)
	return _flyingwing(k)


# ---------------------------------------------------------------- ortak geometri

## Gövde kesiti: süperelips (sq 2 = elips, büyüdükçe köşeli). z'de, (xc, yc) merkezli.
static func _sec(z: float, xc: float, yc: float, hw: float, top: float, bot: float, sq: float, n: int) -> Array:
	var r: Array = []
	var e := 2.0 / sq
	for i in n:
		var a := TAU * (i + 0.5) / n
		var c := cos(a)
		var s := sin(a)
		var x := hw * signf(c) * pow(absf(c), e)
		var y := (top if s > 0.0 else bot) * signf(s) * pow(absf(s), e)
		r.append(Vector3(xc + x, yc + y, z))
	return r


## Yuvarlak gövde: [z, yarı genişlik, üst, alt, merkez y, köşelilik] istasyonları, önden arkaya.
static func _fuse(k: Kit, s: String, st: Array, n: int) -> void:
	var rings: Array = []
	for r in st:
		rings.append(_sec(r[0], 0.0, r[4], r[1], r[2], r[3], r[5], n))
	k.loft(s, rings, true, true)


## Kanat profili (Vector2(z, kalınlık yönü)). part 0: tam, 1: ön kısım (kanatçık menteşesine kadar), 2: kanatçık.
static func _foil(le: float, te: float, t: float, part: int, sym: bool) -> Array:
	var lo := 0.55 if sym else 0.42
	var c := te - le
	var u3 := Vector2(le + c * 0.3, t * 0.55)
	var u7 := Vector2(le + c * 0.72, t * 0.24)
	var l3 := Vector2(le + c * 0.3, -t * lo)
	var l7 := Vector2(le + c * 0.72, -t * lo * 0.43)
	if part == 1:
		return [Vector2(le, 0), u3, u7, l7, l3]
	if part == 2:
		return [u7, Vector2(te, 0), l7]
	return [Vector2(le, 0), u3, u7, Vector2(te, 0), l7, l3]


## Kanat yarısı. w: [kök x, kök hücum, kök firar, uç x, uç hücum, uç firar, y, kalınlık oranı, dihedral, kanatçık başı,
## kanatçık sonu]. side: +1 sağ / -1 sol. name: kanatçık parça adı ("" ise kanatçık yok). allmove: bütün yüzey parça.
## band > 0: açıklığın son band kadarı takım renginde şeritle kaplanır; kanatçık şeritten önce biter.
static func _wing(k: Kit, s: String, w: Array, side: float, name: String, allmove: bool, band := 0.0) -> void:
	var dt := tan(deg_to_rad(w[8]))
	if allmove:
		var pv := Vector3(w[0] * side, w[6], lerpf(w[1], w[2], 0.4))
		k.begin_part(name, pv, Vector3(side, 0, 0))
		k.loft(s, [_wsec(w, side, dt, 0.0, 0), _wsec(w, side, dt, 1.0, 0)])
		k.end_part()
		return
	var fr: Array = [0.0, 1.0]
	if name != "" and w.size() > 10:
		fr = [0.0, w[9], minf(w[10], 1.0 - band) if band > 0.0 else w[10], 1.0]
	for i in fr.size() - 1:
		var fa: float = fr[i]
		var fb: float = fr[i + 1]
		if fr.size() == 4 and i == 1:
			k.loft(s, [_wsec(w, side, dt, fa, 1), _wsec(w, side, dt, fb, 1)])
			var pa := _hinge(w, side, dt, fa)
			var pb := _hinge(w, side, dt, fb)
			k.begin_part(name, pa, pb - pa)
			k.loft(s, [_wsec(w, side, dt, fa, 2), _wsec(w, side, dt, fb, 2)])
			k.end_part()
		else:
			k.loft(s, [_wsec(w, side, dt, fa, 0), _wsec(w, side, dt, fb, 0)])
	if band > 0.0:
		_wband(k, w, side, dt, 1.0 - band)


## Kanat ucu şeridi: profili saran, biraz kalın takım renkli kılıf (f0'dan uca kadar).
static func _wband(k: Kit, w: Array, side: float, dt: float, f0: float) -> void:
	var rings: Array = []
	for f in [f0, 1.0]:
		var x: float = lerpf(w[0], w[3], f) + (0.02 if f >= 1.0 else 0.0)
		var le: float = lerpf(w[1], w[4], f)
		var te: float = lerpf(w[2], w[5], f)
		var y: float = w[6] + (x - w[0]) * dt
		var t: float = maxf(float(w[7]) * TK * absf(le - te), 0.03)
		var r: Array = []
		for q in _foil(le + 0.03, te - 0.03, t, 0, false):
			var off := 0.03 if q.y > 0.0 else (-0.03 if q.y < 0.0 else 0.0)
			r.append(Vector3(x * side, y + q.y + off, q.x))
		rings.append(r)
	k.loft("team", rings)


static func _wsec(w: Array, side: float, dt: float, f: float, part: int) -> Array:
	var x := lerpf(w[0], w[3], f)
	var le := lerpf(w[1], w[4], f)
	var te := lerpf(w[2], w[5], f)
	var y: float = w[6] + (x - w[0]) * dt
	var t: float = w[7] * TK * absf(le - te)
	var r: Array = []
	for q in _foil(le, te, maxf(t, 0.03), part, false):
		r.append(Vector3(x * side, y + q.y, q.x))
	return r


static func _hinge(w: Array, side: float, dt: float, f: float) -> Vector3:
	var x := lerpf(w[0], w[3], f)
	var le := lerpf(w[1], w[4], f)
	var te := lerpf(w[2], w[5], f)
	return Vector3(x * side, w[6] + (x - w[0]) * dt, le + (te - le) * 0.72)


## Kanadın x hizasındaki üst yüzeyinin y'si ve kirişin ortası (z): Vector2(y, z).
static func _wtop(w: Array, x: float) -> Vector2:
	var f := clampf((x - w[0]) / maxf(w[3] - w[0], 0.01), 0.0, 1.0)
	var le := lerpf(w[1], w[4], f)
	var te := lerpf(w[2], w[5], f)
	var y: float = w[6] + (x - w[0]) * tan(deg_to_rad(w[8])) + w[7] * TK * absf(le - te) * 0.5
	return Vector2(y, (le + te) * 0.5)


## Dikey yüzey. f: [x, yatıklık, kök hücum, kök firar, kök y, uç hücum, uç firar, uç y]. rud: dümen parça adı ("" yok).
## band: uçta takım rengi şerit.
static func _fin(k: Kit, s: String, f: Array, xs: float, rud: String, band: bool) -> void:
	var x: float = f[0] * xs
	var cant: float = f[1] * xs
	var h: float = f[7] - f[4]
	var ttk := FIN_T
	k.push(Vector3(x, f[4], 0), Vector3(0, 0, -cant))
	var parts := [0] if rud == "" else [1, 2]
	for pt in parts:
		var rings: Array = []
		for fy in [0.0, 1.0]:
			var le := lerpf(f[2], f[5], fy)
			var te := lerpf(f[3], f[6], fy)
			var r: Array = []
			for q in _foil(le, te, ttk * absf(le - te), pt, true):
				r.append(Vector3(q.y, fy * h, q.x))
			rings.append(r)
		if pt == 2:
			var pa := Vector3(0, 0, lerpf(f[2], f[3], 0.72))
			var pb := Vector3(0, h, lerpf(f[5], f[6], 0.72))
			k.begin_part(rud, pa, pb - pa)
			k.loft(s, rings)
			k.end_part()
		else:
			k.loft(s, rings)
	if band:
		var r2: Array = []
		for fy in [0.66, 1.0]:
			var le := lerpf(f[2], f[5], fy)
			var te := lerpf(f[3], f[6], fy)
			var r: Array = []
			for q in _foil(le + 0.02, te - 0.02, ttk * absf(le - te) + 0.06, 0, true):
				r.append(Vector3(q.y, fy * h + (0.02 if fy > 0.9 else 0.0), q.x))
			r2.append(r)
		k.loft("team", r2)
	k.pop()


## Gövde istasyonlarından z'deki kesit (doğrusal ara değer): [z, yarı genişlik, üst, alt, merkez y, köşelilik].
static func _stat(st: Array, z: float) -> Array:
	for i in st.size() - 1:
		var a: Array = st[i]
		var b: Array = st[i + 1]
		if z <= a[0] and z >= b[0]:
			var t: float = (a[0] - z) / maxf(a[0] - b[0], 0.001)
			var r: Array = []
			for j in 6:
				r.append(lerpf(a[j], b[j], t))
			return r
	return st[0] if z > st[0][0] else st[st.size() - 1]


## Gövdenin sırtına oturan ince şerit (ör. kokpit önündeki mat siyah parlama önleyici panel). z0 önde, ang: tepeden
## iki yana açı (derece).
static func _strip(k: Kit, s: String, st: Array, z0: float, z1: float, ang: float) -> void:
	var rings: Array = []
	for i in 5:
		var z := lerpf(z0, z1, i / 4.0)
		var r := _stat(st, z)
		var e: float = 2.0 / r[5]
		var a2 := ang * (0.55 + 0.45 * i / 4.0)
		var outer: Array = []
		var inner: Array = []
		for j in 7:
			var a := deg_to_rad(90.0 - a2 + a2 * 2.0 * j / 6.0)
			var c := cos(a)
			var sn := sin(a)
			var x: float = r[1] * signf(c) * pow(absf(c), e)
			var y: float = r[2] * pow(sn, e)
			outer.append(Vector3(x * 1.025, r[4] + y * 1.025 + 0.01, z))
			inner.append(Vector3(x * 0.99, r[4] + y * 0.99, z))
		inner.reverse()
		rings.append(outer + inner)
	k.loft(s, rings, true)


## Kanopi: yarım elips kesitli cam fanus, çerçeveleri koyu.
static func _canopy(k: Kit, c: Array) -> void:
	var zf: float = c[0]
	var zr: float = c[1]
	var hw: float = c[2]
	var h: float = c[3]
	var y: float = c[4]
	var seats: int = c[5]
	var glass := "gold" if c[6] else "glass"
	var st := [[0.0, 0.25, 0.2], [0.12, 0.7, 0.68], [0.3, 0.95, 0.95], [0.6, 1.0, 1.0], [0.85, 0.88, 0.8], [1.0, 0.45, 0.3]]
	var rings: Array = []
	for q in st:
		rings.append(_dome(lerpf(zf, zr, q[0]), y, hw * q[1], h * q[2]))
	k.loft(glass, rings, true, true)
	var bows := [0.3] if seats != 2 else [0.3, 0.56]
	for b in bows:
		var z := lerpf(zf, zr, b)
		var a1 := _dome(z + 0.03, y, hw * 0.98, h * 0.98)
		var a2 := _dome(z - 0.03, y, hw * 0.98, h * 0.98)
		var big1: Array = []
		var big2: Array = []
		for i in a1.size():
			big1.append(a1[i] * Vector3(1.03, 1.0, 1.0) + Vector3(0, 0.02, 0))
			big2.append(a2[i] * Vector3(1.03, 1.0, 1.0) + Vector3(0, 0.02, 0))
		k.loft("dark", [big1, big2])


static func _dome(z: float, y: float, hw: float, h: float) -> Array:
	var r: Array = []
	for i in 9:
		var a := PI * i / 8.0
		r.append(Vector3(hw * cos(a), y + h * pow(sin(a), 0.8), z))
	return r


## Lüle: dişli kapak, koyu iç, içinde titreyen art yakıcı (parça).
static func _nozzle(k: Kit, x: float, y: float, r: float, z: float, idx: int) -> void:
	var ln := r * 1.3
	var p := Vector3(x, y, z)
	k.lathe("burnt", [Vector2(r * 1.02, 0), Vector2(r * 0.98, ln * 0.55), Vector2(r * 0.86, ln), Vector2(r * 0.76, ln), Vector2(r * 0.76, ln * 0.5)],
		p, Vector3(-90, 0, 0), 14)
	for i in 12:
		k.push(p, Vector3(0, 0, 30.0 * i))
		k.box("steel", Vector3(0.04, 0.03, ln * 0.45), Vector3(0, r * 0.97, -ln * 0.7), Vector3(-6, 0, 0))
		k.pop()
	k.lathe("glow", [Vector2(0, 0), Vector2(r * 0.77, 0), Vector2(r * 0.77, 0.01), Vector2(0, 0.01)], p + Vector3(0, 0, -ln * 0.45), Vector3(-90, 0, 0), 12)
	k.begin_part("burn%d" % idx, p + Vector3(0, 0, -ln * 0.5), Vector3(0, 0, -1))
	k.lathe("flame", [Vector2(r * 0.74, 0), Vector2(r * 0.62, r * 1.2), Vector2(r * 0.36, r * 3.0), Vector2(r * 0.12, r * 4.4), Vector2(0, r * 4.9)],
		p + Vector3(0, 0, -ln * 0.5), Vector3(-90, 0, 0), 10)
	k.lathe("flame2", [Vector2(r * 0.5, 0), Vector2(r * 0.4, r * 0.9), Vector2(r * 0.16, r * 2.2), Vector2(0, r * 2.7)], p + Vector3(0, 0, -ln * 0.52), Vector3(-90, 0, 0), 8)
	k.end_part()


## Hava-hava füzesi (parça): beyaz gövde, koyu arayıcı burun, kanatçıklar. p ağırlık merkezi.
static func _missile(k: Kit, p: Vector3, ln: float, r: float, name: String) -> void:
	k.begin_part(name, p, Vector3(0, 1, 0))
	var b := p + Vector3(0, 0, -ln * 0.5)
	k.lathe("white", [Vector2(0, 0), Vector2(r, 0), Vector2(r, ln * 0.84)], b, Vector3(90, 0, 0), 8)
	k.lathe("radome", [Vector2(r, ln * 0.84), Vector2(r * 0.4, ln * 0.97), Vector2(0, ln)], b, Vector3(90, 0, 0), 8)
	for a in [45.0, 135.0]:
		k.box("white", Vector3(r * 5.0, 0.012, ln * 0.12), b + Vector3(0, 0, ln * 0.07), Vector3(0, 0, a))
		k.box("white", Vector3(r * 3.6, 0.012, ln * 0.07), b + Vector3(0, 0, ln * 0.7), Vector3(0, 0, a))
	k.end_part()


## Bomba (parça): yeşil gövde, kuyruk kanatçıkları.
static func _bomb(k: Kit, p: Vector3, ln: float, r: float, name: String) -> void:
	k.begin_part(name, p, Vector3(0, 1, 0))
	var b := p + Vector3(0, 0, -ln * 0.5)
	k.lathe("bomb", [Vector2(0, 0), Vector2(r * 0.55, 0), Vector2(r, ln * 0.3), Vector2(r, ln * 0.72), Vector2(r * 0.5, ln * 0.95), Vector2(0, ln)],
		b, Vector3(90, 0, 0), 10)
	k.lathe("white", [Vector2(r * 1.01, ln * 0.5), Vector2(r * 1.01, ln * 0.55)], b, Vector3(90, 0, 0), 10)
	for a in [45.0, 135.0]:
		k.box("bomb", Vector3(r * 3.0, 0.015, ln * 0.18), b + Vector3(0, 0, ln * 0.09), Vector3(0, 0, a))
	k.end_part()


## Pilon: kanat altında yük askısı.
static func _pylon(k: Kit, p: Vector3, ln: float, h: float) -> void:
	k.loft("skin2", [[Vector3(p.x - 0.04, p.y, p.z + ln * 0.5), Vector3(p.x + 0.04, p.y, p.z + ln * 0.5), Vector3(p.x + 0.04, p.y - h, p.z + ln * 0.35),
		Vector3(p.x - 0.04, p.y - h, p.z + ln * 0.35)],
		[Vector3(p.x - 0.04, p.y, p.z - ln * 0.5), Vector3(p.x + 0.04, p.y, p.z - ln * 0.5), Vector3(p.x + 0.04, p.y - h, p.z - ln * 0.4),
		Vector3(p.x - 0.04, p.y - h, p.z - ln * 0.4)]])


## Seyir ışıkları: sol kırmızı, sağ yeşil (sabit); çakar beyaz (parça, yanıp söner).
static func _nav(k: Kit, tip: Vector3, strobe: Vector3, r: float) -> void:
	k.box("navr", Vector3(r, r, r * 1.6), Vector3(-tip.x, tip.y, tip.z))
	k.box("navg", Vector3(r, r, r * 1.6), tip)
	k.begin_part("strobe", strobe, Vector3(0, 1, 0))
	k.box("navw", Vector3(r * 1.2, r * 1.2, r * 1.2), strobe)
	k.end_part()


## Elektro-optik kamera tareti (parça, hedefe döner): top, ön camı.
static func _eo(k: Kit, p: Vector3, r: float) -> void:
	k.lathe("skin2", [Vector2(r * 0.5, r * 1.4), Vector2(r * 0.55, r * 0.9)], p, Vector3.ZERO, 8)
	k.begin_part("eo", p, Vector3(0, 1, 0))
	var prof: Array = []
	for i in 9:
		var a := -PI * 0.5 + PI * i / 8.0
		prof.append(Vector2(cos(a) * r, sin(a) * r))
	k.lathe("white", prof, p, Vector3.ZERO, 12)
	k.box("glass", Vector3(r * 0.9, r * 0.75, 0.03), p + Vector3(0, -r * 0.1, r * 0.97))
	k.lathe("lens", [Vector2(0, 0), Vector2(r * 0.22, 0), Vector2(r * 0.22, 0.01), Vector2(0, 0.012)], p + Vector3(r * 0.2, -r * 0.1, r * 0.99), Vector3(90, 0, 0), 8)
	k.end_part()


## Pervane: n kanat, r yarıçap, c kanat genişliği, burulma payı. Ekseni +Y, göbek merkezde.
static func _prop(k: Kit, n: int, r: float, c: float) -> void:
	k.lathe("dark", [Vector2(0, -c * 0.5), Vector2(c * 0.55, -c * 0.4), Vector2(c * 0.45, c * 0.3), Vector2(0, c * 0.9)], Vector3.ZERO, Vector3.ZERO, 10)
	for i in n:
		k.push(Vector3.ZERO, Vector3(0, 360.0 * i / n, 0))
		k.loft("rotor", [
			[Vector3(c * 0.3, -c * 0.06, c * 0.5), Vector3(c * 0.3, c * 0.06, c * 0.5), Vector3(c * 0.3, c * 0.06, -c * 0.5), Vector3(c * 0.3, -c * 0.06, -c * 0.5)],
			[Vector3(r * 0.45, -c * 0.05 + c * 0.2, c * 0.55), Vector3(r * 0.45, c * 0.05 + c * 0.2, c * 0.55), Vector3(r * 0.45, c * 0.05 - c * 0.2, -c * 0.45),
				Vector3(r * 0.45, -c * 0.05 - c * 0.2, -c * 0.45)],
			[Vector3(r, -c * 0.03 + c * 0.12, c * 0.25), Vector3(r, c * 0.03 + c * 0.12, c * 0.25), Vector3(r, c * 0.03 - c * 0.12, -c * 0.25),
				Vector3(r, -c * 0.03 - c * 0.12, -c * 0.25)],
		])
		k.box("white", Vector3(r * 0.07, c * 0.14, c * 0.55), Vector3(r * 0.96, 0, 0))
		k.pop()


## Takım rengi işaret: kanat üstünde disk.
static func _mark(k: Kit, p: Vector3, r: float) -> void:
	k.lathe("team", [Vector2(r, 0), Vector2(r, 0.01), Vector2(0, 0.012)], p, Vector3.ZERO, 16)
	k.lathe("white", [Vector2(r * 0.42, 0), Vector2(r * 0.42, 0.016), Vector2(0, 0.018)], p, Vector3.ZERO, 10)


## Ölçeği uygulanmış göbek listesi.
static func _hubs(s: float, hubs: Array) -> Array:
	var out: Array = []
	for hb in hubs:
		out.append([hb[0] * s, hb[1]])
	return out


# ---------------------------------------------------------------- jetler

static func _jet(k: Kit, p: Dictionary, cls: String, ammo: int) -> void:
	var L: float = p["L"]
	var S: float = float(p["game"]) * BIG / L
	var W: float = p["W"]
	var H: float = p["H"]
	var heavy: bool = p["fam"] == "heavy"
	var flat: bool = p.get("flat", false)
	var facet: bool = p.get("facet", false)
	var n := 12 if facet else 16
	# egzoz isi: lülenin 3,5 m önünden başlayıp ağzında en koyu
	var nzs: Array = p["noz"]
	k.soot = Vector3((nzs[3] + 3.5) * S, (nzs[3] - 0.3) * S, (nzs[0] + nzs[2] * 2.4) * S * STY.x)
	k.push(Vector3.ZERO, Vector3.ZERO, S)
	k.push_scale(STY)
	# gövde: burun (radom) ve geri kalanı
	var tpl: Array = HEAVY if heavy else LIGHT
	var st: Array = []
	for i in tpl.size():
		var r: Array = tpl[i]
		var sq: float = r[5] + (1.2 if facet else 0.0)
		var wm: float = r[1]
		var tm: float = r[2]
		var bm: float = r[3]
		if flat and i <= 5:
			wm *= 1.35
			tm *= 0.72
			bm *= 0.8
			sq = 3.4
		st.append([r[0] * L, wm * W, tm * H, bm * H, r[4] * H, sq])
	var ni: String = p["intake"][0]
	if ni == "nose":
		st[0] = [L * 0.5, W * 0.85, H * 0.85, H * 0.85, 0.0, 2.0]
		st[1] = [L * 0.47, W * 0.9, H * 0.9, H * 0.9, 0.0, 2.0]
	_fuse(k, "radome", st.slice(0, 4), n)
	_fuse(k, "skin", st.slice(3), n)
	if p.has("pitot"):
		k.lathe("steel", [Vector2(0.04, 0), Vector2(0.015, 0.8), Vector2(0, 0.82)], Vector3(0, st[0][4], st[0][0] - 0.05), Vector3(90, 0, 0), 5)
	if p.has("spine"):
		var sp: Array = p["spine"]
		var yb: float = H * 0.7
		k.loft("skin", [_sec(sp[0], 0.0, yb, sp[2] * 0.6, sp[3] * 0.5, 0.05, 2.2, 10), _sec(lerpf(sp[0], sp[1], 0.3), 0.0, yb, sp[2], sp[3], 0.05, 2.2, 10),
			_sec(sp[1], 0.0, yb - 0.1, sp[2] * 0.4, 0.15, 0.05, 2.2, 10)], true, true)
	if p.has("stinger"):
		var sz: float = p["stinger"]
		k.loft("skin", [_sec(-L * 0.44, 0.0, H * 0.05, W * 0.36, H * 0.32, H * 0.26, 2.2, 12), _sec(sz + 0.6, 0.0, 0.05, 0.3, 0.3, 0.3, 2.0, 12),
			_sec(sz, 0.0, 0.05, 0.08, 0.08, 0.08, 2.0, 12)], true, true)
	# naseller ve aralarındaki yassı gövde (çift motorlu ağır uçaklar)
	if p.has("pods"):
		var pd: Array = p["pods"]
		var px: float = pd[0]
		var py: float = pd[1]
		var pr: float = pd[2]
		k.loft("skin", [_sec(pd[3] + 0.6, 0.0, py + pr * 0.2, px * 0.6, pr * 0.7, pr * 0.4, 3.0, 12),
			_sec(pd[3] - 1.0, 0.0, py + pr * 0.25, px + pr * 0.85, pr * 0.85, pr * 0.65, 3.6, 12),
			_sec(-L * 0.38, 0.0, py + pr * 0.25, px + pr * 0.8, pr * 0.8, pr * 0.6, 3.6, 12),
			_sec(pd[4] + 0.2, 0.0, py + pr * 0.2, px + pr * 0.4, pr * 0.6, pr * 0.5, 3.0, 12)], false, true)
		for sx in [-1.0, 1.0]:
			k.loft("skin", [_sec(pd[3], px * sx, py, pr * 0.92, pr * 0.95, pr * 0.95, 2.4, 14),
				_sec(lerpf(pd[3], pd[4], 0.5), px * sx, py, pr, pr, pr, 2.2, 14), _sec(pd[4], px * sx, py, pr * 0.96, pr * 0.96, pr * 0.96, 2.0, 14)], true, true)
	_intake(k, p["intake"], p.get("pods", []), L)
	# kanopi ve önündeki mat siyah parlama önleyici panel
	var cn: Array = p["can"]
	if ni != "nose":
		_strip(k, "plastic", st, cn[0] + 1.6, cn[0] - 0.2, 34.0)
	_canopy(k, cn)
	# kanatlar ve kuyruk
	var w: Array = p["wing"]
	if p.has("glove"):
		var g: Array = p["glove"]
		for sx in [-1.0, 1.0]:
			_wing(k, "skin", [g[0], g[1], g[2], g[3], g[4], g[5], w[6], 0.035, 0.0], sx, "", false)
	for sx in [-1.0, 1.0]:
		_wing(k, "skin", w, sx, "ail_l" if sx < 0.0 else "ail_r", false, BAND)
		if p.has("stab"):
			_wing(k, "skin", p["stab"], sx, "stab_l" if sx < 0.0 else "stab_r", true)
		if p.has("canard"):
			_wing(k, "skin", p["canard"], sx, "can_l" if sx < 0.0 else "can_r", true)
	if p.has("lerx"):
		var lx: Array = p["lerx"]
		for sx in [-1.0, 1.0]:
			var a := [Vector3(lx[0] * sx, w[6] - 0.04, lx[1]), Vector3(lx[2] * sx, w[6] - 0.04, lx[3]), Vector3(lx[0] * sx, w[6] - 0.04, lx[4])]
			var b := [Vector3(lx[0] * sx, w[6] + 0.06, lx[1] - 0.2), Vector3(lx[2] * sx, w[6] + 0.04, lx[3]), Vector3(lx[0] * sx, w[6] + 0.1, lx[4])]
			k.loft("skin", [a, b])
	var fin: Array = p["fin"]
	if fin[0] > 0.0:
		for sx in [-1.0, 1.0]:
			_fin(k, "skin", fin, sx, "rud_l" if sx < 0.0 else "rud_r", true)
	else:
		_fin(k, "skin", fin, 1.0, "rud", true)
	if p.has("ventral"):
		var vf: Array = p["ventral"]
		if vf[0] > 0.0:
			for sx in [-1.0, 1.0]:
				_fin(k, "skin", vf, sx, "", false)
		else:
			_fin(k, "skin", vf, 1.0, "", false)
	# lüleler ve art yakıcı
	var nz: Array = p["noz"]
	if nz[0] > 0.0:
		_nozzle(k, -nz[0], nz[1], nz[2], nz[3], 0)
		_nozzle(k, nz[0], nz[1], nz[2], nz[3], 1)
	else:
		_nozzle(k, 0.0, nz[1], nz[2], nz[3], 0)
	# işaretler ve ışıklar
	var rx := lerpf(w[0], w[3], 0.62)
	var top := _wtop(w, rx)
	var chord := absf(lerpf(w[1], w[4], 0.62) - lerpf(w[2], w[5], 0.62))
	for sx in [-1.0, 1.0]:
		_mark(k, Vector3(rx * sx, top.x + 0.005, top.y), minf(0.65, chord * 0.32))
	var tip := _wtop(w, w[3])
	var fy: float = fin[7]
	_nav(k, Vector3(w[3] + 0.05, tip.x - 0.05, lerpf(w[4], w[5], 0.3)), Vector3(fin[0], fy + 0.08, lerpf(fin[5], fin[6], 0.5)), 0.12)
	# dış yükler: cephane sayısı kadar, iki kanada sırayla
	if cls == "stealth":
		k.pop()
		k.pop()
		return
	var spots: Array = []
	var tips: bool = p.get("tips", false)
	if cls == "striker":
		spots = [0.5, 0.3, 0.72]
	elif tips:
		spots = [1.0, 0.62, 0.38]
	else:
		spots = [0.68, 0.42, 0.22]
	var ml := L * 0.19
	var idx := 0
	for f in spots:
		for sx in [-1.0, 1.0]:
			if idx >= ammo:
				break
			var x: float = lerpf(w[0], w[3], f)
			var wt := _wtop(w, x)
			var wy: float = w[6] + (x - w[0]) * tan(deg_to_rad(w[8]))
			var name := "store%d" % idx
			if f >= 1.0:
				k.box("skin2", Vector3(0.1, 0.12, ml * 0.75), Vector3(x * sx + 0.06 * sx, wy, wt.y))
				_missile(k, Vector3((x + 0.16) * sx, wy, wt.y - 0.2), ml, 0.09, name)
			else:
				_pylon(k, Vector3(x * sx, wy - 0.05, wt.y), ml * 0.55, 0.3)
				if cls == "striker":
					_bomb(k, Vector3(x * sx, wy - 0.6, wt.y - 0.2), ml * 0.85, 0.2, name)
				else:
					_missile(k, Vector3(x * sx, wy - 0.45, wt.y - 0.3), ml, 0.09, name)
			idx += 1
	if cls == "striker":
		var cy: float = -H * 1.1 - 0.3
		k.lathe("skin2", [Vector2(0, 0), Vector2(0.28, 0.5), Vector2(0.32, 2.0), Vector2(0.2, 3.2), Vector2(0, 3.6)], Vector3(0, cy, -2.4), Vector3(90, 0, 0), 12)
	k.pop()
	k.pop()


## Hava alığı. a: [tür, x, y, ön z, arka z, yarı genişlik, yarı yükseklik]. pd: nasel (varsa ağız nasele bağlanır).
static func _intake(k: Kit, a: Array, pd: Array, L: float) -> void:
	var t: String = a[0]
	var x: float = a[1]
	var y: float = a[2]
	var zf: float = a[3]
	var zr: float = a[4]
	var hw: float = a[5]
	var hh: float = a[6]
	if t == "nose":
		k.lathe("dark", [Vector2(0, 0), Vector2(hw * 0.86, 0), Vector2(hw * 0.86, 0.01), Vector2(0, 0.012)], Vector3(0, 0, zf - 0.08), Vector3(90, 0, 0), 14)
		k.lathe("radome", [Vector2(hw * 0.45, 0), Vector2(hw * 0.35, 0.6), Vector2(0.03, 1.2)], Vector3(0, 0, zf - 0.3), Vector3(90, 0, 0), 12)
		return
	if t == "chin":
		k.loft("skin", [_sec(zf, 0.0, y, hw, hh, hh, 3.5, 12), _sec(zf - 0.6, 0.0, y + 0.05, hw, hh * 1.05, hh, 3.5, 12),
			_sec(zr, 0.0, y + hh * 0.7, hw * 0.8, hh * 0.6, hh * 0.4, 3.0, 12)], false, true)
		k.loft("dark", [_sec(zf + 0.01, 0.0, y, hw * 0.86, hh * 0.8, hh * 0.8, 3.5, 12), _sec(zf - 0.3, 0.0, y, hw * 0.84, hh * 0.78, hh * 0.78, 3.5, 12)])
		return
	for sx in [-1.0, 1.0]:
		var cx := x * sx
		var ex: float = cx if pd.is_empty() else float(pd[0]) * sx
		var ey: float = y if pd.is_empty() else float(pd[1])
		var sq := 2.2 if t == "semi" else 3.6
		k.loft("skin", [_sec(zf, cx, y, hw, hh, hh, sq, 12), _sec(lerpf(zf, zr, 0.3), lerpf(cx, ex, 0.3), lerpf(y, ey, 0.3), hw, hh, hh, sq, 12),
			_sec(zr, ex - (0.0 if not pd.is_empty() else sx * hw * 0.6), ey, hw * (1.0 if not pd.is_empty() else 0.4), hh * 0.95, hh * 0.95, sq, 12)], false, true)
		k.loft("dark", [_sec(zf + 0.01, cx, y, hw * 0.84, hh * 0.84, hh * 0.84, sq, 12), _sec(zf - 0.3, cx, y, hw * 0.82, hh * 0.82, hh * 0.82, sq, 12)])
		if t == "semi":
			k.lathe("radome", [Vector2(hw * 0.5, 0), Vector2(hw * 0.3, 0.4), Vector2(0.02, 0.9)], Vector3(cx - sx * hw * 0.3, y, zf - 0.4), Vector3(90, 0, 0), 10)


# ---------------------------------------------------------------- küçük İHA'lar

## DJI Mavic / FPV / Switch: dört kollu dron (görünürlük için büyütülmüş). Kamera gimbali döner, ışıkları yanıp söner.
static func _quad(k: Kit, pk: Kit) -> Array:
	var s := 4.0
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_fuse(k, "plastic", [[0.12, 0.02, 0.015, 0.015, 0.0, 2.0], [0.1, 0.04, 0.03, 0.025, 0.0, 2.4], [0.04, 0.05, 0.04, 0.035, 0.0, 2.8],
		[-0.06, 0.05, 0.042, 0.035, 0.0, 2.8], [-0.12, 0.035, 0.03, 0.025, 0.0, 2.4]], 12)
	k.box("team", Vector3(0.05, 0.006, 0.08), Vector3(0, 0.043, -0.01))
	_eo(k, Vector3(0, -0.04, 0.1), 0.018)
	var hubs: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var m := Vector3(0.14 * sx, 0.012, 0.12 * sz)
			k.push(Vector3(0.07 * sx, 0.0, 0.06 * sz), Vector3(0, rad_to_deg(atan2(0.14 * sx, 0.12 * sz)), 0))
			k.box("plastic", Vector3(0.014, 0.012, 0.19), Vector3.ZERO)
			k.pop()
			k.lathe("dark", [Vector2(0.016, -0.02), Vector2(0.016, 0.018), Vector2(0, 0.022)], m, Vector3.ZERO, 10)
			k.box("navg" if sz > 0.0 else "navr", Vector3(0.008, 0.006, 0.008), m + Vector3(0, -0.022, 0))
			k.box("plastic", Vector3(0.006, 0.05, 0.006), m + Vector3(0, -0.045, 0))
			hubs.append([m + Vector3(0, 0.026, 0), Vector3.ZERO])
	k.begin_part("strobe", Vector3(0, 0.0, -0.12), Vector3(0, 1, 0))
	k.box("navw", Vector3(0.01, 0.006, 0.006), Vector3(0, 0.0, -0.122))
	k.end_part()
	_prop(pk, 2, 0.12, 0.02)
	k.pop()
	pk.pop()
	return _hubs(s, hubs)


## Baba Yaga: altı kollu ağır bombardıman dronu, altında bomba (cephane), ışıklar.
static func _hexa(k: Kit, pk: Kit, ammo: int) -> Array:
	var s := 1.25
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_fuse(k, "plastic", [[0.25, 0.08, 0.05, 0.04, 0.0, 3.0], [0.18, 0.14, 0.09, 0.06, 0.0, 3.4], [-0.18, 0.14, 0.09, 0.06, 0.0, 3.4], [-0.25, 0.08, 0.05, 0.04, 0.0, 3.0]], 12)
	k.box("skin2", Vector3(0.2, 0.08, 0.3), Vector3(0, 0.12, 0))
	k.box("team", Vector3(0.16, 0.01, 0.2), Vector3(0, 0.165, 0))
	_eo(k, Vector3(0, -0.08, 0.2), 0.04)
	var hubs: Array = []
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var e := Vector3(cos(a), 0.0, sin(a)) * 0.8
		k.push(e * 0.5, Vector3(0, rad_to_deg(atan2(e.x, e.z)), 0))
		k.lathe("plastic", [Vector2(0.024, -0.4), Vector2(0.024, 0.4)], Vector3.ZERO, Vector3(90, 0, 0), 6)
		k.pop()
		k.lathe("dark", [Vector2(0.045, -0.04), Vector2(0.045, 0.04), Vector2(0, 0.05)], e, Vector3.ZERO, 10)
		k.box("navg" if e.z > 0.0 else "navr", Vector3(0.025, 0.02, 0.025), e + Vector3(0, -0.05, 0))
		hubs.append([e + Vector3(0, 0.06, 0), Vector3.ZERO])
	for sx in [-1.0, 1.0]:
		k.box("plastic", Vector3(0.02, 0.3, 0.02), Vector3(0.18 * sx, -0.2, 0), Vector3(0, 0, 12 * sx))
		k.box("plastic", Vector3(0.025, 0.025, 0.55), Vector3(0.21 * sx, -0.34, 0))
	for i in mini(ammo, 2):
		_bomb(k, Vector3(-0.07 + i * 0.14, -0.16, 0.0), 0.42, 0.06, "store%d" % i)
	k.begin_part("strobe", Vector3(0, 0.17, -0.1), Vector3(0, 1, 0))
	k.box("navw", Vector3(0.03, 0.02, 0.03), Vector3(0, 0.17, -0.1))
	k.end_part()
	_prop(pk, 2, 0.36, 0.05)
	k.pop()
	pk.pop()
	return _hubs(s, hubs)


## Orlan-10 / Orbiter / Ababil / Uqab: yüksek kanatlı, burunda pervaneli küçük keşif uçağı; kanatçık, irtifa ve yön dümeni oynar.
static func _orlan(k: Kit, pk: Kit) -> Array:
	var s := 0.7
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_fuse(k, "skin", [[0.84, 0.06, 0.06, 0.06, 0.0, 2.0], [0.75, 0.11, 0.11, 0.1, 0.0, 2.2], [0.5, 0.13, 0.15, 0.12, 0.01, 2.4],
		[0.1, 0.12, 0.14, 0.1, 0.02, 2.4], [-0.3, 0.07, 0.08, 0.06, 0.03, 2.2], [-1.45, 0.03, 0.035, 0.03, 0.03, 2.0]], 12)
	var w := [0.05, 0.3, 0.02, 1.55, 0.24, 0.05, 0.16, 0.12, 2.0, 0.55, 0.95]
	for sx in [-1.0, 1.0]:
		_wing(k, "skin", w, sx, "ail_l" if sx < 0.0 else "ail_r", false, 0.16)
		_wing(k, "skin", [0.03, -1.18, -1.36, 0.45, -1.26, -1.42, 0.03, 0.08, 0.0], sx, "stab_l" if sx < 0.0 else "stab_r", true)
		_mark(k, Vector3(1.0 * sx, 0.18, 0.13), 0.09)
	_fin(k, "skin", [0.0, 0.0, -1.12, -1.4, 0.04, -1.32, -1.45, 0.42], 1.0, "rud", true)
	_eo(k, Vector3(0, -0.15, 0.4), 0.06)
	_nav(k, Vector3(1.56, 0.17, 0.2), Vector3(0, 0.46, -1.4), 0.025)
	_prop(pk, 2, 0.3, 0.05)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, 0.88), Vector3(90, 0, 0)]])


## Lancet-3 / Hero / Meraj / Nagastra: boru gövde, önde ve arkada X kanatlar (arkadakiler dümen), arkada itici pervane.
static func _lancet(k: Kit, pk: Kit) -> Array:
	var s := 1.0
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_fuse(k, "skin", [[0.82, 0.03, 0.03, 0.03, 0.0, 2.0], [0.74, 0.06, 0.06, 0.06, 0.0, 2.0], [0.62, 0.08, 0.08, 0.08, 0.0, 2.0],
		[-0.6, 0.08, 0.08, 0.08, 0.0, 2.0], [-0.74, 0.05, 0.05, 0.05, 0.0, 2.0]], 12)
	k.lathe("glass", [Vector2(0.06, 0), Vector2(0.04, 0.05), Vector2(0, 0.07)], Vector3(0, 0, 0.78), Vector3(90, 0, 0), 10)
	k.lathe("team", [Vector2(0.082, 0.0), Vector2(0.082, 0.12)], Vector3(0, 0, 0.2), Vector3(90, 0, 0), 12)
	for i in 4:
		var a := 45.0 + 90.0 * i
		k.push(Vector3.ZERO, Vector3(0, 0, a))
		_wing(k, "skin", [0.07, 0.42, 0.06, 0.62, 0.25, 0.08, 0.0, 0.08, 0.0], 1.0, "", false)
		var nm: String = ["ail_l", "ail_r", "stab_l", "stab_r"][i]
		_wing(k, "skin", [0.07, -0.42, -0.62, 0.48, -0.52, -0.64, 0.0, 0.08, 0.0], 1.0, nm, true)
		k.pop()
	_prop(pk, 2, 0.17, 0.035)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -0.8), Vector3(90, 0, 0)]])


## Shahed-136 / Geran-2 (sc 0.85), Shahed-131 (sc 0.5): delta kanat, uçlarda dümenli dikey yüzeyler, arkada pervane.
static func _shahed(k: Kit, pk: Kit, sc: float) -> Array:
	k.push(Vector3.ZERO, Vector3.ZERO, sc)
	pk.push(Vector3.ZERO, Vector3.ZERO, sc)
	_fuse(k, "radome", [[1.75, 0.04, 0.04, 0.04, 0.0, 2.0], [1.6, 0.11, 0.11, 0.1, 0.0, 2.0], [1.35, 0.16, 0.16, 0.14, 0.0, 2.2]], 12)
	_fuse(k, "skin", [[1.35, 0.16, 0.16, 0.14, 0.0, 2.2], [0.8, 0.18, 0.18, 0.15, 0.0, 2.4], [-1.2, 0.18, 0.18, 0.15, 0.0, 2.4], [-1.5, 0.13, 0.13, 0.12, 0.0, 2.2]], 12)
	for sx in [-1.0, 1.0]:
		_wing(k, "skin", [0.16, 1.3, -1.25, 1.25, -1.0, -1.45, 0.0, 0.05, 0.0, 0.15, 0.85], sx, "ail_l" if sx < 0.0 else "ail_r", false, 0.14)
		_fin(k, "skin", [1.27, 0.0, -0.85, -1.45, -0.2, -1.1, -1.48, 0.38], sx, "rud_l" if sx < 0.0 else "rud_r", true)
		_mark(k, Vector3(0.62 * sx, 0.05, -0.65), 0.16)
	k.lathe("dark", [Vector2(0.12, 0), Vector2(0.11, 0.18), Vector2(0.04, 0.24)], Vector3(0, 0.0, -1.5), Vector3(-90, 0, 0), 12)
	_nav(k, Vector3(1.27, 0.4, -1.3), Vector3(0, 0.2, -1.2), 0.03)
	_prop(pk, 2, 0.38, 0.06)
	k.pop()
	pk.pop()
	return _hubs(sc, [[Vector3(0, 0, -1.78), Vector3(90, 0, 0)]])


## Harop: önde küçük kanard, arkada kanat uçları dikey yüzeyli ok kanat, itici pervane.
static func _harop(k: Kit, pk: Kit) -> Array:
	var s := 1.0
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_fuse(k, "skin", [[1.35, 0.03, 0.03, 0.03, -0.02, 2.0], [1.2, 0.11, 0.11, 0.1, -0.01, 2.2], [0.8, 0.16, 0.18, 0.15, 0.0, 2.6],
		[-0.6, 0.16, 0.17, 0.14, 0.0, 2.6], [-1.05, 0.09, 0.09, 0.08, 0.0, 2.2]], 12)
	for sx in [-1.0, 1.0]:
		_wing(k, "skin", [0.14, 0.3, -0.55, 1.45, -0.75, -1.02, 0.04, 0.06, 0.0, 0.3, 0.9], sx, "ail_l" if sx < 0.0 else "ail_r", false, 0.16)
		_wing(k, "skin", [0.12, 1.0, 0.8, 0.42, 0.86, 0.78, 0.06, 0.06, 0.0], sx, "can_l" if sx < 0.0 else "can_r", true)
		_fin(k, "skin", [1.47, 0.0, -0.7, -1.0, 0.04, -0.9, -1.04, 0.42], sx, "rud_l" if sx < 0.0 else "rud_r", true)
		_mark(k, Vector3(0.82 * sx, 0.09, -0.55), 0.13)
	_eo(k, Vector3(0, -0.15, 1.0), 0.07)
	_nav(k, Vector3(1.47, 0.44, -0.95), Vector3(0, 0.18, -0.6), 0.03)
	_prop(pk, 2, 0.32, 0.05)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -1.12), Vector3(90, 0, 0)]])


# ---------------------------------------------------------------- büyük İHA'lar

## İki kirişli İHA ortak gövdesi. span, ln (gövde boyu), bx (kirişlerin x'i), wy (kanat y), tz (kiriş sonu), chord.
static func _twin(k: Kit, span: float, ln: float, bx: float, wy: float, tz: float, chord: float, ammo: int) -> void:
	var hz := ln * 0.5
	_fuse(k, "skin", [[hz, 0.05, 0.05, 0.05, -0.02, 2.0], [hz - 0.25, 0.22, 0.24, 0.2, -0.02, 2.0], [hz - 0.8, 0.34, 0.38, 0.32, 0.0, 2.2],
		[hz - 1.8, 0.38, 0.42, 0.36, 0.02, 2.4], [0.0, 0.36, 0.4, 0.33, 0.02, 2.4], [-hz * 0.6, 0.26, 0.28, 0.24, 0.02, 2.2],
		[-hz + 0.15, 0.13, 0.14, 0.13, 0.02, 2.0]], 14)
	var w := [0.25, chord * 0.65, -chord * 0.35, span * 0.5, chord * 0.45, -chord * 0.15, wy, 0.13, 1.5, 0.55, 0.95]
	for sx in [-1.0, 1.0]:
		_wing(k, "skin", w, sx, "ail_l" if sx < 0.0 else "ail_r", false, 0.12)
		k.loft("skin", [_sec(chord * 0.55, bx * sx, wy - 0.06, 0.06, 0.06, 0.06, 2.0, 10), _sec(chord * 0.3, bx * sx, wy - 0.06, 0.09, 0.09, 0.09, 2.0, 10),
			_sec(tz + 0.3, bx * sx, wy - 0.06, 0.07, 0.07, 0.07, 2.0, 10), _sec(tz, bx * sx, wy - 0.06, 0.04, 0.04, 0.04, 2.0, 10)], true, true)
		var mx := span * 0.33
		var t := _wtop(w, mx)
		_mark(k, Vector3(mx * sx, t.x + 0.01, t.y), minf(0.45, chord * 0.3))
	var tip := _wtop(w, span * 0.5)
	_nav(k, Vector3(span * 0.5 + 0.03, tip.x - 0.02, tip.y), Vector3(0, 0.45, 0.0), 0.08)
	for i in ammo:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var x := span * (0.2 + 0.08 * floorf(i * 0.5)) * sx
		_pylon(k, Vector3(x, wy - 0.05, chord * 0.15), 0.6, 0.15)
		_bomb(k, Vector3(x, wy - 0.33, chord * 0.1), 1.0, 0.08, "store%d" % i)
	_eo(k, Vector3(0, -0.46, hz - 0.8), 0.18)
	k.lathe("dark", [Vector2(0.13, 0), Vector2(0.1, 0.12), Vector2(0.03, 0.16)], Vector3(0, 0.02, -hz + 0.15), Vector3(-90, 0, 0), 10)
	k.box("skin2", Vector3(0.05, 0.25, 0.4), Vector3(0, 0.45, 0.6))


## Bayraktar TB2: iki kirişi birleştiren ters V kuyruk (tepesi ortada, yüzeyleri oynar), arasında itici pervane.
static func _tb2(k: Kit, pk: Kit, ammo: int) -> Array:
	var s := 0.45
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_twin(k, 12.0, 6.5, 1.15, 0.32, -2.95, 0.95, ammo)
	for sx in [-1.0, 1.0]:
		_fin(k, "skin", [1.15, -50.0, -2.2, -2.95, 0.26, -2.6, -3.05, 1.76], sx, "rud_l" if sx < 0.0 else "rud_r", false)
	_prop(pk, 2, 0.85, 0.13)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0.02, -3.35), Vector3(90, 0, 0)]])


## Kirişlerin sonunda iki dikey kuyruk ve aralarında oynar irtifa dümenli yatay dengeleyici.
static func _htail(k: Kit, bx: float, y: float, z: float, fh: float, ch: float) -> void:
	for sx in [-1.0, 1.0]:
		_fin(k, "skin", [bx, 0.0, z + ch * 0.3, z - ch * 0.7, y, z - ch * 0.35, z - ch * 0.75, y + fh], sx, "rud_l" if sx < 0.0 else "rud_r", true)
		_wing(k, "skin", [0.0, z - ch * 0.05, z - ch * 0.75, bx, z - ch * 0.15, z - ch * 0.75, y + fh * 0.55, 0.08, 0.0, 0.0, 1.0],
			sx, "stab_l" if sx < 0.0 else "stab_r", false)


## IAI Heron / Heron TP: uzun kanat, iki kiriş, H kuyruk, burun üstünde uydu anteni kamburu.
static func _heron(k: Kit, pk: Kit) -> Array:
	var s := 0.42
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_twin(k, 16.6, 8.5, 1.6, 0.35, -4.4, 1.0, 0)
	_fuse(k, "skin", [[3.7, 0.06, 0.04, 0.04, 0.3, 2.0], [3.1, 0.32, 0.28, 0.05, 0.3, 2.0], [1.9, 0.3, 0.24, 0.05, 0.3, 2.0], [1.0, 0.1, 0.05, 0.05, 0.32, 2.0]], 12)
	_htail(k, 1.6, 0.3, -3.9, 1.2, 1.0)
	_prop(pk, 3, 0.95, 0.16)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0.02, -4.4), Vector3(90, 0, 0)]])


## Mohajer-6: köşeli gövde, yüksek kanat, kirişlerin üstünde yatay dengeleyici.
static func _mohajer(k: Kit, pk: Kit, ammo: int) -> Array:
	var s := 0.5
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_twin(k, 10.0, 5.6, 1.1, 0.34, -2.9, 0.85, ammo)
	_htail(k, 1.1, 0.3, -2.45, 0.85, 0.8)
	_prop(pk, 2, 0.7, 0.12)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0.02, -2.95), Vector3(90, 0, 0)]])


## AN-196 Liutyi: alçak kanat, iki kiriş, arkada üç kanatlı itici pervane, burnu harp başlıklı.
static func _liutyi(k: Kit, pk: Kit) -> Array:
	var s := 0.55
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_twin(k, 6.7, 4.4, 0.85, -0.18, -2.3, 0.75, 0)
	_htail(k, 0.85, -0.18, -1.9, 0.75, 0.6)
	_prop(pk, 3, 0.55, 0.1)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0.02, -2.3), Vector3(90, 0, 0)]])


## MQ-9 / Hermes 900 / Orion / Shahed-129 / Burraq: ince uzun gövde, burun üstü uydu kamburu, çok uzun kanat,
## V kuyruk ve altta dümenli dikey yüzey, arkada üç kanatlı itici pervane.
static func _mq9(k: Kit, pk: Kit, ammo: int) -> Array:
	var s := 0.32
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_fuse(k, "skin", [[5.6, 0.08, 0.08, 0.08, -0.05, 2.0], [5.3, 0.36, 0.4, 0.3, -0.02, 2.0], [4.6, 0.48, 0.62, 0.38, 0.05, 2.2],
		[3.4, 0.48, 0.62, 0.4, 0.05, 2.3], [2.2, 0.45, 0.46, 0.42, 0.0, 2.4], [0.0, 0.42, 0.42, 0.4, 0.0, 2.4], [-3.2, 0.26, 0.26, 0.25, 0.0, 2.2],
		[-4.8, 0.13, 0.13, 0.13, 0.0, 2.0]], 14)
	var w := [0.35, 0.8, -0.45, 10.0, 0.35, -0.15, 0.2, 0.13, 1.0, 0.55, 0.92]
	for sx in [-1.0, 1.0]:
		_wing(k, "skin", w, sx, "ail_l" if sx < 0.0 else "ail_r", false, 0.1)
		_fin(k, "skin", [0.15, 45.0, -3.3, -4.7, 0.2, -4.3, -4.8, 2.0], sx, "rud_l" if sx < 0.0 else "rud_r", true)
		_mark(k, Vector3(6.0 * sx, 0.42, 0.15), 0.4)
	_fin(k, "skin", [0.0, 0.0, -3.8, -4.7, -0.15, -4.4, -4.75, -1.2], 1.0, "rud", false)
	var hp := [3.0, 5.0, 4.0, 6.0]
	for i in ammo:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var x: float = hp[i % 4] * sx
		_pylon(k, Vector3(x, 0.16, 0.2), 0.6, 0.2)
		_missile(k, Vector3(x, -0.15, -0.1), 1.6, 0.09, "store%d" % i)
	_eo(k, Vector3(0, -0.52, 4.3), 0.28)
	_nav(k, Vector3(10.03, 0.35, 0.1), Vector3(0, 0.62, 3.6), 0.12)
	_prop(pk, 3, 1.3, 0.2)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -4.95), Vector3(90, 0, 0)]])


## Bayraktar Akıncı: uzun gövde, uçları yukarı bükük kanat, kanatlarda iki turboprop (çekici pervane), V kuyruk.
static func _akinci(k: Kit, pk: Kit, ammo: int) -> Array:
	var s := 0.36
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_fuse(k, "skin", [[6.1, 0.08, 0.08, 0.08, -0.05, 2.0], [5.7, 0.42, 0.42, 0.36, -0.03, 2.0], [4.8, 0.6, 0.66, 0.52, 0.02, 2.2],
		[3.0, 0.64, 0.7, 0.56, 0.03, 2.4], [0.0, 0.6, 0.62, 0.54, 0.0, 2.5], [-3.5, 0.38, 0.38, 0.32, 0.0, 2.3], [-6.0, 0.14, 0.14, 0.14, 0.0, 2.0]], 14)
	k.loft("glass", [_dome(5.1, 0.45, 0.25, 0.04), _dome(4.8, 0.45, 0.35, 0.18), _dome(4.3, 0.45, 0.32, 0.16), _dome(4.0, 0.45, 0.12, 0.04)], true, true)
	var w := [0.5, 1.25, -0.75, 7.0, 0.7, -0.35, 0.1, 0.14, 2.0]
	for sx in [-1.0, 1.0]:
		_wing(k, "skin", w, sx, "", false)
		# bükük dış kanat (kanatçıklı)
		k.push(Vector3(7.0 * sx, 0.1 + 6.5 * tan(deg_to_rad(2.0)), 0), Vector3(0, 0, 9.0 * sx))
		_wing(k, "skin", [0.0, 0.7, -0.35, 3.0, 0.4, -0.2, 0.0, 0.12, 0.0, 0.05, 0.9], sx, "ail_l" if sx < 0.0 else "ail_r", false, 0.25)
		k.box("navr" if sx < 0.0 else "navg", Vector3(0.1, 0.1, 0.16), Vector3(3.03 * sx, 0.0, 0.2))
		k.pop()
		# motor naseli
		k.loft("skin2", [_sec(2.35, 2.6 * sx, 0.1, 0.24, 0.26, 0.24, 2.0, 12), _sec(1.9, 2.6 * sx, 0.1, 0.34, 0.38, 0.36, 2.2, 12),
			_sec(-0.3, 2.6 * sx, 0.1, 0.32, 0.36, 0.3, 2.4, 12), _sec(-1.3, 2.6 * sx, 0.15, 0.1, 0.1, 0.1, 2.0, 12)], true, true)
		k.box("dark", Vector3(0.12, 0.08, 0.3), Vector3(2.6 * sx + 0.3 * sx, 0.0, -0.6))
		_mark(k, Vector3(4.6 * sx, 0.38, 0.2), 0.42)
		_fin(k, "skin", [0.2, 40.0, -4.3, -5.9, 0.3, -5.4, -6.0, 2.1], sx, "rud_l" if sx < 0.0 else "rud_r", true)
	for i in ammo:
		var sx := -1.0 if i % 2 == 0 else 1.0
		var x := (3.6 + 1.2 * floorf(i * 0.5)) * sx
		_pylon(k, Vector3(x, 0.05, 0.2), 0.7, 0.2)
		_bomb(k, Vector3(x, -0.38, 0.0), 1.8, 0.13, "store%d" % i)
	_eo(k, Vector3(0, -0.64, 4.8), 0.3)
	k.begin_part("strobe", Vector3(0, 0.62, 0.0), Vector3(0, 1, 0))
	k.box("navw", Vector3(0.14, 0.1, 0.14), Vector3(0, 0.64, 0.0))
	k.end_part()
	_prop(pk, 4, 1.2, 0.2)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(2.6, 0.1, 2.45), Vector3(90, 0, 0)], [Vector3(-2.6, 0.1, 2.45), Vector3(90, 0, 0)]])


## S-70 Okhotnik-B / Ghatak: kuyruksuz uçan kanat, elevonları oynar, sırtında hava alığı, arkada tek jet lülesi.
static func _flyingwing(k: Kit) -> Array:
	var s := 0.34
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	for sx in [-1.0, 1.0]:
		_wing(k, "stealth", [0.0, 7.0, -5.8, 3.4, 3.0, -4.2, 0.0, 0.11, 0.0], sx, "", false)
		_wing(k, "stealth", [3.4, 3.0, -4.2, 9.9, -2.4, -3.6, 0.0, 0.07, 0.0, 0.1, 0.9], sx, "ail_l" if sx < 0.0 else "ail_r", false, 0.12)
		_mark(k, Vector3(6.0 * sx, 0.12, -1.8), 0.5)
	k.loft("stealth", [_sec(5.5, 0.0, 0.3, 0.6, 0.15, 0.1, 3.0, 12), _sec(3.0, 0.0, 0.3, 1.1, 0.55, 0.1, 3.0, 12), _sec(-2.5, 0.0, 0.3, 1.0, 0.5, 0.1, 3.0, 12),
		_sec(-5.0, 0.0, 0.3, 0.6, 0.2, 0.1, 3.0, 12)], false, true)
	k.box("dark", Vector3(1.1, 0.35, 0.05), Vector3(0, 0.62, 3.6), Vector3(-30, 0, 0))
	_nozzle(k, 0.0, 0.25, 0.5, -5.0, 0)
	_nav(k, Vector3(9.9, 0.0, -2.5), Vector3(0, 0.85, 0.0), 0.12)
	k.pop()
	return []
