class_name Buildings
extends RefCounted
## Bina modelleri, vinç ve ikmal noktaları. Ölçüler oyun birimindedir; ön taraf +Z. Hepsi Kit ile tek mesh kurulur:
## tabanlar topraklanır ve gölgelenir, takım rengi bayrak, çatı şeridi ve boyalı bantlarla gösterilir.
## Not: bu dosya yalnızca Kit çağrıları ve düz hesap içerir; geliştirme önizleme aracı da aynı kodu okur.

const IDS := ["hq", "santral", "maden", "kisla", "fabrika", "havaalani", "teknoloji", "fuze", "sam_box", "sam_tube",
	"crane", "supply_oil", "supply_crates", "obstacle", "house", "trench", "mine", "block", "ruin_factory", "deposit", "ileri"]


static func has(id: String) -> bool:
	return id in IDS


# Ulusal mimari: her ülkenin duvar, süsleme ve çatı renkleri, çatı tipi (düz ya da beşik) ve kubbe biçimi.
#   ua: badanalı beyaz duvar, yeşil çatı, altın armut kubbe (Kazak barok), mavi-sarı şerit
#   ru: kırmızı tuğla, beyaz taş süsleme, koyu yeşil çatı, çadır çatılı kule, kızıl yıldız, soğan kubbe
#   il: Kudüs taşı (krem kireçtaşı), düz çatı, güneş enerjili su ısıtıcıları, kemerli pencereler, mavi şerit
#   ir: kerpiç-tuğla, turkuaz kubbe, rüzgâr kuleleri (badgir), çini kemerli eyvan
#   pk: kırmızı kumtaşı, beyaz mermer Babür kubbesi ve çhatriler, yeşil şerit
#   in: pembe kumtaşı (Racput), çhatriler, cumbalı pencere (jharokha), safran şerit
const STYLES := {
	"ua": {wall = Color(0.86, 0.85, 0.8), trim = Color(0.66, 0.64, 0.58), roof = Color(0.24, 0.45, 0.32), dome = Color(0.86, 0.68, 0.24), accent = Color(0.12, 0.36, 0.72), accent2 = Color(0.98, 0.8, 0.1), flat = false},
	"ru": {wall = Color(0.6, 0.27, 0.21), trim = Color(0.84, 0.82, 0.76), roof = Color(0.17, 0.32, 0.23), dome = Color(0.86, 0.68, 0.24), accent = Color(0.8, 0.1, 0.08), accent2 = Color(0.86, 0.68, 0.24), flat = false},
	"il": {wall = Color(0.87, 0.81, 0.66), trim = Color(0.76, 0.7, 0.56), roof = Color(0.74, 0.69, 0.58), dome = Color(0.9, 0.9, 0.86), accent = Color(0.1, 0.3, 0.72), accent2 = Color(0.94, 0.94, 0.92), flat = true},
	"ir": {wall = Color(0.75, 0.61, 0.43), trim = Color(0.62, 0.5, 0.34), roof = Color(0.68, 0.56, 0.4), dome = Color(0.13, 0.6, 0.65), accent = Color(0.08, 0.35, 0.62), accent2 = Color(0.86, 0.68, 0.24), flat = true},
	"pk": {wall = Color(0.62, 0.31, 0.23), trim = Color(0.9, 0.88, 0.84), roof = Color(0.56, 0.31, 0.23), dome = Color(0.93, 0.92, 0.88), accent = Color(0.04, 0.44, 0.2), accent2 = Color(0.9, 0.88, 0.84), flat = true},
	"in": {wall = Color(0.8, 0.53, 0.43), trim = Color(0.88, 0.8, 0.66), roof = Color(0.7, 0.46, 0.37), dome = Color(0.86, 0.62, 0.5), accent = Color(0.95, 0.55, 0.15), accent2 = Color(0.07, 0.45, 0.1), flat = true},
}

static var _st := ""   # tasarlanan binanın mimari üslubu (ülke kodu ya da haritanın üslubu)


static func _style() -> Dictionary:
	return STYLES.get(_st, {})


## Araç yuvalarına ek olarak beton, sac, asfalt ve boya renkleri. Üslup verilirse duvar, süsleme ve çatı
## renkleri ülkenin mimarisine göre değişir.
static func slots(k: Kit, bc: Color, tc: Color, style := "") -> void:
	_st = style
	var st := _style()
	Vehicles.slots(k, bc, tc)
	k.slot("conc", "concrete", st.get("wall", Color(0.62, 0.61, 0.57)), 0.5)
	k.slot("conc2", "concrete", st.get("trim", Color(0.46, 0.46, 0.44)), 0.5)
	k.slot("roof", "corrug" if not st.get("flat", false) else "concrete", st.get("roof", Color(0.42, 0.45, 0.47)), 0.35)
	k.slot("dome", "paint", st.get("dome", Color(0.8, 0.8, 0.8)), 0.1)
	k.slot("accent", "paint", st.get("accent", Color(0.3, 0.3, 0.3)), 0.1)
	k.slot("accent2", "paint", st.get("accent2", Color(0.6, 0.6, 0.6)), 0.1)
	k.slot("gold", "steel", Color(0.92, 0.74, 0.28), 0.0)
	k.slot("solar", "optic", Color(0.08, 0.14, 0.3), 0.0)
	k.slot("sheet", "corrug", Color(0.6, 0.62, 0.6), 0.45)
	k.slot("asphalt", "concrete", Color(0.2, 0.2, 0.21), 0.3)
	k.slot("white", "fabric", Color(0.86, 0.86, 0.82), 0.15)
	k.slot("red", "fabric", Color(0.7, 0.16, 0.12), 0.1)
	k.slot("yellow", "steel", Color(0.95, 0.72, 0.1), 0.2)
	k.slot("ore", "concrete", Color(0.3, 0.26, 0.22), 0.3)
	k.slot("sand", "fabric", Color(0.62, 0.55, 0.4), 0.4)
	k.slot("teamroof", "corrug", tc.darkened(0.1), 0.15)


static func design(id: String, k: Kit, style := "") -> void:
	_st = style
	_design(id, k)
	if STYLES.has(style):
		_ornament(k, id)


static func _design(id: String, k: Kit) -> void:
	if id == "hq":
		_hq(k)
	elif id == "santral":
		_santral(k)
	elif id == "maden":
		_maden(k)
	elif id == "kisla":
		_kisla(k)
	elif id == "fabrika":
		_fabrika(k)
	elif id == "havaalani":
		_havaalani(k)
	elif id == "teknoloji":
		_teknoloji(k)
	elif id == "fuze":
		_fuze(k)
	elif id == "sam_box":
		_sam_box(k)
	elif id == "sam_tube":
		_sam_tube(k)
	elif id == "crane":
		_crane(k)
	elif id == "supply_oil":
		_supply(k, true)
	elif id == "obstacle":
		_obstacle(k)
	elif id == "house":
		_house(k)
	elif id == "block":
		_apartment(k)
	elif id == "ruin_factory":
		_ruin_factory(k)
	elif id == "deposit":
		_deposit(k)
	elif id == "ileri":
		_fob(k)
	elif id == "trench":
		_trench(k)
	elif id == "mine":
		_mine(k)
	else:
		_supply(k, false)


# ---------------------------------------------------------------- ortak parçalar

## Zemin plakası (beton / asfalt), kenarı hafif pahlı.
static func _slab(k: Kit, s: String, w: float, l: float, p: Vector3) -> void:
	k.loft(s, [
		[Vector3(p.x - w * 0.5, 0.0, p.z - l * 0.5), Vector3(p.x + w * 0.5, 0.0, p.z - l * 0.5), Vector3(p.x + w * 0.5, 0.0, p.z + l * 0.5), Vector3(p.x - w * 0.5, 0.0, p.z + l * 0.5)],
		[Vector3(p.x - w * 0.5 + 0.08, p.y, p.z - l * 0.5 + 0.08), Vector3(p.x + w * 0.5 - 0.08, p.y, p.z - l * 0.5 + 0.08),
			Vector3(p.x + w * 0.5 - 0.08, p.y, p.z + l * 0.5 - 0.08), Vector3(p.x - w * 0.5 + 0.08, p.y, p.z + l * 0.5 - 0.08)],
	])


## Blok: duvarlar ve üstte korkuluk çıkıntısı. c: taban merkezi.
static func _block(k: Kit, s: String, size: Vector3, c: Vector3) -> void:
	k.box(s, size, c + Vector3(0, size.y * 0.5, 0))
	k.box("conc2", Vector3(size.x + 0.12, 0.1, size.z + 0.12), c + Vector3(0, size.y + 0.02, 0))


## Beşik çatı: sırtı z boyunca. w genişlik, l boy, hgt sırt yüksekliği; c saçak hizasında merkez.
static func _gable(k: Kit, s: String, w: float, l: float, hgt: float, c: Vector3) -> void:
	if s == "roof" and _style().get("flat", false):
		# Düz çatılı üsluplar: beton döşeme ve korkuluk duvarı.
		k.box("conc2", Vector3(w, 0.14, l), c + Vector3(0, 0.07, 0))
		for sx in [-1.0, 1.0]:
			k.box("conc", Vector3(0.14, 0.32, l), c + Vector3(sx * (w * 0.5 - 0.07), 0.3, 0))
			k.box("conc", Vector3(w, 0.32, 0.14), c + Vector3(0, 0.3, sx * (l * 0.5 - 0.07)))
		return
	var a := [Vector3(c.x - w * 0.5, c.y, c.z - l * 0.5), Vector3(c.x + w * 0.5, c.y, c.z - l * 0.5), Vector3(c.x, c.y + hgt, c.z - l * 0.5)]
	var b := [Vector3(c.x - w * 0.5, c.y, c.z + l * 0.5), Vector3(c.x + w * 0.5, c.y, c.z + l * 0.5), Vector3(c.x, c.y + hgt, c.z + l * 0.5)]
	k.loft(s, [a, b])


## Ön / arka duvarda (z düzlemi) n pencere. x0..x1 arasında, y yüksekliğinde.
static func _win_z(k: Kit, x0: float, x1: float, y: float, z: float, n: int, hgt: float) -> void:
	for i in n:
		var x := lerpf(x0, x1, (i + 0.5) / n)
		k.box("conc2", Vector3((x1 - x0) / n * 0.72, hgt + 0.08, 0.05), Vector3(x, y, z))
		k.box("glass", Vector3((x1 - x0) / n * 0.6, hgt, 0.07), Vector3(x, y, z))


