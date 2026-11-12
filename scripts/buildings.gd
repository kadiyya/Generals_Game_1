class_name Buildings
extends RefCounted
## Bina modelleri, vinç ve ikmal noktaları. Ölçüler oyun birimindedir; ön taraf +Z. Hepsi Kit ile tek mesh kurulur:
## tabanlar topraklanır ve gölgelenir, takım rengi bayrak, çatı şeridi ve boyalı bantlarla gösterilir.
## Not: bu dosya yalnızca Kit çağrıları ve düz hesap içerir; geliştirme önizleme aracı da aynı kodu okur.

const IDS := ["hq", "santral", "maden", "kisla", "fabrika", "havaalani", "teknoloji", "fuze", "sam_box", "sam_tube",
	"crane", "supply_oil", "supply_crates"]


static func has(id: String) -> bool:
	return id in IDS


## Araç yuvalarına ek olarak beton, sac, asfalt ve boya renkleri.
static func slots(k: Kit, bc: Color, tc: Color) -> void:
	Vehicles.slots(k, bc, tc)
	k.slot("conc", "concrete", Color(0.62, 0.61, 0.57), 0.5)
	k.slot("conc2", "concrete", Color(0.46, 0.46, 0.44), 0.5)
	k.slot("roof", "corrug", Color(0.42, 0.45, 0.47), 0.35)
	k.slot("sheet", "corrug", Color(0.6, 0.62, 0.6), 0.45)
	k.slot("asphalt", "concrete", Color(0.2, 0.2, 0.21), 0.3)
	k.slot("white", "fabric", Color(0.86, 0.86, 0.82), 0.15)
	k.slot("red", "fabric", Color(0.7, 0.16, 0.12), 0.1)
	k.slot("yellow", "steel", Color(0.95, 0.72, 0.1), 0.2)
	k.slot("ore", "concrete", Color(0.3, 0.26, 0.22), 0.3)
	k.slot("sand", "fabric", Color(0.62, 0.55, 0.4), 0.4)
	k.slot("teamroof", "corrug", tc.darkened(0.1), 0.15)


static func design(id: String, k: Kit) -> void:
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
		var z := 2.6 * sz
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