## Yan duvarda (x düzlemi) n pencere.
static func _win_x(k: Kit, z0: float, z1: float, y: float, x: float, n: int, hgt: float) -> void:
	for i in n:
		var z := lerpf(z0, z1, (i + 0.5) / n)
		k.box("conc2", Vector3(0.05, hgt + 0.08, (z1 - z0) / n * 0.72), Vector3(x, y, z))
		k.box("glass", Vector3(0.07, hgt, (z1 - z0) / n * 0.6), Vector3(x, y, z))


## Kapı (z düzleminde): kasa ve koyu kanat. big: araç kapısı (şeritli kepenk).
static func _door(k: Kit, p: Vector3, w: float, hgt: float, big: bool) -> void:
	k.box("conc2", Vector3(w + 0.16, hgt + 0.08, 0.06), p + Vector3(0, hgt * 0.5, 0))
	k.box("steel" if big else "dark", Vector3(w, hgt, 0.08), p + Vector3(0, hgt * 0.5 - 0.02, 0))
	if big:
		for i in 4:
			k.box("dark", Vector3(w, 0.03, 0.09), p + Vector3(0, hgt * (i + 0.5) / 4.0, 0))
		k.box("yellow", Vector3(w + 0.16, 0.08, 0.07), p + Vector3(0, hgt + 0.06, 0))


## Bayrak direği ve takım renginde bayrak.
static func _flag(k: Kit, p: Vector3, hgt: float) -> void:
	k.lathe("steel", [Vector2(0.05, 0), Vector2(0.03, hgt), Vector2(0, hgt + 0.05)], p, Vector3.ZERO, 6)
	k.box("team", Vector3(1.1, 0.65, 0.03), p + Vector3(0.58, hgt - 0.4, 0))
	k.box("team", Vector3(0.5, 0.6, 0.03), p + Vector3(0.9, hgt - 0.44, 0.04), Vector3(0, -14, 0))


## Kafes anten direği.
static func _mast(k: Kit, p: Vector3, hgt: float) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("steel", Vector3(0.04, hgt, 0.04), p + Vector3(0.12 * sx, hgt * 0.5, 0.12 * sz), Vector3(1.5 * sz, 0, -1.5 * sx))
	var n := int(hgt / 0.5)
	for i in n:
		k.box("steel", Vector3(0.28, 0.03, 0.28), p + Vector3(0, 0.3 + i * 0.5, 0))
	k.lathe("red", [Vector2(0.02, 0), Vector2(0.015, 0.9), Vector2(0, 0.9)], p + Vector3(0, hgt, 0), Vector3.ZERO, 5)
	k.box("white", Vector3(0.5, 0.12, 0.08), p + Vector3(0, hgt * 0.85, 0.16))


## Uydu / radar çanağı: ayak ve yukarı bakan çanak. tilt derece öne eğim.
static func _dish(k: Kit, p: Vector3, r: float, tilt: float) -> void:
	k.lathe("steel", [Vector2(r * 0.25, 0), Vector2(r * 0.12, r * 0.6), Vector2(0, r * 0.6)], p, Vector3.ZERO, 8)
	k.lathe("white", [Vector2(0.0, 0.0), Vector2(r * 0.5, r * 0.08), Vector2(r, r * 0.35), Vector2(r * 0.96, r * 0.37), Vector2(r * 0.5, r * 0.13), Vector2(0, r * 0.06)],
		p + Vector3(0, r * 0.6, 0), Vector3(tilt, 0, 0), 14)
	k.push(p + Vector3(0, r * 0.6, 0), Vector3(tilt, 0, 0))
	k.box("steel", Vector3(0.04, r * 0.75, 0.04), Vector3(0, r * 0.4, 0))
	k.pop()


## Klima / havalandırma kutusu.
static func _ac(k: Kit, p: Vector3) -> void:
	k.box("sheet", Vector3(0.7, 0.4, 0.5), p + Vector3(0, 0.2, 0))
	k.lathe("dark", [Vector2(0, 0), Vector2(0.18, 0), Vector2(0.18, 0.02), Vector2(0, 0.02)], p + Vector3(0, 0.4, 0), Vector3.ZERO, 8)


## Kum torbası duvarı: p'den başlar, yaw yönünde n torba, iki sıra.
static func _sandbags(k: Kit, p: Vector3, yaw: float, n: int) -> void:
	k.push(p, Vector3(0, yaw, 0))
	for j in 2:
		for i in n - j:
			Tanks._bag(k, "sand", Vector3(0.3, 0.2, 0.52), Vector3(0, 0.1 + j * 0.19, (i + j * 0.5) * 0.5), 0.0)
	k.pop()


## Dikey silindir tank / silo.
static func _tank(k: Kit, s: String, p: Vector3, r: float, hgt: float) -> void:
	k.lathe(s, [Vector2(r, 0), Vector2(r, hgt * 0.5), Vector2(r * 1.02, hgt * 0.52), Vector2(r, hgt * 0.54), Vector2(r, hgt), Vector2(r * 0.6, hgt + r * 0.18), Vector2(0, hgt + r * 0.22)],
		p, Vector3.ZERO, 14)


## Baca: kırmızı-beyaz uyarı şeritli.
static func _stack(k: Kit, p: Vector3, r: float, hgt: float) -> void:
	k.lathe("conc", [Vector2(r * 1.25, 0), Vector2(r, hgt * 0.7)], p, Vector3.ZERO, 10)
	k.lathe("red", [Vector2(r, hgt * 0.7), Vector2(r * 0.96, hgt * 0.8)], p, Vector3.ZERO, 10)
	k.lathe("white", [Vector2(r * 0.96, hgt * 0.8), Vector2(r * 0.93, hgt * 0.9)], p, Vector3.ZERO, 10)
	k.lathe("red", [Vector2(r * 0.93, hgt * 0.9), Vector2(r * 0.9, hgt), Vector2(r * 0.7, hgt), Vector2(r * 0.7, hgt - 0.1)], p, Vector3.ZERO, 10)
	k.lathe("dark", [Vector2(0, 0), Vector2(r * 0.71, 0), Vector2(0, 0.01)], p + Vector3(0, hgt - 0.1, 0), Vector3.ZERO, 8)


## Sandık yığını.
static func _crates(k: Kit, p: Vector3) -> void:
	k.box("wood", Vector3(0.7, 0.55, 0.7), p + Vector3(0, 0.28, 0), Vector3(0, 8, 0))
	k.box("wood", Vector3(0.7, 0.55, 0.7), p + Vector3(0.8, 0.28, 0.1), Vector3(0, -5, 0))
	k.box("wood", Vector3(0.65, 0.5, 0.65), p + Vector3(0.4, 0.8, 0.05), Vector3(0, 20, 0))
	k.box("hull2", Vector3(0.9, 0.35, 0.5), p + Vector3(0.3, 0.18, 0.85))


# ---------------------------------------------------------------- binalar

## Karargâh: iki katlı beton komuta binası, camlı harekât odası, çatıda çanak, anten, bayrak; girişte kum torbaları.
static func _hq(k: Kit) -> void:
	_slab(k, "conc2", 9.2, 9.2, Vector3(0, 0.12, 0))
	_block(k, "conc", Vector3(7.4, 2.5, 6.4), Vector3(0, 0.1, -0.6))
	k.box("team", Vector3(7.46, 0.3, 6.46), Vector3(0, 2.2, -0.6))
	_win_z(k, -3.4, -0.9, 1.5, 2.6, 4, 0.5)
	_win_z(k, 0.9, 3.4, 1.5, 2.6, 4, 0.5)
	_win_x(k, -3.4, 2.2, 1.5, 3.7, 6, 0.5)
	_win_x(k, -3.4, 2.2, 1.5, -3.7, 6, 0.5)
	_door(k, Vector3(0, 0.12, 2.61), 1.2, 1.5, false)
	k.box("conc2", Vector3(2.2, 0.12, 1.2), Vector3(0, 1.8, 3.1))
	for sx in [-1.0, 1.0]:
		k.box("conc2", Vector3(0.14, 1.7, 0.14), Vector3(0.95 * sx, 0.95, 3.55))
		_sandbags(k, Vector3(1.6 * sx, 0.12, 3.0), 0.0, 4)
	# harekât odası: çepeçevre cam
	_block(k, "conc", Vector3(4.4, 1.6, 3.8), Vector3(-0.8, 2.62, -1.2))
	k.box("glass", Vector3(4.46, 0.6, 3.86), Vector3(-0.8, 3.55, -1.2))
	for i in 5:
		k.box("conc", Vector3(0.12, 0.62, 3.9), Vector3(-2.8 + i * 1.0, 3.55, -1.2))
	k.box("team", Vector3(4.2, 0.03, 0.8), Vector3(-0.8, 4.34, -1.2))
	_mast(k, Vector3(-2.2, 4.3, -2.4), 3.2)
	_dish(k, Vector3(0.3, 4.3, -2.0), 0.8, 35.0)
	_dish(k, Vector3(2.6, 2.7, -2.8), 0.6, 40.0)
	_flag(k, Vector3(2.9, 2.7, 1.9), 3.4)
	_ac(k, Vector3(2.6, 2.7, 0.2))
	_ac(k, Vector3(2.6, 2.7, -1.0))
	# çatıda helikopter pisti işareti
	k.lathe("white", [Vector2(1.0, 0), Vector2(1.0, 0.012), Vector2(0.85, 0.012)], Vector3(0.6, 2.72, 1.2), Vector3.ZERO, 16)
	for sx in [-1.0, 1.0]:
		k.box("white", Vector3(0.14, 0.012, 0.9), Vector3(0.6 + 0.3 * sx, 2.725, 1.2))
	k.box("white", Vector3(0.6, 0.012, 0.14), Vector3(0.6, 2.725, 1.2))
	# yanda jeneratör ve yakıt tankı
	k.box("hull2", Vector3(1.4, 0.9, 0.9), Vector3(-3.9, 0.57, 3.4))
	Tanks._grille(k, Vector3(-3.9, 1.04, 3.4), 1.1, 0.6, 0.0, 4)
	Tanks._cyl(k, "sheet", 0.4, 1.4, Vector3(3.9, 0.55, 3.6), Vector3(0, 0, 90), 10)
	_crates(k, Vector3(-3.6, 0.12, -4.0))


## Santral: türbin binası, iki soğutma kulesi, şeritli baca, trafo sahası.
static func _santral(k: Kit) -> void:
	_slab(k, "conc2", 5.6, 6.2, Vector3(0, 0.1, 0.2))
	_block(k, "conc", Vector3(4.4, 1.7, 2.4), Vector3(0, 0.08, -1.4))
	k.push(Vector3(0, 0, -1.4), Vector3(0, 90, 0))
	_gable(k, "roof", 2.5, 4.5, 0.55, Vector3(0, 1.84, 0))
	k.pop()
	k.box("teamroof", Vector3(4.54, 0.06, 0.7), Vector3(0, 2.4, -1.4))
	_win_z(k, -1.9, 1.9, 1.15, -0.19, 5, 0.4)
	_door(k, Vector3(-1.6, 0.1, -0.19), 0.6, 1.0, false)
	for sx in [-1.0, 1.0]:
		# hiperbolik soğutma kulesi
		k.lathe("conc", [Vector2(1.1, 0.0), Vector2(0.86, 0.9), Vector2(0.72, 1.9), Vector2(0.78, 2.9), Vector2(0.7, 2.9), Vector2(0.66, 2.2)],
			Vector3(1.25 * sx, 0.1, 1.5), Vector3.ZERO, 16)
		k.lathe("dark", [Vector2(0, 0), Vector2(0.68, 0), Vector2(0, 0.01)], Vector3(1.25 * sx, 2.3, 1.5), Vector3.ZERO, 12)
		k.lathe("team", [Vector2(0.75, 0), Vector2(0.735, 0.22)], Vector3(1.25 * sx, 1.7, 1.5), Vector3.ZERO, 16)
	_stack(k, Vector3(-1.8, 0.1, -2.3), 0.22, 4.2)
	# trafolar ve yalıtkanlar
	for i in 2:
		var p := Vector3(1.0 + i * 1.0, 0.1, -0.1)
		k.box("hull2", Vector3(0.6, 0.6, 0.5), p + Vector3(0, 0.3, 0.3))
		for sx in [-1.0, 1.0]:
			k.lathe("white", [Vector2(0.05, 0), Vector2(0.07, 0.1), Vector2(0.04, 0.2), Vector2(0.07, 0.3), Vector2(0, 0.4)], p + Vector3(0.15 * sx, 0.6, 0.3), Vector3.ZERO, 6)
	Tanks._cyl(k, "steel", 0.12, 2.4, Vector3(0, 0.9, 0.3), Vector3(0, 0, 90), 8)


## Maden ocağı: kuyu kulesi ve makarası, eğik bant, cevher yığını, sac işletme binası.
static func _maden(k: Kit) -> void:
	_slab(k, "conc2", 6.2, 6.2, Vector3(0, 0.08, 0))
	_block(k, "sheet", Vector3(3.0, 1.6, 2.4), Vector3(-1.3, 0.06, -1.3))
	_gable(k, "roof", 3.2, 2.5, 0.6, Vector3(-1.3, 1.7, -1.3))
	k.box("teamroof", Vector3(0.6, 0.05, 2.56), Vector3(-1.3, 2.3, -1.3))
	_door(k, Vector3(-1.3, 0.08, -0.09), 1.3, 1.2, true)
	_win_x(k, -2.3, -0.3, 1.1, -2.81, 3, 0.35)
	# kuyu kulesi: dört eğik ayak, çaprazlar, tepede makara
	var c := Vector3(-1.9, 0.08, 1.7)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("steel", Vector3(0.1, 3.9, 0.1), c + Vector3(0.42 * sx, 1.9, 0.42 * sz), Vector3(-6.0 * sz, 0, 6.0 * sx))
		for i in 3:
			k.box("steel", Vector3(0.05, 1.3, 0.05), c + Vector3(0.55 * sx - 0.1 * sx * i, 0.8 + i * 1.1, 0), Vector3(40 * (1 if i % 2 == 0 else -1), 0, 0))
	for i in 3:
		k.box("steel", Vector3(1.3 - i * 0.24, 0.06, 1.3 - i * 0.24), c + Vector3(0, 0.9 + i * 1.1, 0))
	k.box("hull2", Vector3(0.8, 0.5, 0.8), c + Vector3(0, 3.95, 0))
	k.lathe("yellow", [Vector2(0.2, -0.05), Vector2(0.55, -0.05), Vector2(0.55, 0.05), Vector2(0.2, 0.05)], c + Vector3(0, 4.35, 0), Vector3(0, 0, 90), 12)
	k.box("team", Vector3(0.82, 0.14, 0.82), c + Vector3(0, 3.8, 0))
	# eğik taşıma bandı ve cevher yığını
	k.box("steel", Vector3(0.5, 0.12, 3.9), Vector3(1.5, 1.35, -0.4), Vector3(32, 0, 0))
	k.box("rubber", Vector3(0.4, 0.04, 3.9), Vector3(1.5, 1.44, -0.4), Vector3(32, 0, 0))
	for z in [-1.6, -0.3]:
		k.box("steel", Vector3(0.08, 2.2 + z * 0.6, 0.08), Vector3(1.5, (2.2 + z * 0.6) * 0.5, z))
	k.lathe("ore", [Vector2(1.5, 0), Vector2(1.0, 0.55), Vector2(0.45, 1.0), Vector2(0, 1.15)], Vector3(1.5, 0.08, 1.7), Vector3.ZERO, 9)
	k.lathe("ore", [Vector2(0.8, 0), Vector2(0.4, 0.45), Vector2(0, 0.6)], Vector3(0.1, 0.08, 2.3), Vector3.ZERO, 7)
	_stack(k, Vector3(-2.5, 0.08, -2.4), 0.16, 3.2)


## Kışla: uzun koğuş, beşik çatı, pencere sırası, kapıda kum torbası ve bayrak, yanda çadır.
static func _kisla(k: Kit) -> void:
	_slab(k, "conc2", 6.6, 5.6, Vector3(0, 0.08, 0.3))
	k.push(Vector3(0, 0, -0.4), Vector3(0, 90, 0))
	_block(k, "conc", Vector3(3.2, 1.5, 5.4), Vector3(0, 0.06, 0))
	_gable(k, "roof", 3.5, 5.6, 0.85, Vector3(0, 1.58, 0))
	for sx in [-1.0, 1.0]:
		k.box("teamroof", Vector3(1.86, 0.04, 0.8), Vector3(0.86 * sx, 2.03, 0), Vector3(0, 0, -25.9 * sx))
	_win_x(k, -2.4, -0.6, 1.0, -1.61, 3, 0.4)
	_win_x(k, 0.6, 2.4, 1.0, -1.61, 3, 0.4)
	_win_x(k, -2.4, 2.4, 1.0, 1.61, 6, 0.4)
	k.pop()
	_door(k, Vector3(0, 0.08, 1.22), 0.8, 1.15, false)
	_sandbags(k, Vector3(-1.2, 0.08, 1.6), 0.0, 3)
	_sandbags(k, Vector3(1.2, 0.08, 1.6), 0.0, 3)
	_flag(k, Vector3(2.7, 0.08, 2.3), 3.0)
	# çadır ve sandıklar
	_gable(k, "canvas2", 1.5, 1.8, 0.9, Vector3(-2.2, 0.08, 2.3))
	_crates(k, Vector3(0.4, 0.08, 2.5))
	_ac(k, Vector3(2.9, 0.08, -1.6))


## Fabrika: testere dişli çatılı atölye, büyük araç kapısı, bacalar, vinç köprüsü, sandıklar.
static func _fabrika(k: Kit) -> void:
	_slab(k, "conc2", 7.2, 7.2, Vector3(0, 0.08, 0))
	_block(k, "sheet", Vector3(5.8, 2.2, 5.2), Vector3(0, 0.06, -0.5))
	k.box("team", Vector3(5.84, 0.26, 5.24), Vector3(0, 1.95, -0.5))
	for i in 3:
		var z := -2.2 + i * 1.72
		k.loft("roof", [
			[Vector3(-2.9, 2.3, z - 0.86), Vector3(-2.9, 2.3, z + 0.86), Vector3(-2.9, 3.1, z - 0.86)],
			[Vector3(2.9, 2.3, z - 0.86), Vector3(2.9, 2.3, z + 0.86), Vector3(2.9, 3.1, z - 0.86)],
		])
		k.box("glass", Vector3(5.4, 0.5, 0.03), Vector3(0, 2.72, z - 0.875))
	_door(k, Vector3(-0.9, 0.08, 2.11), 2.4, 1.7, true)
	_door(k, Vector3(2.0, 0.08, 2.11), 0.7, 1.2, false)
	_win_x(k, -2.6, 1.6, 1.4, 2.91, 5, 0.45)
	_win_x(k, -2.6, 1.6, 1.4, -2.91, 5, 0.45)
	_stack(k, Vector3(2.3, 2.3, -2.6), 0.2, 2.6)
	_stack(k, Vector3(1.6, 2.3, -2.6), 0.16, 2.0)
	# önde köprülü vinç ve yeni çıkmış gövde
	for sx in [-1.0, 1.0]:
		k.box("yellow", Vector3(0.14, 2.2, 0.14), Vector3(-0.9 + 1.5 * sx, 1.18, 3.2))
	k.box("yellow", Vector3(3.3, 0.18, 0.2), Vector3(-0.9, 2.3, 3.2))
	k.box("dark", Vector3(0.03, 0.9, 0.03), Vector3(-0.9, 1.8, 3.2))
	k.box("hull", Vector3(1.1, 0.4, 1.7), Vector3(-0.9, 0.5, 3.1))
	k.box("rubber", Vector3(1.3, 0.3, 1.9), Vector3(-0.9, 0.23, 3.1))
	_crates(k, Vector3(2.0, 0.08, 2.9))
	_tank(k, "sheet", Vector3(-3.1, 0.08, 2.9), 0.4, 1.2)
	_ac(k, Vector3(-2.2, 2.3, 1.5))


## Hava alanı: işaretli pist, iki kemerli hangar, camlı kule, yakıt tankları, rüzgâr tulumu.
static func _havaalani(k: Kit) -> void:
	_slab(k, "asphalt", 3.4, 12.0, Vector3(2.6, 0.06, 0))
	_slab(k, "conc2", 6.4, 9.0, Vector3(-2.2, 0.05, 0))
	for i in 6:
		k.box("white", Vector3(0.16, 0.012, 1.0), Vector3(2.6, 0.068, -4.6 + i * 1.84))
	for sz in [-1.0, 1.0]:
		for i in 4:
			k.box("white", Vector3(0.18, 0.012, 0.7), Vector3(1.55 + i * 0.7, 0.068, 5.4 * sz))
		k.box("white", Vector3(0.05, 0.012, 11.6), Vector3(2.6 + 1.5 * sz, 0.068, 0))
		# kemerli hangar: ağzı piste bakar
		var z: float = 2.6 * sz
		var a: Array = []
		var b: Array = []
		for i in 9:
			var an := PI * i / 8.0
			a.append(Vector3(-4.3, 0.05 + sin(an) * 1.7, z + cos(an) * 1.75))
			b.append(Vector3(-0.9, 0.05 + sin(an) * 1.7, z + cos(an) * 1.75))
		k.loft("roof", [a, b], true)
		k.box("dark", Vector3(0.04, 1.25, 2.6), Vector3(-0.88, 0.68, z))
		k.box("yellow", Vector3(0.05, 0.1, 2.7), Vector3(-0.87, 1.35, z))
		k.box("teamroof", Vector3(0.7, 0.05, 1.0), Vector3(-2.6, 1.74, z))
		Tanks._cyl(k, "red", 0.05, 0.08, Vector3(1.0, 0.1, 5.7 * sz), Vector3.ZERO, 6)
	# kontrol kulesi
	k.loft("conc", [Tanks._plan(0.05, [Vector2(0.5, 0.5), Vector2(0.5, -0.5)]), Tanks._plan(3.5, [Vector2(0.4, 0.4), Vector2(0.4, -0.4)])])
	k.loft("glass", [Tanks._plan(3.5, [Vector2(0.35, 0.7), Vector2(0.7, 0.35), Vector2(0.7, -0.35), Vector2(0.35, -0.7)]),
		Tanks._plan(4.2, [Vector2(0.45, 0.85), Vector2(0.85, 0.45), Vector2(0.85, -0.45), Vector2(0.45, -0.85)])])
	k.box("conc2", Vector3(1.8, 0.12, 1.8), Vector3(0, 4.26, 0))
	k.box("team", Vector3(1.5, 0.03, 1.5), Vector3(0, 4.34, 0))
	_mast(k, Vector3(0.4, 4.3, -0.4), 1.6)
	Vehicles._radar(k, Vector3(-0.3, 4.9, 0.3), 0.9, 0.35, -10.0)
	# yakıt tankları ve rüzgâr tulumu
	for i in 2:
		Tanks._cyl(k, "sheet", 0.42, 1.6, Vector3(-4.6 + i * 1.0, 0.5, -0.0), Vector3(90, 0, 0), 10)
	k.lathe("steel", [Vector2(0.03, 0), Vector2(0.02, 1.8)], Vector3(0.6, 0.06, 4.6), Vector3.ZERO, 5)
	k.lathe("red", [Vector2(0.14, 0), Vector2(0.06, 0.6)], Vector3(0.6, 1.8, 4.6), Vector3(80, 30, 0), 6)


## Teknoloji merkezi: cam cepheli laboratuvar, radom küresi, çanak, soğutma üniteleri.
static func _teknoloji(k: Kit) -> void:
	_slab(k, "conc2", 6.4, 5.6, Vector3(0, 0.08, 0))
	_block(k, "white", Vector3(5.0, 1.9, 3.6), Vector3(0, 0.06, -0.4))
	k.box("glass", Vector3(3.2, 1.2, 0.06), Vector3(0.7, 1.1, 1.41))
	for i in 5:
		k.box("white", Vector3(0.06, 1.24, 0.08), Vector3(-0.9 + i * 0.8, 1.1, 1.42))
	k.box("team", Vector3(5.04, 0.2, 3.64), Vector3(0, 1.75, -0.4))
	_door(k, Vector3(-1.8, 0.08, 1.41), 0.7, 1.15, false)
	_win_x(k, -1.9, 1.1, 1.2, 2.51, 4, 0.5)
	_win_x(k, -1.9, 1.1, 1.2, -2.51, 4, 0.5)
	# ikinci kat ve radom
	_block(k, "white", Vector3(2.2, 1.0, 2.2), Vector3(1.2, 1.98, -0.8))
	_win_z(k, 0.3, 2.1, 2.5, 0.31, 3, 0.4)
	var prof: Array = []
	for i in 9:
		var a := -0.6 + (PI * 0.5 + 0.6) * i / 8.0
		prof.append(Vector2(cos(a) * 1.15, sin(a) * 1.15))
	k.lathe("white", prof, Vector3(-1.2, 2.7, -0.7), Vector3.ZERO, 14)
	k.lathe("conc2", [Vector2(1.0, 0), Vector2(0.95, 0.15)], Vector3(-1.2, 1.98, -0.7), Vector3.ZERO, 12)
	_dish(k, Vector3(1.2, 3.0, -0.8), 0.7, 40.0)
	_mast(k, Vector3(2.0, 3.0, -1.6), 2.2)
	for i in 3:
		_ac(k, Vector3(-2.0 + i * 0.85, 1.98, 0.9))
	Tanks._cyl(k, "sheet", 0.3, 1.3, Vector3(-2.8, 0.75, 2.0), Vector3.ZERO, 10)
	Tanks._cyl(k, "sheet", 0.3, 1.3, Vector3(-2.1, 0.75, 2.1), Vector3.ZERO, 10)


## Füze üssü: beton rampa, dikilmiş balistik füze ve servis kulesi, sığınak, alev siperleri.
static func _fuze(k: Kit) -> void:
	_slab(k, "conc2", 6.2, 6.2, Vector3(0, 0.14, 0))
	k.box("yellow", Vector3(5.6, 0.012, 0.14), Vector3(0, 0.15, 2.8))
	k.box("yellow", Vector3(5.6, 0.012, 0.14), Vector3(0, 0.15, -2.8))
	# fırlatma masası ve füze
	var c := Vector3(1.1, 0.14, 0.2)
	k.lathe("conc", [Vector2(1.2, 0), Vector2(1.1, 0.3), Vector2(0.5, 0.3)], c, Vector3.ZERO, 12)
	k.lathe("dark", [Vector2(0, 0), Vector2(0.5, 0), Vector2(0, 0.01)], c + Vector3(0, 0.22, 0), Vector3.ZERO, 10)
	for i in 4:
		k.push(c, Vector3(0, 45.0 + i * 90.0, 0))
		k.box("steel", Vector3(0.1, 0.7, 0.1), Vector3(0.42, 0.6, 0), Vector3(0, 0, 14))
		k.pop()
	k.lathe("white", [Vector2(0.2, 0.0), Vector2(0.36, 0.15), Vector2(0.36, 1.6)], c + Vector3(0, 0.8, 0), Vector3.ZERO, 12)
	k.lathe("team", [Vector2(0.362, 1.6), Vector2(0.362, 1.9)], c + Vector3(0, 0.8, 0), Vector3.ZERO, 12)
	k.lathe("white", [Vector2(0.36, 1.9), Vector2(0.36, 3.4), Vector2(0.3, 3.45), Vector2(0.3, 3.7)], c + Vector3(0, 0.8, 0), Vector3.ZERO, 12)
	k.lathe("dark", [Vector2(0.3, 3.7), Vector2(0.24, 4.3), Vector2(0.1, 4.75), Vector2(0, 4.85)], c + Vector3(0, 0.8, 0), Vector3.ZERO, 12)
	for i in 4:
		k.push(c + Vector3(0, 1.0, 0), Vector3(0, i * 90.0, 0))
		k.loft("dark", [[Vector3(0.36, 0, -0.02), Vector3(0.75, 0, -0.02), Vector3(0.36, 0.7, -0.02)], [Vector3(0.36, 0, 0.02), Vector3(0.75, 0, 0.02), Vector3(0.36, 0.7, 0.02)]])
		k.pop()
	# servis kulesi (kafes) ve bağlantı kolları
	var g := Vector3(2.3, 0.14, 0.2)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("red", Vector3(0.08, 5.0, 0.08), g + Vector3(0.28 * sx, 2.5, 0.28 * sz))
	for i in 7:
		k.box("steel", Vector3(0.64, 0.05, 0.64), g + Vector3(0, 0.6 + i * 0.7, 0))
		k.box("steel", Vector3(0.05, 0.9, 0.05), g + Vector3(0.28, 0.25 + i * 0.7, 0), Vector3(38 * (1 if i % 2 == 0 else -1), 0, 0))
	for y in [2.2, 3.9]:
		k.box("steel", Vector3(0.9, 0.08, 0.12), Vector3(1.75, y, 0.2))
	# komuta sığınağı ve alev siperleri
	k.push(Vector3(-1.8, 0, -0.3), Vector3.ZERO)
	k.loft("conc", [Tanks._plan(0.14, [Vector2(1.0, 1.7), Vector2(1.0, -1.7)]), Tanks._plan(1.05, [Vector2(0.8, 1.5), Vector2(0.8, -1.5)])])
	k.box("dark", Vector3(0.05, 0.16, 1.6), Vector3(0.92, 0.75, 0))
	k.box("team", Vector3(1.2, 0.03, 2.4), Vector3(0, 1.07, 0))
	_door(k, Vector3(0, 0.14, 1.62), 0.6, 0.75, false)
	k.pop()
	_mast(k, Vector3(-2.4, 1.05, -1.5), 2.4)
	k.box("conc", Vector3(0.25, 1.3, 2.6), Vector3(-0.35, 0.79, 0.2), Vector3(0, 0, -8))
	k.box("conc", Vector3(2.4, 1.1, 0.25), Vector3(1.2, 0.69, -2.0), Vector3(8, 0, 0))
	Tanks._cyl(k, "sheet", 0.35, 1.6, Vector3(1.6, 0.52, 2.3), Vector3(0, 0, 90), 10)
	Tanks._cyl(k, "white", 0.3, 1.2, Vector3(-0.2, 0.47, 2.4), Vector3(0, 0, 90), 10)


# ---------------------------------------------------------------- hava savunma bataryaları

## Patriot / David's Sling: destek ayaklı römorkta eğik dört kutulu atıcı, yanında düz yüzlü radar ve jeneratör.
static func _sam_box(k: Kit) -> void:
	_slab(k, "conc2", 4.6, 4.6, Vector3(0, 0.06, 0))
	k.box("hull2", Vector3(1.5, 0.25, 3.2), Vector3(0.5, 0.75, -0.2))
	for sx in [-1.0, 1.0]:
		for z in [-1.3, -0.7]:
			Vehicles._wheel(k, Vector3(0.5 + 0.8 * sx, 0.4, z), 0.34, 0.24, sx)
		for z in [0.9, -1.75]:
			k.box("steel", Vector3(0.7, 0.08, 0.1), Vector3(0.5 + 1.05 * sx, 0.7, z))
			k.box("steel", Vector3(0.1, 0.7, 0.1), Vector3(0.5 + 1.4 * sx, 0.4, z))
			k.box("steel", Vector3(0.3, 0.04, 0.3), Vector3(0.5 + 1.4 * sx, 0.08, z))
	Tanks._cyl(k, "hull2", 0.6, 0.2, Vector3(0.5, 0.97, -0.5), Vector3.ZERO, 10)
	k.push(Vector3(0.5, 1.1, -1.3), Vector3(-38, 0, 0))
	k.box("steel", Vector3(1.5, 0.1, 2.6), Vector3(0, 0, 1.3))
	for i in 2:
		for j in 2:
			var p := Vector3(-0.38 + i * 0.76, 0.42 + j * 0.72, 1.4)
			k.box("hull", Vector3(0.7, 0.66, 2.9), p)
			k.box("hull2", Vector3(0.74, 0.7, 0.08), p + Vector3(0, 0, 0.9))
			k.box("hull2", Vector3(0.74, 0.7, 0.08), p + Vector3(0, 0, -0.9))
			k.box("dark", Vector3(0.56, 0.52, 0.02), p + Vector3(0, 0, 1.455))
	k.box("team", Vector3(1.5, 0.03, 1.6), Vector3(0, 1.5, 1.4))
	k.pop()
	# radar ve jeneratör
	k.box("hull2", Vector3(1.0, 0.7, 1.4), Vector3(-1.5, 0.45, -1.2))
	k.push(Vector3(-1.5, 1.7, -1.0), Vector3(-20, 20, 0))
	k.box("hull", Vector3(1.3, 1.5, 0.2), Vector3.ZERO)
	k.box("steel", Vector3(1.1, 1.2, 0.03), Vector3(0, 0.05, 0.11))
	k.pop()
	k.box("hull2", Vector3(0.9, 0.7, 0.7), Vector3(-1.5, 0.43, 1.3))
	Tanks._grille(k, Vector3(-1.5, 0.8, 1.3), 0.7, 0.5, 0.0, 4)
	_sandbags(k, Vector3(-2.2, 0.06, 0.2), 0.0, 3)
	Tanks._antenna(k, Vector3(-1.9, 0.8, -1.7), 1.6)


## S-400 / HQ-9 / Bavar-373: 8x8 taşıyıcıda arkada dikilmiş dört füze tüpü, yanında radar direği.
static func _sam_tube(k: Kit) -> void:
	_slab(k, "conc2", 4.6, 6.2, Vector3(0, 0.06, 0))
	k.push(Vector3(0.5, 0.06, 0.2), Vector3.ZERO, 0.52)
	Vehicles._truck(k, 9.6, [-3.9, -2.5, 1.6, 3.4], false)
	k.box("hull", Vector3(2.5, 0.9, 2.2), Vector3(0, 1.75, 1.4))
	for sx in [-1.0, 1.0]:
		k.box("steel", Vector3(0.3, 1.2, 0.3), Vector3(1.4 * sx, 0.6, -4.4))
		k.box("steel", Vector3(0.6, 0.06, 0.6), Vector3(1.4 * sx, 0.04, -4.4))
		k.box("hull2", Vector3(0.25, 1.6, 1.4), Vector3(1.1 * sx, 2.0, -3.4))
		for z in [-3.9, -2.8]:
			var p := Vector3(0.62 * sx, 1.3, z)
			k.lathe("hull", [Vector2(0.5, 0), Vector2(0.5, 6.4), Vector2(0.44, 6.5), Vector2(0, 6.55)], p, Vector3.ZERO, 12)
			for y in [1.0, 3.2, 5.4]:
				k.lathe("hull2", [Vector2(0.53, y), Vector2(0.53, y + 0.18)], p, Vector3.ZERO, 12)
			k.lathe("team", [Vector2(0.52, 5.75), Vector2(0.52, 6.2)], p, Vector3.ZERO, 12)
	k.pop()
	# radar direği
	k.box("hull2", Vector3(1.0, 0.7, 1.2), Vector3(-1.5, 0.41, -1.6))
	k.lathe("steel", [Vector2(0.12, 0), Vector2(0.08, 2.6)], Vector3(-1.5, 0.75, -1.6), Vector3.ZERO, 8)
	k.push(Vector3(-1.5, 3.5, -1.5), Vector3(-12, 15, 0))
	k.box("hull", Vector3(1.5, 1.1, 0.16), Vector3.ZERO)
	k.box("steel", Vector3(1.3, 0.9, 0.03), Vector3(0, 0, 0.09))
	k.pop()
	_sandbags(k, Vector3(-2.2, 0.06, 0.6), 0.0, 3)


# ---------------------------------------------------------------- vinç ve ikmal noktaları

## İnşaat kule vinci: kafes kule, bom, karşı ağırlık, kanca.
static func _crane(k: Kit) -> void:
	k.box("conc2", Vector3(1.2, 0.3, 1.2), Vector3(0, 0.15, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("yellow", Vector3(0.07, 5.8, 0.07), Vector3(0.2 * sx, 3.2, 0.2 * sz))
	for i in 9:
		k.box("yellow", Vector3(0.46, 0.04, 0.46), Vector3(0, 0.7 + i * 0.62, 0))
		k.box("yellow", Vector3(0.04, 0.72, 0.04), Vector3(0.2, 0.4 + i * 0.62, 0), Vector3(36 * (1 if i % 2 == 0 else -1), 0, 0))
	k.box("hull2", Vector3(0.6, 0.5, 0.6), Vector3(0, 6.2, 0))
	k.box("glass", Vector3(0.5, 0.3, 0.03), Vector3(-0.05, 6.25, 0.31))
	k.box("yellow", Vector3(4.6, 0.1, 0.1), Vector3(-2.5, 6.5, 0.14))
	k.box("yellow", Vector3(4.6, 0.1, 0.1), Vector3(-2.5, 6.5, -0.14))
	k.box("yellow", Vector3(4.4, 0.06, 0.06), Vector3(-2.4, 6.85, 0), Vector3(0, 0, -4))
	for i in 7:
		k.box("yellow", Vector3(0.04, 0.4, 0.3), Vector3(-0.6 - i * 0.6, 6.68 - i * 0.025, 0), Vector3(0, 0, 30))
	k.box("yellow", Vector3(1.8, 0.12, 0.3), Vector3(1.1, 6.5, 0))
	k.box("conc", Vector3(0.7, 0.5, 0.5), Vector3(1.6, 6.25, 0))
	k.box("yellow", Vector3(0.07, 0.9, 0.07), Vector3(0, 6.9, 0))
	k.box("dark", Vector3(0.03, 2.3, 0.03), Vector3(-3.6, 5.3, 0))
	k.box("steel", Vector3(0.9, 0.5, 0.9), Vector3(-3.6, 3.95, 0))


## İkmal noktası: petrol kulesi ve tanklar ya da sandık / varil yığını. Çevresinde kum torbaları, bir direk.
static func _supply(k: Kit, oil: bool) -> void:
	k.lathe("conc2", [Vector2(3.0, 0.0), Vector2(2.9, 0.08), Vector2(0, 0.08)], Vector3.ZERO, Vector3.ZERO, 16)
	if oil:
		var c := Vector3(0, 0.08, -0.6)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				k.box("steel", Vector3(0.1, 4.5, 0.1), c + Vector3(0.38 * sx, 2.2, 0.38 * sz), Vector3(-9.0 * sz, 0, 9.0 * sx))
		for i in 4:
			var w := 1.35 - i * 0.33
			k.box("steel", Vector3(w, 0.05, w), c + Vector3(0, 0.6 + i * 1.05, 0))
			k.box("steel", Vector3(0.05, 1.2, 0.05), c + Vector3(w * 0.5, 1.1 + i * 1.05, 0), Vector3(35 * (1 if i % 2 == 0 else -1), 0, 0))
		k.box("hull2", Vector3(0.6, 0.3, 0.6), c + Vector3(0, 4.45, 0))
		k.lathe("dark", [Vector2(0.07, 0), Vector2(0.07, 4.0)], c + Vector3(0, 0.2, 0), Vector3.ZERO, 6)
		# pompa ve tanklar
		k.box("yellow", Vector3(0.12, 0.12, 1.5), Vector3(0.9, 1.3, -0.5), Vector3(12, 0, 0))
		k.box("steel", Vector3(0.14, 1.2, 0.14), Vector3(0.9, 0.65, -0.6))
		for sx in [-1.0, 1.0]:
			_tank(k, "sheet", Vector3(1.5 * sx, 0.08, 1.0), 0.8, 1.3)
			k.lathe("red", [Vector2(0.815, 0.9), Vector2(0.815, 1.1)], Vector3(1.5 * sx, 0.08, 1.0), Vector3.ZERO, 14)
		Tanks._cyl(k, "steel", 0.07, 2.4, Vector3(0, 0.4, 1.0), Vector3(0, 0, 90), 6)
	else:
		_crates(k, Vector3(-1.2, 0.08, -0.7))
		_crates(k, Vector3(0.5, 0.08, -1.2))
		k.box("canvas2", Vector3(1.6, 0.7, 1.0), Vector3(0.9, 0.43, 0.7), Vector3(0, 12, 0))
		k.box("canvas", Vector3(1.7, 0.06, 1.1), Vector3(0.9, 0.8, 0.7), Vector3(0, 12, 0))
		for i in 4:
			Tanks._cyl(k, "hull2" if i % 2 == 0 else "red", 0.22, 0.6, Vector3(-1.4 + (i % 2) * 0.5, 0.38, 1.0 + floorf(i * 0.5) * 0.5), Vector3.ZERO, 8)
		_sandbags(k, Vector3(-2.3, 0.08, -0.4), 0.0, 4)
	k.lathe("steel", [Vector2(0.05, 0), Vector2(0.03, 4.0)], Vector3(-1.9, 0.08, 1.6), Vector3.ZERO, 6)
	k.lathe("white", [Vector2(0.12, 0), Vector2(0.12, 0.25), Vector2(0, 0.3)], Vector3(-1.9, 4.0, 1.6), Vector3.ZERO, 6)


## Tanksavar engeli: beton "ejderha dişleri" ve aralarına gerilmiş tel.
static func _obstacle(k: Kit) -> void:
	for i in 3:
		for j in 2:
			var p := Vector3(-1.4 + i * 1.4 + j * 0.7, 0, -0.5 + j * 1.0)
			k.lathe("conc", [Vector2(0.55, 0), Vector2(0.5, 0.15), Vector2(0.12, 1.1), Vector2(0, 1.15)], p, Vector3(0, i * 30.0, 0), 4)
	for sz in [-1.0, 1.0]:
		k.box("dark", Vector3(4.2, 0.03, 0.03), Vector3(0, 0.6, 1.0 * sz))
		k.box("dark", Vector3(4.2, 0.03, 0.03), Vector3(0, 0.3, 1.0 * sz))
	for x in [-2.0, 2.0]:
		k.box("wood", Vector3(0.08, 0.8, 0.08), Vector3(x, 0.4, 0))


## Köy evi: tuğla duvarlar, kırma çatı, pencereler; piyade içine girebilir. Bir köşesi hasarlı.
static func _house(k: Kit) -> void:
	_block(k, "conc", Vector3(3.6, 2.2, 3.2), Vector3(0, 1.1, 0))
	k.box("conc2", Vector3(3.7, 0.2, 3.3), Vector3(0, 0.1, 0))
	_gable(k, "roof", 4.0, 3.6, 1.2, Vector3(0, 2.2, 0))
	_win_z(k, -1.2, 1.2, 1.3, 1.62, 2, 0.6)
	_win_z(k, -1.2, 1.2, 1.3, -1.62, 2, 0.6)
	_win_x(k, -0.9, 0.9, 1.3, 1.82, 2, 0.6)
	_door(k, Vector3(-1.82, 0, 0.6), 0.8, 1.5, false)
	# hasar: çatıda delik ve moloz
	k.box("dark", Vector3(0.9, 0.05, 0.8), Vector3(0.9, 2.75, -0.7), Vector3(0, 0, 18))
	for i in 4:
		k.box("conc2", Vector3(0.4, 0.25, 0.35), Vector3(1.9 + i * 0.25, 0.12, -1.5 + i * 0.3), Vector3(0, i * 25.0, 0))
	_sandbags(k, Vector3(-2.3, 0, -1.2), 0.0, 4)


## Siper: piyadenin çevresinde kum torbası halkası.
static func _trench(k: Kit) -> void:
	for i in 6:
		var a := TAU * i / 6.0
		k.push(Vector3(cos(a) * 1.5, 0, sin(a) * 1.5), Vector3(0, -rad_to_deg(a), 0))
		for j in 2:
			Tanks._bag(k, "sand", Vector3(0.3, 0.2, 0.55), Vector3(0, 0.1 + j * 0.19, j * 0.25 - 0.25), 0.0)
		Tanks._bag(k, "sand", Vector3(0.3, 0.2, 0.55), Vector3(0, 0.1, 0.35), 0.0)
		k.pop()


## Tanksavar mayını: yere yarı gömülü disk (yalnızca sahibi görür).
static func _mine(k: Kit) -> void:
	k.lathe("hull2", [Vector2(0, 0), Vector2(0.45, 0), Vector2(0.45, 0.1), Vector2(0.2, 0.16), Vector2(0, 0.17)], Vector3.ZERO, Vector3.ZERO, 10)
	k.lathe("team", [Vector2(0, 0.17), Vector2(0.12, 0.17), Vector2(0.12, 0.2), Vector2(0, 0.2)], Vector3.ZERO, Vector3.ZERO, 8)


## Yıkık apartman: dört katlı panel blok, balkonlar, bir köşesi çökmüş; dibinde moloz.
static func _apartment(k: Kit) -> void:
	_block(k, "conc", Vector3(5.4, 5.2, 3.6), Vector3(0, 0, 0))
	for f in 4:
		var y := 0.75 + f * 1.25
		_win_z(k, -2.4, 2.4, y, 1.82, 5, 0.55)
		_win_z(k, -2.4, 2.4, y, -1.82, 5, 0.55)
		_win_x(k, -1.3, 1.3, y, 2.72, 2, 0.55)
		_win_x(k, -1.3, 1.3, y, -2.72, 2, 0.55)
		if f > 0:
			for i in 3:
				k.box("conc2", Vector3(1.0, 0.08, 0.5), Vector3(-1.6 + i * 1.6, y - 0.4, 2.05))
				k.box("conc2", Vector3(1.0, 0.4, 0.05), Vector3(-1.6 + i * 1.6, y - 0.2, 2.3))
	k.box("conc2", Vector3(0.12, 5.2, 3.7), Vector3(0, 2.6, 0))
	# çökmüş köşe: kararmış boşluklar ve sarkan döşeme
	k.box("dark", Vector3(1.7, 2.3, 0.1), Vector3(1.75, 4.1, 1.84))
	k.box("dark", Vector3(0.1, 2.3, 1.6), Vector3(2.74, 4.1, 1.0))
	k.box("conc2", Vector3(1.6, 0.12, 1.4), Vector3(1.9, 3.1, 1.3), Vector3(0, 0, -16))
	for i in 7:
		k.box("conc2", Vector3(0.5 + (i % 3) * 0.2, 0.3, 0.45), Vector3(2.2 + (i % 4) * 0.35, 0.15 + (i / 4) * 0.25, 1.4 + (i % 3) * 0.5), Vector3(0, i * 37.0, i * 7.0))
	_door(k, Vector3(-1.6, 0, 1.82), 0.9, 1.3, false)
	_sandbags(k, Vector3(-2.6, 0, 2.3), 0.0, 3)


## Terk edilmiş fabrika: yarısı çökmüş çatı, çıplak çelik makaslar, delik duvarlar, devrik baca.
static func _ruin_factory(k: Kit) -> void:
	_slab(k, "conc2", 9.6, 7.6, Vector3(0, 0.08, 0))
	k.box("conc", Vector3(8.8, 3.0, 0.35), Vector3(0, 1.58, -3.4))
	k.box("conc", Vector3(3.4, 3.0, 0.35), Vector3(-2.7, 1.58, 3.4))
	k.box("conc", Vector3(2.6, 1.6, 0.35), Vector3(3.1, 0.88, 3.4))
	k.box("conc", Vector3(0.35, 3.0, 6.8), Vector3(-4.4, 1.58, 0))
	k.box("conc", Vector3(0.35, 2.2, 3.6), Vector3(4.4, 1.18, -1.6))
	_win_z(k, -4.0, -1.2, 2.0, 3.6, 3, 0.7)
	_win_z(k, -4.0, 4.0, 2.0, -3.6, 6, 0.7)
	# çatı: sol yarısı sağlam, sağda yalnız makaslar
	k.box("roof", Vector3(4.6, 0.12, 7.0), Vector3(-2.2, 3.15, 0))
	for i in 5:
		var z := -3.0 + i * 1.5
		k.box("steel", Vector3(8.6, 0.14, 0.14), Vector3(0, 3.1, z))
		k.box("steel", Vector3(0.1, 0.9, 0.1), Vector3(2.2, 3.5, z), Vector3(0, 0, 50))
	k.box("roof", Vector3(2.4, 0.1, 2.0), Vector3(2.4, 1.6, 1.4), Vector3(30, 20, 18))
	_stack(k, Vector3(3.4, 0.08, -2.6), 0.32, 6.5)
	k.box("conc", Vector3(0.6, 0.6, 3.0), Vector3(5.6, 0.35, 1.6), Vector3(0, 30, 90))
	for i in 9:
		k.box("conc2", Vector3(0.6, 0.35, 0.5), Vector3(1.0 + (i % 3) * 0.9, 0.2 + (i / 3) * 0.2, 1.0 + (i % 4) * 0.6), Vector3(0, i * 41.0, i * 9.0))
	_crates(k, Vector3(-3.0, 0.08, 1.0))


## Kaynak yatağı: toprağın üstüne çıkmış cevher kayaları, parlayan damarlar, sondaj kazıkları ve işaret direkleri.
static func _deposit(k: Kit) -> void:
	k.lathe("ore", [Vector2(3.2, 0.0), Vector2(2.9, 0.06), Vector2(0, 0.06)], Vector3.ZERO, Vector3.ZERO, 14)
	var rocks := [[Vector3(-0.9, 0, -0.6), 1.2, 1.3], [Vector3(0.9, 0, 0.3), 1.0, 1.0], [Vector3(-0.1, 0, 1.2), 0.8, 0.8], [Vector3(1.4, 0, -1.3), 0.7, 0.7]]
	for i in rocks.size():
		var r: Array = rocks[i]
		k.lathe("ore", [Vector2(r[1], 0), Vector2(r[1] * 0.8, r[2] * 0.6), Vector2(r[1] * 0.3, r[2]), Vector2(0, r[2] * 1.05)], r[0], Vector3(0, i * 40.0, 0), 6)
		for j in 3:
			k.box("yellow", Vector3(0.14, 0.5 + j * 0.15, 0.14), r[0] + Vector3(cos(j * 2.1) * r[1] * 0.55, r[2] * 0.45, sin(j * 2.1) * r[1] * 0.55), Vector3(25 - j * 20, j * 50, 15))
	for i in 4:
		var a := i * PI * 0.5 + 0.4
		var p := Vector3(cos(a) * 2.7, 0, sin(a) * 2.7)
		k.box("wood", Vector3(0.08, 1.1, 0.08), p + Vector3(0, 0.55, 0))
		k.box("red" if i % 2 == 0 else "white", Vector3(0.1, 0.25, 0.1), p + Vector3(0, 1.0, 0))
	# sondaj kulesi (küçük üçayak)
	for i in 3:
		k.box("steel", Vector3(0.07, 2.4, 0.07), Vector3(1.9, 1.1, 1.6) + Vector3(cos(i * 2.1) * 0.35, 0, sin(i * 2.1) * 0.35), Vector3(cos(i * 2.1) * 9.0, 0, -sin(i * 2.1) * 9.0))
	k.box("hull2", Vector3(0.3, 0.3, 0.3), Vector3(1.9, 2.3, 1.6))


## İleri harekât üssü: kum torbası çemberi, çadırlar, kamuflaj ağı, telsiz direği, mühimmat sandıkları ve bayrak.
static func _fob(k: Kit) -> void:
	k.lathe("sand", [Vector2(3.6, 0.0), Vector2(3.5, 0.05), Vector2(0, 0.05)], Vector3.ZERO, Vector3.ZERO, 16)
	for i in 8:
		var a := TAU * i / 8.0
		if i == 2:
			continue    # giriş
		_sandbags(k, Vector3(cos(a) * 3.3, 0, sin(a) * 3.3), -rad_to_deg(a), 3)
	_gable(k, "canvas2", 1.6, 2.4, 1.0, Vector3(-1.2, 0.05, -0.8))
	_gable(k, "canvas2", 1.4, 2.0, 0.9, Vector3(1.0, 0.05, -1.4))
	k.box("canvas", Vector3(2.6, 0.04, 1.9), Vector3(0.7, 1.35, 1.0), Vector3(4, 10, -3))
	for p in [Vector3(-0.5, 0, 0.2), Vector3(1.9, 0, 0.2), Vector3(-0.5, 0, 1.8), Vector3(1.9, 0, 1.8)]:
		k.box("wood", Vector3(0.07, 1.35, 0.07), p + Vector3(0, 0.68, 0))
	_crates(k, Vector3(0.2, 0.05, 0.9))
	_mast(k, Vector3(-2.0, 0.05, 1.2), 3.4)
	_flag(k, Vector3(2.3, 0.05, -2.2), 3.0)
	for i in 3:
		k.box("sand", Vector3(0.8, 0.9, 0.8), Vector3(-2.6 + i * 0.85, 0.5, -2.6))
	k.box("team", Vector3(1.2, 0.03, 0.8), Vector3(-1.2, 1.08, -0.8))



# ---------------------------------------------------------------- ulusal süslemeler

## Binanın üstüne ülkenin mimarisine özgü öğeleri ekler. Konumlar her binanın kendi tasarımına göredir.
static func _ornament(k: Kit, id: String) -> void:
	var st := _st
	match id:
		"hq":
			match st:
				"ua":
					_dome_pear(k, Vector3(-0.8, 4.36, -1.0), 0.9)
					_band(k, Vector3(0, 2.62, -0.6), 7.5, 6.5)
				"ru":
					_shatyor(k, Vector3(2.9, 2.72, -2.9), 0.65)
					_star(k, Vector3(-0.8, 2.95, 0.73), 0.34)
					_dome_onion(k, Vector3(-0.8, 4.36, -1.2), 0.55)
				"il":
					_arcade(k, Vector3(-2.2, 0.12, 2.66), 5, 0.72, 1.35)
					_solar(k, Vector3(2.4, 2.72, -2.6))
					_solar(k, Vector3(2.4, 2.72, -1.4))
					_band(k, Vector3(0, 2.62, -0.6), 7.5, 6.5)
				"ir":
					_dome_persian(k, Vector3(-0.8, 4.36, -1.2), 1.0)
					_iwan(k, Vector3(0, 0.12, 2.66), 1.7, 2.3)
					_badgir(k, Vector3(3.0, 2.72, -3.0), 1.6)
				"pk":
					_dome_mughal(k, Vector3(-0.8, 4.36, -1.2), 0.95)
					_chhatri(k, Vector3(3.1, 2.72, 1.9), 0.5)
					_chhatri(k, Vector3(-3.1, 2.72, 1.9), 0.5)
					_band(k, Vector3(0, 2.62, -0.6), 7.5, 6.5)
				"in":
					_chhatri(k, Vector3(-0.8, 4.36, -1.2), 0.8)
					_chhatri(k, Vector3(3.1, 2.72, 1.9), 0.5)
					_chhatri(k, Vector3(-3.1, 2.72, 1.9), 0.5)
					_jharokha(k, Vector3(-2.2, 1.5, 2.62))
					_jharokha(k, Vector3(2.2, 1.5, 2.62))
		"kisla":
			match st:
				"ua":
					_dome_pear(k, Vector3(0, 2.4, -0.4), 0.38)
				"ru":
					_star(k, Vector3(0, 1.48, 1.24), 0.2)
					_shatyor(k, Vector3(2.4, 1.64, -1.6), 0.35)
				"il":
					_solar(k, Vector3(1.4, 1.8, -0.6))
					_band(k, Vector3(0, 1.5, -0.4), 5.5, 3.3)
				"ir":
					_badgir(k, Vector3(-2.2, 1.64, -1.5), 1.4)
					_badgir(k, Vector3(2.2, 1.64, -1.5), 1.4)
				"pk", "in":
					_chhatri(k, Vector3(-2.2, 1.95, -0.4), 0.42)
					_chhatri(k, Vector3(2.2, 1.95, -0.4), 0.42)
		"santral":
			match st:
				"ru":
					_star(k, Vector3(0, 1.45, -0.17), 0.2)
				"ir":
					_badgir(k, Vector3(1.8, 1.8, -2.2), 1.3)
				"il":
					_solar(k, Vector3(0.9, 1.95, -1.4))
				"pk", "in":
					_band(k, Vector3(0, 1.6, -1.4), 4.5, 2.5)
		"fabrika":
			match st:
				"ru":
					_star(k, Vector3(1.1, 1.3, 2.14), 0.3)
				"ua":
					_band(k, Vector3(0, 2.06, -0.5), 5.9, 5.3)
				"ir":
					_badgir(k, Vector3(-2.5, 2.3, -2.7), 1.6)
				"il":
					_solar(k, Vector3(-2.0, 3.05, 1.2))
				"pk", "in":
					_chhatri(k, Vector3(2.4, 2.3, 1.7), 0.45)
		"teknoloji":
			match st:
				"ua":
					_dome_pear(k, Vector3(1.2, 2.98, -0.8), 0.5)
				"ru":
					_star(k, Vector3(0.7, 1.9, 1.44), 0.25)
				"il":
					_solar(k, Vector3(-1.6, 2.0, 1.0))
					_solar(k, Vector3(-0.4, 2.0, 1.0))
				"ir":
					_dome_persian(k, Vector3(1.2, 2.98, -0.8), 0.6)
				"pk":
					_dome_mughal(k, Vector3(1.2, 2.98, -0.8), 0.6)
				"in":
					_chhatri(k, Vector3(1.2, 2.98, -0.8), 0.55)
		"havaalani":
			match st:
				"ru":
					_star(k, Vector3(0, 3.0, 0.42), 0.22)
				"ir":
					_dome_persian(k, Vector3(0, 4.34, 0), 0.45)
				"pk":
					_dome_mughal(k, Vector3(0, 4.34, 0), 0.45)
				"in":
					_chhatri(k, Vector3(0, 4.34, 0), 0.45)
				"ua":
					_dome_pear(k, Vector3(0, 4.34, 0), 0.32)
		"house", "block":
			match st:
				"ir":
					_badgir(k, Vector3(1.3, 2.2, -1.1), 1.0)
				"il":
					_solar(k, Vector3(0.8, 2.4, -0.6))
				"pk", "in":
					_chhatri(k, Vector3(-1.3, 2.4, -1.0), 0.35)


## Çatı kenarında renkli şerit (ulusal renkler).
static func _band(k: Kit, c: Vector3, w: float, d: float) -> void:
	for sx in [-1.0, 1.0]:
		k.box("accent", Vector3(w + 0.04, 0.14, 0.05), c + Vector3(0, -0.2, sx * d * 0.5))
		k.box("accent", Vector3(0.05, 0.14, d + 0.04), c + Vector3(sx * w * 0.5, -0.2, 0))
		k.box("accent2", Vector3(w + 0.04, 0.07, 0.05), c + Vector3(0, -0.32, sx * d * 0.5))


## Ukrayna barok armut kubbesi: kasnak, iki kademeli altın armut, fener ve haç.
static func _dome_pear(k: Kit, p: Vector3, r: float) -> void:
	k.lathe("conc", [Vector2(r * 0.9, 0), Vector2(r * 0.9, r * 0.6), Vector2(r * 0.95, r * 0.62)], p, Vector3.ZERO, 12)
	k.lathe("roof", [Vector2(r * 0.95, r * 0.62), Vector2(r * 1.05, r * 0.95), Vector2(r * 0.8, r * 1.35), Vector2(r * 0.25, r * 1.6), Vector2(r * 0.2, r * 1.7)], p, Vector3.ZERO, 12)
	k.lathe("dome", [Vector2(r * 0.2, r * 1.7), Vector2(r * 0.38, r * 1.9), Vector2(r * 0.3, r * 2.15), Vector2(r * 0.06, r * 2.35), Vector2(0, r * 2.4)], p, Vector3.ZERO, 10)
	k.box("gold", Vector3(0.04, r * 0.6, 0.04), p + Vector3(0, r * 2.65, 0))
	k.box("gold", Vector3(r * 0.3, 0.04, 0.04), p + Vector3(0, r * 2.75, 0))


## Rus soğan kubbesi: ince boyun, şişkin altın soğan, sivri tepe.
static func _dome_onion(k: Kit, p: Vector3, r: float) -> void:
	k.lathe("conc2", [Vector2(r * 0.7, 0), Vector2(r * 0.7, r * 0.7), Vector2(r * 0.55, r * 0.75)], p, Vector3.ZERO, 12)
	k.lathe("dome", [Vector2(r * 0.55, r * 0.75), Vector2(r * 1.0, r * 1.05), Vector2(r * 0.95, r * 1.35), Vector2(r * 0.5, r * 1.7), Vector2(r * 0.08, r * 2.05), Vector2(0, r * 2.15)], p, Vector3.ZERO, 14)
	k.box("gold", Vector3(0.04, r * 0.5, 0.04), p + Vector3(0, r * 2.35, 0))


## Rus çadır çatılı kule (şatyor): kare gövde, piramit yeşil çatı, tepede kızıl yıldız.
static func _shatyor(k: Kit, p: Vector3, r: float) -> void:
	k.box("conc", Vector3(r * 2.0, r * 2.4, r * 2.0), p + Vector3(0, r * 1.2, 0))
	k.box("conc2", Vector3(r * 2.1, r * 0.14, r * 2.1), p + Vector3(0, r * 2.4, 0))
	for sx in [-1.0, 1.0]:
		k.box("glass", Vector3(r * 0.5, r * 0.8, 0.04), p + Vector3(sx * r * 0.45, r * 1.5, r * 1.01))
	k.loft("roof", [Tanks._plan(r * 2.45, [Vector2(r, r), Vector2(r, -r)]).map(func(v): return v + p),
		Tanks._plan(r * 4.4, [Vector2(0.02, 0.02), Vector2(0.02, -0.02)]).map(func(v): return v + p)])
	_star(k, p + Vector3(0, r * 4.7, 0), r * 0.35)


## Beş köşeli kızıl yıldız (cephede, +Z'ye bakar).
static func _star(k: Kit, p: Vector3, r: float) -> void:
	var outer: Array = []
	var inner: Array = []
	for i in 5:
		var a := PI * 0.5 + i * TAU / 5.0
		outer.append(Vector2(cos(a), sin(a)) * r)
		var b := a + TAU / 10.0
		inner.append(Vector2(cos(b), sin(b)) * r * 0.42)
	var pent0: Array = []
	var pent1: Array = []
	for v in inner:
		pent0.append(p + Vector3(v.x, v.y, 0.0))
		pent1.append(p + Vector3(v.x, v.y, 0.06))
	k.loft("accent", [pent0, pent1])
	for i in 5:
		var a2: Vector2 = inner[(i + 4) % 5]
		var b2: Vector2 = inner[i]
		var c2: Vector2 = outer[i]
		k.loft("accent", [[p + Vector3(a2.x, a2.y, 0), p + Vector3(c2.x, c2.y, 0), p + Vector3(b2.x, b2.y, 0)],
			[p + Vector3(a2.x, a2.y, 0.06), p + Vector3(c2.x, c2.y, 0.06), p + Vector3(b2.x, b2.y, 0.06)]])


## İran kubbesi: yüksek kasnak, hafif sivri turkuaz kubbe, altın alem; kasnakta koyu mavi çini şerit.
static func _dome_persian(k: Kit, p: Vector3, r: float) -> void:
	k.lathe("conc", [Vector2(r * 0.85, 0), Vector2(r * 0.85, r * 0.55)], p, Vector3.ZERO, 16)
	k.lathe("accent", [Vector2(r * 0.86, r * 0.3), Vector2(r * 0.86, r * 0.5)], p, Vector3.ZERO, 16)
	k.lathe("dome", [Vector2(r * 0.88, r * 0.55), Vector2(r * 0.95, r * 0.85), Vector2(r * 0.82, r * 1.2), Vector2(r * 0.5, r * 1.5), Vector2(r * 0.12, r * 1.72), Vector2(0, r * 1.78)], p, Vector3.ZERO, 16)
	k.box("gold", Vector3(0.05, r * 0.5, 0.05), p + Vector3(0, r * 2.0, 0))
	k.lathe("gold", [Vector2(0, 0), Vector2(r * 0.09, r * 0.08), Vector2(0, r * 0.16)], p + Vector3(0, r * 1.95, 0), Vector3.ZERO, 8)


## Babür kubbesi: beyaz mermer, soğanımsı, lotus taçlı alem.
static func _dome_mughal(k: Kit, p: Vector3, r: float) -> void:
	k.lathe("conc2", [Vector2(r * 0.8, 0), Vector2(r * 0.8, r * 0.4)], p, Vector3.ZERO, 16)
	k.lathe("dome", [Vector2(r * 0.75, r * 0.4), Vector2(r * 1.05, r * 0.8), Vector2(r * 1.0, r * 1.15), Vector2(r * 0.6, r * 1.55), Vector2(r * 0.15, r * 1.8), Vector2(0, r * 1.85)], p, Vector3.ZERO, 16)
	k.lathe("gold", [Vector2(r * 0.18, 0), Vector2(r * 0.08, r * 0.2), Vector2(r * 0.1, r * 0.3), Vector2(0, r * 0.5)], p + Vector3(0, r * 1.8, 0), Vector3.ZERO, 8)


## Çhatri: dört sütun üstünde küçük kubbeli köşk.
static func _chhatri(k: Kit, p: Vector3, r: float) -> void:
	k.box("conc2", Vector3(r * 2.0, r * 0.18, r * 2.0), p + Vector3(0, r * 0.09, 0))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box("conc", Vector3(r * 0.2, r * 1.1, r * 0.2), p + Vector3(sx * r * 0.75, r * 0.73, sz * r * 0.75))
	k.box("conc2", Vector3(r * 2.2, r * 0.16, r * 2.2), p + Vector3(0, r * 1.36, 0))
	k.lathe("dome", [Vector2(r * 0.9, 0), Vector2(r * 0.85, r * 0.4), Vector2(r * 0.5, r * 0.8), Vector2(r * 0.1, r * 1.0), Vector2(0, r * 1.05)], p + Vector3(0, r * 1.44, 0), Vector3.ZERO, 12)
	k.lathe("gold", [Vector2(r * 0.08, 0), Vector2(0, r * 0.35)], p + Vector3(0, r * 2.48, 0), Vector3.ZERO, 6)


## Rüzgâr kulesi (badgir): uzun kare kule, dört yüzünde dikey yarıklar, düz başlık.
static func _badgir(k: Kit, p: Vector3, h: float) -> void:
	var w := 0.62
	k.box("conc", Vector3(w, h, w), p + Vector3(0, h * 0.5, 0))
	k.box("conc2", Vector3(w + 0.1, 0.1, w + 0.1), p + Vector3(0, h + 0.05, 0))
	for i in 3:
		var off := -w * 0.3 + i * w * 0.3
		k.box("dark", Vector3(0.07, h * 0.4, 0.02), p + Vector3(off, h * 0.72, w * 0.51))
		k.box("dark", Vector3(0.07, h * 0.4, 0.02), p + Vector3(off, h * 0.72, -w * 0.51))
		k.box("dark", Vector3(0.02, h * 0.4, 0.07), p + Vector3(w * 0.51, h * 0.72, off))
		k.box("dark", Vector3(0.02, h * 0.4, 0.07), p + Vector3(-w * 0.51, h * 0.72, off))


## Eyvan: cephede çini çerçeveli, sivri kemerli büyük giriş.
static func _iwan(k: Kit, p: Vector3, w: float, h: float) -> void:
	k.box("accent", Vector3(w + 0.5, h + 0.4, 0.08), p + Vector3(0, (h + 0.4) * 0.5, 0.0))
	k.box("dome", Vector3(w + 0.3, h + 0.25, 0.1), p + Vector3(0, (h + 0.25) * 0.5, 0.02))
	k.box("dark", Vector3(w, h * 0.65, 0.12), p + Vector3(0, h * 0.325, 0.03))
	# sivri kemer: iki eğik kanat
	for sx in [-1.0, 1.0]:
		k.box("dark", Vector3(w * 0.58, h * 0.26, 0.12), p + Vector3(sx * w * 0.2, h * 0.75, 0.03), Vector3(0, 0, -sx * 28.0))
	k.box("gold", Vector3(w + 0.5, 0.06, 0.1), p + Vector3(0, h + 0.42, 0.02))


## Kemerli revak: sütunlar ve yarım daire kemerler (Kudüs taşı).
static func _arcade(k: Kit, p: Vector3, n: int, span: float, h: float) -> void:
	for i in n + 1:
		k.box("conc2", Vector3(0.14, h, 0.16), p + Vector3(i * span, h * 0.5, 0.05))
	for i in n:
		var c := p + Vector3((i + 0.5) * span, h, 0.05)
		k.lathe("conc2", [Vector2(span * 0.5, 0), Vector2(span * 0.5, 0.05), Vector2(span * 0.42, 0.05), Vector2(span * 0.42, 0.0)], c, Vector3(90, 0, 0), 12)
	k.box("conc2", Vector3(n * span + 0.2, 0.12, 0.2), p + Vector3(n * span * 0.5, h + span * 0.5 + 0.06, 0.05))


## Güneş enerjili su ısıtıcısı: eğik panel ve beyaz depo (İsrail çatılarının simgesi).
static func _solar(k: Kit, p: Vector3) -> void:
	k.box("steel", Vector3(0.05, 0.4, 0.05), p + Vector3(-0.4, 0.2, -0.3))
	k.box("steel", Vector3(0.05, 0.4, 0.05), p + Vector3(0.4, 0.2, -0.3))
	k.box("solar", Vector3(1.0, 0.05, 0.8), p + Vector3(0, 0.3, 0.05), Vector3(28, 0, 0))
	Tanks._cyl(k, "white", 0.17, 1.0, p + Vector3(0, 0.55, -0.42), Vector3(0, 0, 90), 10)


## Cumbalı pencere (jharokha): duvardan taşan, küçük kubbeli balkon.
static func _jharokha(k: Kit, p: Vector3) -> void:
	k.box("conc2", Vector3(0.9, 0.12, 0.45), p + Vector3(0, -0.35, 0.2))
	k.box("conc", Vector3(0.8, 0.55, 0.38), p + Vector3(0, 0.0, 0.2))
	k.box("dark", Vector3(0.5, 0.35, 0.02), p + Vector3(0, 0.0, 0.4))
	k.lathe("dome", [Vector2(0.45, 0), Vector2(0.3, 0.2), Vector2(0, 0.32)], p + Vector3(0, 0.3, 0.2), Vector3.ZERO, 10)
