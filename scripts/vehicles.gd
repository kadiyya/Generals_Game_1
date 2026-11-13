class_name Vehicles
extends RefCounted
## Tank dışındaki kara araçları ve piyade. Ölçüler gerçek araçlardan (metre), Tanks.S ile küçültülür.
## Ortak parçalar (yürüyen aksam, kapak, nişangâh, ızgara...) Tanks içindedir. h gövde, t kule kurucusu;
## kule parçaları kule merkezine göre yazılır, design() merkezin z'sini döndürür. Kulesi olmayanlarda t boş kalır.
## Not: bu dosya yalnızca Kit çağrıları ve düz hesap içerir; geliştirme önizleme aracı da aynı kodu okur.

const IDS := ["ifv_low", "m113", "ifv_tall", "namer", "gepard", "shilka", "tor", "sph", "tos", "pantsir", "irondome",
	"truck_gun", "himars", "mlrs_truck", "laser_truck", "ew_truck"]


static func has(id: String) -> bool:
	return id in IDS


## Tank yuvalarına ek olarak üniforma, yelek ve ten.
static func slots(k: Kit, bc: Color, tc: Color) -> void:
	Tanks.slots(k, bc, tc)
	k.slot("uniform", "armor", bc.lerp(Color(0.4, 0.4, 0.34), 0.3), 0.35)
	k.slot("vest", "fabric", bc.darkened(0.42), 0.2)
	k.slot("flesh", "fabric", Color(0.74, 0.57, 0.44), 0.0)
	k.slot("helmet", "fabric", tc.darkened(0.12), 0.05)
	k.slot("beam", "optic", Color(0.25, 0.8, 0.95), 0.0)
	k.slot("missile", "fabric", Color(0.8, 0.8, 0.76), 0.1)


static func design(id: String, h: Kit, t: Kit) -> float:
	var s := Tanks.S
	h.push(Vector3.ZERO, Vector3.ZERO, s)
	t.push(Vector3.ZERO, Vector3.ZERO, s)
	var tz := 0.0
	if id == "ifv_low":
		tz = _bmp(h, t)
	elif id == "m113":
		tz = _m113(h, t)
	elif id == "ifv_tall":
		tz = _bradley(h, t)
	elif id == "namer":
		tz = _namer(h, t)
	elif id == "gepard":
		tz = _gepard(h, t)
	elif id == "shilka":
		tz = _shilka(h, t)
	elif id == "tor":
		tz = _tor(h, t)
	elif id == "sph":
		tz = _sph(h, t)
	elif id == "tos":
		_tos(h)
	elif id == "pantsir":
		tz = _pantsir(h, t)
	elif id == "irondome":
		_irondome(h)
	elif id == "truck_gun":
		_truck_gun(h)
	elif id == "himars":
		_himars(h)
	elif id == "mlrs_truck":
		_mlrs(h)
	elif id == "ew_truck":
		_ew(h)
	else:
		_laser(h)
	return tz * s


# ---------------------------------------------------------------- piyade

## Tek asker (ayakta, tüfek önde). launcher: omzunda tanksavar füzesi. Ölçek görünürlük için biraz büyük.
static func soldier(k: Kit, launcher: bool) -> void:
	k.push(Vector3.ZERO, Vector3.ZERO, 0.68)
	for sx in [-1.0, 1.0]:
		k.box("dark", Vector3(0.15, 0.12, 0.3), Vector3(0.11 * sx, 0.06, 0.04))
		k.box("uniform", Vector3(0.17, 0.8, 0.2), Vector3(0.11 * sx, 0.5, 0.0), Vector3(-4.0 * sx, 0, 0))
		k.box("vest", Vector3(0.12, 0.14, 0.08), Vector3(0.13 * sx, 1.02, 0.17))
		k.box("helmet", Vector3(0.03, 0.12, 0.14), Vector3(0.27 * sx, 1.42, 0.0))
	k.box("uniform", Vector3(0.48, 0.6, 0.24), Vector3(0, 1.2, 0))
	k.box("vest", Vector3(0.44, 0.44, 0.3), Vector3(0, 1.2, 0.0))
	k.box("canvas2", Vector3(0.34, 0.42, 0.18), Vector3(0, 1.24, -0.22))
	# kollar: sağ el kabzada, sol el ileride
	k.box("uniform", Vector3(0.12, 0.42, 0.13), Vector3(0.29, 1.25, 0.1), Vector3(-40, 0, 0))
	k.box("uniform", Vector3(0.12, 0.46, 0.13), Vector3(-0.27, 1.27, 0.2), Vector3(-65, 0, 12))
	k.box("flesh", Vector3(0.09, 0.09, 0.1), Vector3(-0.2, 1.17, 0.42))
	# baş ve kask (takım rengi kask kılıfı)
	k.lathe("flesh", [Vector2(0.06, -0.12), Vector2(0.1, -0.04), Vector2(0.1, 0.05), Vector2(0, 0.1)], Vector3(0, 1.64, 0.01), Vector3.ZERO, 8)
	k.lathe("helmet", [Vector2(0.14, -0.02), Vector2(0.14, 0.06), Vector2(0.1, 0.13), Vector2(0, 0.16)], Vector3(0, 1.66, 0.0), Vector3.ZERO, 8)
	if launcher:
		k.lathe("hull2", [Vector2(0, 0), Vector2(0.075, 0), Vector2(0.075, 1.15), Vector2(0.09, 1.17), Vector2(0.09, 1.3), Vector2(0, 1.3)],
			Vector3(0.2, 1.56, -0.5), Vector3(90, 0, 0), 8)
		k.box("dark", Vector3(0.1, 0.14, 0.16), Vector3(0.2, 1.68, 0.25))
	else:
		k.box("dark", Vector3(0.05, 0.09, 0.5), Vector3(0.14, 1.2, 0.3))
		k.box("dark", Vector3(0.03, 0.03, 0.34), Vector3(0.14, 1.22, 0.7))
		k.box("dark", Vector3(0.04, 0.16, 0.07), Vector3(0.14, 1.1, 0.34), Vector3(15, 0, 0))
	k.pop()


# ---------------------------------------------------------------- zırhlı muharebe araçları

## Alt gövde (paletler arası) ve üst gövde (paletlerin üstü) iki yan kesitle.
static func _hull(k: Kit, lower: Array, upper: Array, xl: float, xu: float) -> void:
	Tanks._side(k, "hull", lower, -xl, xl)
	Tanks._side(k, "hull", upper, -xu, xu)


static func _tracks(k: Kit, x: float, tw: float, wz: Array, wr: float, front: Vector3, rear: Vector3, front_drive: bool, rr: Array, rry: float) -> void:
	for sx in [-1.0, 1.0]:
		Tanks._running(k, sx, x, tw, wz, wr, front, rear, front_drive, rr, rry)


## Far (çelik yuva + lamba), öne bakar.
static func _lamp(k: Kit, p: Vector3) -> void:
	k.box("steel", Vector3(0.18, 0.16, 0.12), p)
	Tanks._cyl(k, "lamp", 0.06, 0.03, p + Vector3(0, 0, 0.07), Vector3(90, 0, 0), 8)


## Otomatik top: ince namlu, ucunda alev gizleyen. e: yükseliş açısı (derece).
static func _autocannon(k: Kit, p: Vector3, ln: float, r: float, e: float) -> void:
	k.lathe("steel", [Vector2(0, 0), Vector2(r * 1.6, 0), Vector2(r * 1.6, ln * 0.25), Vector2(r, ln * 0.27), Vector2(r, ln * 0.9),
		Vector2(r * 1.5, ln * 0.92), Vector2(r * 1.5, ln), Vector2(0, ln)], p, Vector3(90 - e, 0, 0), 8)


## BMP-2 / BMP-3: alçak, sivri burunlu gövde, küçük konik kule, arkada kapılar.
static func _bmp(h: Kit, t: Kit) -> float:
	_tracks(h, 1.32, 0.38, [-2.5, -1.55, -0.6, 0.35, 1.3, 2.25], 0.29, Vector3(3.0, 0.62, 0.26), Vector3(-3.05, 0.55, 0.24), true, [-1.2, 0.8], 0.8)
	_hull(h, [Vector2(3.45, 1.0), Vector2(2.95, 0.42), Vector2(-3.3, 0.42), Vector2(-3.4, 1.0)],
		[Vector2(3.45, 1.0), Vector2(1.7, 1.5), Vector2(-3.4, 1.5), Vector2(-3.45, 1.0)], 1.1, 1.58)
	# dalga kıran levha, sürücü kapağı, motor ızgarası (sağ ön), farlar
	h.box("hull2", Vector3(2.6, 0.04, 1.3), Vector3(0, 1.3, 2.52), Vector3(16, 0, 0))
	Tanks._hatch(h, Vector3(-0.75, 1.5, 1.2), 0.27)
	Tanks._grille(h, Vector3(0.75, 1.52, 1.1), 0.9, 0.8, 0.0, 5)
	for sx in [-1.0, 1.0]:
		_lamp(h, Vector3(1.3 * sx, 1.2, 3.05))
		h.box("rubber", Vector3(0.03, 0.26, 5.4), Vector3(1.59 * sx, 0.86, -0.2))
		h.box("hull2", Vector3(0.75, 1.0, 0.06), Vector3(0.4 * sx, 0.98, -3.44))
		Tanks._hatch(h, Vector3(0.6 * sx, 1.5, -2.2), 0.3)
		for i in 3:
			h.box("glass", Vector3(0.04, 0.07, 0.16), Vector3(1.59 * sx, 1.36, -0.6 - i * 0.8))
	Tanks._panel(h, Vector3(0, 1.515, -1.2), 1.4, 0.8, 0.0)
	Tanks._crate(h, "hull", Vector3(0.9, 0.2, 0.5), Vector3(0, 1.6, -3.0))
	# kule: alçak koni, 30 mm top, tanksavar füzesi, projektör
	t.loft("hull", [Tanks._egg(1.5, 0.95, 1.0, 0.95), Tanks._egg(1.78, 0.82, 0.86, 0.8), Tanks._egg(1.92, 0.55, 0.55, 0.6)], true)
	t.loft("team", [Tanks._egg(1.56, 0.96, 1.0, 0.95), Tanks._egg(1.64, 0.92, 0.97, 0.92)], true)
	t.box("hull2", Vector3(0.4, 0.3, 0.4), Vector3(0, 1.72, 0.85))
	_autocannon(t, Vector3(0, 1.72, 1.0), 2.5, 0.04, 2.0)
	t.lathe("hull2", [Vector2(0, 0), Vector2(0.09, 0), Vector2(0.09, 1.1), Vector2(0, 1.1)], Vector3(0.1, 2.12, -0.5), Vector3(90, 0, 0), 8)
	t.box("steel", Vector3(0.08, 0.2, 0.08), Vector3(0.1, 2.0, 0.0))
	Tanks._hatch(t, Vector3(0.38, 1.9, -0.2), 0.24)
	Tanks._sight(t, "hull2", Vector3(0.24, 0.2, 0.26), Vector3(-0.4, 1.98, 0.25), 0.0)
	Tanks._smoke(t, Vector3(0.8, 1.75, 0.45), 45.0, 3)
	Tanks._smoke(t, Vector3(-0.8, 1.75, 0.45), -45.0, 3)
	Tanks._antenna(t, Vector3(-0.5, 1.9, -0.45), 1.8)
	return 0.1


## Boragh / Talha (M113 türevi): kutu gövde, eğik ön levha, üstte makineli tüfekli kupola.
static func _m113(h: Kit, t: Kit) -> float:
	_tracks(h, 1.12, 0.38, [-1.75, -0.9, -0.05, 0.8, 1.65], 0.3, Vector3(2.25, 0.62, 0.25), Vector3(-2.25, 0.5, 0.22), true, [], 0.8)
	_hull(h, [Vector2(2.5, 1.0), Vector2(2.2, 0.42), Vector2(-2.4, 0.42), Vector2(-2.45, 1.0)],
		[Vector2(2.5, 1.0), Vector2(1.75, 1.85), Vector2(-2.45, 1.85), Vector2(-2.45, 1.0)], 0.9, 1.34)
	h.box("hull2", Vector3(2.3, 0.04, 0.95), Vector3(0, 1.5, 2.2), Vector3(-48.5, 0, 0))
	Tanks._grille(h, Vector3(0.6, 1.87, 1.2), 0.9, 0.7, 0.0, 5)
	Tanks._hatch(h, Vector3(-0.7, 1.85, 1.2), 0.26)
	h.box("hull2", Vector3(1.5, 0.05, 1.3), Vector3(0, 1.87, -1.5))
	Tanks._panel(h, Vector3(0, 1.91, -1.5), 1.2, 0.9, 0.0)
	h.box("hull2", Vector3(1.6, 1.2, 0.06), Vector3(0, 1.15, -2.47))
	for sx in [-1.0, 1.0]:
		_lamp(h, Vector3(0.95 * sx, 1.35, 2.3))
		h.box("rubber", Vector3(0.03, 0.22, 4.2), Vector3(1.35 * sx, 0.9, 0.0))
		h.box("team", Vector3(0.012, 0.12, 2.2), Vector3(1.35 * sx, 1.55, -0.9))
		Tanks._crate(h, "hull", Vector3(0.12, 0.3, 0.9), Vector3(1.4 * sx, 1.4, 0.6))
	Tanks._antenna(h, Vector3(-1.1, 1.85, -2.1), 1.8)
	# kupola ve 12,7 mm tüfek
	t.lathe("hull2", [Vector2(0.42, 0), Vector2(0.42, 0.16), Vector2(0.36, 0.2), Vector2(0, 0.2)], Vector3(0, 1.85, 0), Vector3.ZERO, 10)
	t.box("hull2", Vector3(0.7, 0.4, 0.04), Vector3(0, 2.2, 0.3), Vector3(-12, 0, 0))
	Tanks._mg(t, Vector3(0, 2.2, 0.45), 0.0, 0.9)
	return 0.0


## M2 Bradley: yüksek gövde, yan zırh plakaları, 25 mm toplu kule ve yanında TOW atıcı.
static func _bradley(h: Kit, t: Kit) -> float:
	_tracks(h, 1.4, 0.5, [-2.4, -1.5, -0.6, 0.3, 1.2, 2.1], 0.32, Vector3(2.9, 0.68, 0.3), Vector3(-2.95, 0.6, 0.26), true, [-1.0, 1.0], 0.92)
	_hull(h, [Vector2(3.25, 1.1), Vector2(2.85, 0.45), Vector2(-3.1, 0.45), Vector2(-3.2, 1.1)],
		[Vector2(3.25, 1.1), Vector2(2.0, 1.95), Vector2(-3.2, 2.0), Vector2(-3.25, 1.1)], 1.1, 1.65)
	Tanks._era(h, "hull2", Vector2(3.2, 1.16), Vector2(2.08, 1.92), -1.55, 1.55, 2, 6, 0.1)
	for sx in [-1.0, 1.0]:
		for i in 6:
			h.box("hull2", Vector3(0.1, 0.62, 0.92), Vector3(1.72 * sx, 1.02, 2.3 - i * 0.98))
			h.box("hull2", Vector3(0.08, 0.5, 0.92), Vector3(1.7 * sx, 1.66, 2.3 - i * 0.98))
		_lamp(h, Vector3(1.35 * sx, 1.55, 2.75))
		h.box("team", Vector3(0.012, 0.1, 2.4), Vector3(1.745 * sx, 1.85, -1.4))
	Tanks._hatch(h, Vector3(-0.8, 1.97, 1.5), 0.28)
	Tanks._grille(h, Vector3(0.6, 1.99, 1.4), 1.1, 0.8, 0.0, 5)
	h.box("hull2", Vector3(1.3, 0.05, 1.3), Vector3(0, 2.02, -2.2))
	Tanks._panel(h, Vector3(0, 2.06, -2.2), 1.1, 0.9, 0.0)
	h.box("hull2", Vector3(1.9, 1.3, 0.08), Vector3(0, 1.3, -3.24))
	Tanks._bag(h, "canvas", Vector3(0.3, 0.3, 0.9), Vector3(1.2, 2.14, -1.0), 0.0)
	# kule
	t.loft("hull", [Tanks._plan(2.0, [Vector2(0.45, 1.05), Vector2(0.95, 0.6), Vector2(0.95, -0.9), Vector2(0.6, -1.15)]),
		Tanks._plan(2.6, [Vector2(0.4, 0.8), Vector2(0.85, 0.5), Vector2(0.85, -0.85), Vector2(0.55, -1.05)])])
	t.box("hull2", Vector3(0.5, 0.35, 0.3), Vector3(0, 2.32, 0.95))
	_autocannon(t, Vector3(0, 2.32, 1.05), 2.3, 0.045, 3.0)
	t.box("hull2", Vector3(0.38, 0.5, 1.25), Vector3(-1.15, 2.4, -0.05))
	t.box("dark", Vector3(0.3, 0.4, 0.02), Vector3(-1.15, 2.4, 0.585))
	Tanks._sight(t, "hull2", Vector3(0.4, 0.25, 0.45), Vector3(0.45, 2.72, 0.3), 0.0)
	Tanks._hatch(t, Vector3(0.38, 2.6, -0.45), 0.25)
	Tanks._hatch(t, Vector3(-0.38, 2.6, -0.45), 0.25)
	Tanks._smoke(t, Vector3(0.75, 2.3, 0.75), 30.0, 4)
	t.box("steel", Vector3(1.6, 0.03, 0.4), Vector3(0, 2.25, -1.3))
	Tanks._bag(t, "canvas2", Vector3(0.3, 0.26, 1.2), Vector3(0, 2.4, -1.32), 90.0)
	Tanks._antenna(t, Vector3(0.7, 2.6, -0.9), 1.8)
	return 0.3


## Namer: Merkava gövdesinde kulesiz ağır zırhlı personel taşıyıcı; üstte uzaktan kumandalı tüfek.
static func _namer(h: Kit, t: Kit) -> float:
	_tracks(h, 1.47, 0.64, [-2.4, -1.46, -0.52, 0.42, 1.36, 2.3], 0.395, Vector3(3.3, 0.66, 0.33), Vector3(-3.3, 0.62, 0.3), true, [-1.9, 0.0, 1.9], 0.98)
	_hull(h, [Vector2(3.8, 1.0), Vector2(3.3, 0.5), Vector2(-3.6, 0.5), Vector2(-3.8, 1.07)],
		[Vector2(3.8, 1.0), Vector2(1.1, 1.75), Vector2(-3.5, 1.75), Vector2(-3.8, 1.55), Vector2(-3.8, 1.07)], 1.15, 1.86)
	# yükseltilmiş personel bölmesi
	h.loft("hull", [Tanks._plan(1.75, [Vector2(1.5, 0.9), Vector2(1.7, 0.3), Vector2(1.7, -3.0), Vector2(1.5, -3.4)]),
		Tanks._plan(2.25, [Vector2(1.3, 0.5), Vector2(1.5, 0.1), Vector2(1.5, -2.9), Vector2(1.3, -3.2)])])
	for sx in [-1.0, 1.0]:
		for i in 4:
			h.box("hull", Vector3(0.12, 0.6, 0.9), Vector3(1.92 * sx, 0.8, 3.15 - i * 0.92))
			h.box("hull", Vector3(0.05, 0.5, 0.9), Vector3(1.9 * sx, 0.84, -0.6 - i * 0.92))
		_lamp(h, Vector3(1.55 * sx, 1.1, 3.62))
		h.box("team", Vector3(0.012, 0.12, 2.6), Vector3(1.64 * sx, 2.0, -1.4), Vector3(0, 0, 21.8 * sx))
		Tanks._hatch(h, Vector3(0.75 * sx, 2.25, -1.9), 0.3)
		Tanks._antenna(h, Vector3(1.2 * sx, 2.25, -2.9), 2.0)
	Tanks._grille(h, Vector3(0.62, 1.47, 2.0), 1.0, 1.3, 15.5, 7)
	Tanks._hatch(h, Vector3(-0.7, 2.25, -0.3), 0.3)
	Tanks._panel(h, Vector3(0, 2.27, -1.0), 1.5, 0.9, 0.0)
	h.box("hull2", Vector3(1.4, 0.9, 0.05), Vector3(0, 1.2, -3.82))
	Tanks._bag(h, "canvas2", Vector3(0.3, 0.3, 1.0), Vector3(0, 2.4, -2.9), 90.0)
	# uzaktan kumandalı silah istasyonu
	Tanks._cyl(t, "hull2", 0.3, 0.2, Vector3(0, 2.35, 0), Vector3.ZERO, 8)
	t.box("hull2", Vector3(0.5, 0.4, 0.5), Vector3(0, 2.62, 0))
	Tanks._sight(t, "hull2", Vector3(0.2, 0.2, 0.2), Vector3(0.38, 2.65, 0.1), 0.0)
	Tanks._mg(t, Vector3(-0.1, 2.7, 0.3), 0.0, 1.0)
	return 0.5


# ---------------------------------------------------------------- hareketli hava savunma

## Radar anteni: eğik dikdörtgen levha ve direği.
static func _radar(k: Kit, p: Vector3, w: float, hgt: float, tilt: float) -> void:
	k.box("steel", Vector3(0.1, hgt * 0.6, 0.1), p + Vector3(0, -hgt * 0.4, -0.05))
	k.push(p, Vector3(tilt, 0, 0))
	k.box("hull2", Vector3(w, hgt, 0.08), Vector3.ZERO)
	k.box("steel", Vector3(w * 0.9, hgt * 0.85, 0.02), Vector3(0, 0, 0.05))
	k.pop()


## Flakpanzer Gepard: Leopard 1 gövdesi, kutunun iki yanında 35 mm toplar, arkada arama önde takip radarı.
static func _gepard(h: Kit, t: Kit) -> float:
	_tracks(h, 1.4, 0.55, [-2.4, -1.6, -0.8, 0.0, 0.8, 1.6, 2.4], 0.33, Vector3(3.15, 0.58, 0.28), Vector3(-3.2, 0.62, 0.3), false, [-1.6, 0.0, 1.6], 0.88)
	_hull(h, [Vector2(3.55, 1.0), Vector2(3.2, 0.48), Vector2(-3.4, 0.48), Vector2(-3.55, 1.05)],
		[Vector2(3.55, 1.0), Vector2(2.6, 1.42), Vector2(-3.4, 1.45), Vector2(-3.55, 1.05)], 1.1, 1.65)
	for sx in [-1.0, 1.0]:
		h.box("hull", Vector3(0.05, 0.42, 6.2), Vector3(1.68 * sx, 0.85, -0.1))
		_lamp(h, Vector3(1.3 * sx, 1.25, 3.2))
		Tanks._grille(h, Vector3(0.7 * sx, 1.47, -2.6), 1.0, 1.1, 0.0, 6)
	Tanks._panel(h, Vector3(0, 1.52, -2.6), 1.2, 0.8, 0.0)
	Tanks._hatch(h, Vector3(0.7, 1.44, 2.1), 0.27)
	# kule
	t.loft("hull", [Tanks._plan(1.45, [Vector2(0.75, 1.3), Vector2(1.1, 0.9), Vector2(1.1, -1.2), Vector2(0.8, -1.5)]),
		Tanks._plan(2.55, [Vector2(0.7, 1.1), Vector2(1.0, 0.8), Vector2(1.0, -1.1), Vector2(0.75, -1.35)])])
	t.loft("team", [Tanks._plan(2.2, [Vector2(0.72, 1.18), Vector2(1.04, 0.84), Vector2(1.04, -1.14), Vector2(0.77, -1.41)]),
		Tanks._plan(2.32, [Vector2(0.71, 1.16), Vector2(1.03, 0.83), Vector2(1.03, -1.13), Vector2(0.77, -1.4)])])
	for sx in [-1.0, 1.0]:
		t.box("hull2", Vector3(0.42, 0.6, 1.5), Vector3(1.3 * sx, 2.05, 0.0), Vector3(-15, 0, 0))
		_autocannon(t, Vector3(1.3 * sx, 2.2, 0.6), 3.0, 0.05, 15.0)
		Tanks._smoke(t, Vector3(0.85 * sx, 1.7, 1.15), 25.0 * sx, 4)
	Tanks._cyl(t, "hull2", 0.42, 0.25, Vector3(0, 2.2, 1.3), Vector3(90, 0, 0), 10)
	_radar(t, Vector3(0, 3.3, -1.25), 1.7, 0.7, -12.0)
	Tanks._hatch(t, Vector3(0.4, 2.55, -0.2), 0.27)
	Tanks._sight(t, "hull2", Vector3(0.25, 0.25, 0.3), Vector3(-0.45, 2.68, 0.4), 0.0)
	return 0.1


## ZSU-23-4 Shilka: hafif gövde, geniş yassı kule, ortada dörtlü 23 mm top, üstte radar çanağı.
static func _shilka(h: Kit, t: Kit) -> float:
	_tracks(h, 1.3, 0.38, [-2.3, -1.4, -0.5, 0.4, 1.3, 2.2], 0.32, Vector3(2.9, 0.55, 0.24), Vector3(-2.95, 0.6, 0.27), false, [], 0.8)
	_hull(h, [Vector2(3.25, 0.95), Vector2(2.9, 0.42), Vector2(-3.15, 0.42), Vector2(-3.25, 1.0)],
		[Vector2(3.25, 0.95), Vector2(2.4, 1.4), Vector2(-3.2, 1.4), Vector2(-3.25, 1.0)], 1.08, 1.5)
	for sx in [-1.0, 1.0]:
		_lamp(h, Vector3(1.2 * sx, 1.2, 2.9))
		h.box("hull", Vector3(0.5, 0.25, 4.0), Vector3(1.3 * sx, 1.15, -0.4))
	Tanks._grille(h, Vector3(0, 1.42, -2.6), 1.8, 0.9, 0.0, 5)
	Tanks._hatch(h, Vector3(-0.6, 1.4, 2.0), 0.26)
	t.loft("hull", [Tanks._plan(1.4, [Vector2(1.0, 1.45), Vector2(1.4, 0.9), Vector2(1.4, -1.3), Vector2(1.0, -1.7)]),
		Tanks._plan(2.2, [Vector2(0.9, 1.2), Vector2(1.3, 0.8), Vector2(1.3, -1.2), Vector2(0.95, -1.55)])])
	t.box("team", Vector3(2.62, 0.1, 2.0), Vector3(0, 1.95, -0.2))
	t.box("hull2", Vector3(0.9, 0.55, 0.7), Vector3(0, 2.0, 1.25))
	for sx in [-1.0, 1.0]:
		for y in [1.88, 2.12]:
			_autocannon(t, Vector3(0.22 * sx, y, 1.5), 2.2, 0.035, 10.0)
	Tanks._cyl(t, "steel", 0.08, 0.5, Vector3(0, 2.45, -1.0), Vector3.ZERO, 6)
	t.lathe("hull2", [Vector2(0.0, 0.12), Vector2(0.4, 0.2), Vector2(0.75, 0.0), Vector2(0.4, 0.14), Vector2(0, 0.08)], Vector3(0, 2.75, -0.9), Vector3(75, 0, 0), 12)
	Tanks._hatch(t, Vector3(0.6, 2.2, 0.1), 0.27)
	Tanks._panel(t, Vector3(-0.5, 2.21, -0.1), 0.9, 0.8, 0.0)
	return 0.0


## Tor-M1 / FM-90: yüksek kutu kule, üstte katlanır arama radarı, önde takip radarı, dikey füze hücreleri.
static func _tor(h: Kit, t: Kit) -> float:
	_tracks(h, 1.4, 0.5, [-2.5, -1.6, -0.7, 0.2, 1.1, 2.0, 2.9], 0.3, Vector3(3.55, 0.6, 0.26), Vector3(-3.3, 0.62, 0.28), false, [-1.5, 0.5], 0.84)
	_hull(h, [Vector2(3.9, 0.95), Vector2(3.5, 0.45), Vector2(-3.5, 0.45), Vector2(-3.6, 1.0)],
		[Vector2(3.9, 0.95), Vector2(2.9, 1.5), Vector2(-3.55, 1.5), Vector2(-3.6, 1.0)], 1.1, 1.6)
	for sx in [-1.0, 1.0]:
		_lamp(h, Vector3(1.3 * sx, 1.25, 3.5))
		h.box("rubber", Vector3(0.03, 0.25, 6.4), Vector3(1.62 * sx, 0.86, 0.0))
		h.box("glass", Vector3(0.5, 0.2, 0.03), Vector3(0.6 * sx, 1.32, 3.3), Vector3(-29, 0, 0))
	Tanks._grille(h, Vector3(0, 1.52, -2.9), 2.2, 0.9, 0.0, 5)
	t.loft("hull", [Tanks._plan(1.5, [Vector2(0.9, 1.3), Vector2(1.25, 0.9), Vector2(1.25, -1.3), Vector2(0.9, -1.6)]),
		Tanks._plan(2.9, [Vector2(0.85, 1.1), Vector2(1.15, 0.8), Vector2(1.15, -1.2), Vector2(0.85, -1.45)])])
	t.loft("team", [Tanks._plan(2.45, [Vector2(0.88, 1.19), Vector2(1.2, 0.85), Vector2(1.2, -1.25), Vector2(0.88, -1.52)]),
		Tanks._plan(2.58, [Vector2(0.87, 1.17), Vector2(1.19, 0.84), Vector2(1.19, -1.24), Vector2(0.88, -1.5)])])
	t.box("hull2", Vector3(1.3, 1.1, 0.25), Vector3(0, 2.3, 1.3), Vector3(-8, 0, 0))
	t.box("steel", Vector3(1.15, 0.95, 0.03), Vector3(0, 2.3, 1.44), Vector3(-8, 0, 0))
	for i in 4:
		for sx in [-1.0, 1.0]:
			t.box("dark", Vector3(0.42, 0.03, 0.42), Vector3(0.3 * sx, 2.91, 0.5 - i * 0.5))
			t.box("missile", Vector3(0.34, 0.03, 0.34), Vector3(0.3 * sx, 2.92, 0.5 - i * 0.5))
	_radar(t, Vector3(0, 3.75, -1.3), 2.0, 0.7, -10.0)
	return 0.0


# ---------------------------------------------------------------- topçu

## Top namlusu: ağız freni, geri tepme silindirleri. e yükseliş (derece).
static func _howitzer(k: Kit, p: Vector3, ln: float, e: float) -> void:
	k.lathe("hull2", [Vector2(0, 0), Vector2(0.2, 0), Vector2(0.2, ln * 0.18), Vector2(0.13, ln * 0.2), Vector2(0.11, ln * 0.5),
		Vector2(0.15, ln * 0.52), Vector2(0.15, ln * 0.58), Vector2(0.1, ln * 0.6), Vector2(0.09, ln * 0.9), Vector2(0.16, ln * 0.91),
		Vector2(0.16, ln), Vector2(0.07, ln), Vector2(0.07, ln - 0.1), Vector2(0, ln - 0.1)], p, Vector3(90 - e, 0, 0), 10)


## 2S19 Msta-S / K9 / Raad-2: tank benzeri gövde, büyük kutu kule, uzun obüs.
static func _sph(h: Kit, t: Kit) -> float:
	_tracks(h, 1.43, 0.58, [-2.25, -1.38, -0.5, 0.38, 1.26, 2.14], 0.375, Vector3(3.05, 0.55, 0.27), Vector3(-3.1, 0.58, 0.31), false, [-1.5, 0.0, 1.5], 0.86)
	Tanks._side(h, "hull", [Vector2(3.42, 0.95), Vector2(2.2, 1.42), Vector2(-3.42, 1.42), Vector2(-3.4, 0.45), Vector2(2.95, 0.45)], -1.12, 1.12)
	for sx in [-1.0, 1.0]:
		h.box("hull", Vector3(0.66, 0.04, 6.4), Vector3(1.44 * sx, 1.03, 0.0))
		h.box("rubber", Vector3(0.03, 0.3, 6.0), Vector3(1.75 * sx, 0.88, 0.0))
		_lamp(h, Vector3(0.98 * sx, 1.36, 2.4))
		for i in 3:
			Tanks._crate(h, "hull", Vector3(0.5, 0.3, 1.0), Vector3(1.42 * sx, 1.2, 2.0 - i * 2.0))
	Tanks._hatch(h, Vector3(0, 1.42, 1.9), 0.27)
	# kule
	t.loft("hull", [Tanks._plan(1.42, [Vector2(0.9, 1.5), Vector2(1.5, 1.0), Vector2(1.55, -2.6), Vector2(1.3, -2.9)]),
		Tanks._plan(2.75, [Vector2(0.8, 1.1), Vector2(1.35, 0.8), Vector2(1.4, -2.5), Vector2(1.2, -2.75)])])
	t.loft("team", [Tanks._plan(2.3, [Vector2(0.84, 1.26), Vector2(1.42, 0.88), Vector2(1.47, -2.55), Vector2(1.25, -2.82)]),
		Tanks._plan(2.44, [Vector2(0.83, 1.22), Vector2(1.4, 0.86), Vector2(1.45, -2.54), Vector2(1.24, -2.8)])])
	t.box("hull2", Vector3(0.9, 0.8, 0.5), Vector3(0, 2.1, 1.35), Vector3(-10, 0, 0))
	_howitzer(t, Vector3(0, 2.15, 1.4), 6.2, 12.0)
	Tanks._hatch(t, Vector3(0.7, 2.75, -0.2), 0.3)
	Tanks._hatch(t, Vector3(-0.7, 2.75, -0.6), 0.3)
	t.box("steel", Vector3(0.06, 0.25, 0.06), Vector3(0.7, 2.98, 0.15))
	Tanks._mg(t, Vector3(0.7, 3.12, 0.25), 0.0, 0.9)
	Tanks._sight(t, "hull2", Vector3(0.3, 0.25, 0.35), Vector3(-0.6, 2.88, 0.5), 0.0)
	Tanks._panel(t, Vector3(0, 2.76, -1.8), 1.6, 1.0, 0.0)
	Tanks._crate(t, "hull", Vector3(2.2, 0.5, 0.3), Vector3(0, 2.0, -3.05))
	for sx in [-1.0, 1.0]:
		Tanks._smoke(t, Vector3(1.2 * sx, 2.3, 1.15), 30.0 * sx, 3)
		Tanks._antenna(t, Vector3(1.1 * sx, 2.75, -2.5), 2.0)
	return 0.2


## TOS-1A: T-72 gövdesi üstünde 24 lüleli termobarik roket atıcı.
static func _tos(h: Kit) -> void:
	Tanks._t72_hull(h, true)
	Tanks._cyl(h, "hull2", 1.0, 0.3, Vector3(0, 1.57, 0.1), Vector3.ZERO, 12)
	for sx in [-1.0, 1.0]:
		h.box("hull2", Vector3(0.2, 0.9, 1.4), Vector3(1.1 * sx, 2.0, -0.2))
	h.push(Vector3(0, 2.6, -0.1), Vector3(-18, 0, 0))
	h.box("hull", Vector3(2.5, 1.1, 3.4), Vector3.ZERO)
	h.box("team", Vector3(2.52, 0.14, 3.0), Vector3(0, 0.3, 0))
	for i in 8:
		for j in 3:
			var p := Vector3(-1.05 + i * 0.3, -0.34 + j * 0.34, 1.7)
			h.lathe("dark", [Vector2(0, 0), Vector2(0.125, 0), Vector2(0.125, 0.012), Vector2(0, 0.012)], p, Vector3(90, 0, 0), 8)
	h.pop()


# ---------------------------------------------------------------- tekerlekli araçlar

## Tekerlek: lastik ve jant. sx yanı gösterir.
static func _wheel(k: Kit, p: Vector3, r: float, w: float, sx: float) -> void:
	var rot := Vector3(0, 0, -90.0 * sx)
	k.lathe("rubber", [Vector2(r * 0.9, -w * 0.5), Vector2(r, -w * 0.3), Vector2(r, w * 0.3), Vector2(r * 0.9, w * 0.5), Vector2(r * 0.6, w * 0.5)], p, rot, 12)
	k.lathe("hull", [Vector2(r * 0.6, w * 0.5), Vector2(r * 0.5, w * 0.25), Vector2(r * 0.2, w * 0.25), Vector2(r * 0.16, w * 0.5), Vector2(0, w * 0.5)], p, rot, 10)


## Askeri kamyon: şasi, tekerlekler ve kabin. ln boy, axles dingil z'leri, armored: zırhlı kabin (küçük camlar).
static func _truck(k: Kit, ln: float, axles: Array, armored: bool) -> void:
	var zf := ln * 0.5
	for z in axles:
		for sx in [-1.0, 1.0]:
			_wheel(k, Vector3(1.1 * sx, 0.6, z), 0.6, 0.42, sx)
		k.box("dark", Vector3(2.0, 0.16, 0.16), Vector3(0, 0.6, z))
	k.box("dark", Vector3(1.0, 0.35, ln - 0.3), Vector3(0, 0.95, -0.1))
	k.box("hull", Vector3(2.5, 0.12, ln - 2.2), Vector3(0, 1.2, -1.1))
	# kabin
	Tanks._side(k, "hull", [Vector2(zf, 1.0), Vector2(zf, 1.95), Vector2(zf - 0.4, 2.8), Vector2(zf - 2.0, 2.8), Vector2(zf - 2.0, 1.0)], -1.25, 1.25)
	var gw := 0.75 if armored else 1.05
	for sx in [-1.0, 1.0]:
		k.box("glass", Vector3(gw, 0.55 if armored else 0.7, 0.03), Vector3(0.58 * sx, 2.38, zf - 0.19), Vector3(-25.2, 0, 0))
		k.box("glass", Vector3(0.03, 0.5, 0.8 if armored else 1.1), Vector3(1.26 * sx, 2.35, zf - 1.1))
		k.box("hull2", Vector3(0.03, 0.7, 0.9), Vector3(1.26 * sx, 1.5, zf - 1.1))
		_lamp(k, Vector3(0.9 * sx, 1.25, zf + 0.02))
		k.box("hull", Vector3(0.5, 0.06, 1.5), Vector3(1.1 * sx, 1.32, zf - 1.0))
		k.box("steel", Vector3(0.1, 0.5, 0.06), Vector3(1.32 * sx, 2.5, zf - 0.3))
	k.box("steel", Vector3(2.5, 0.3, 0.16), Vector3(0, 0.85, zf + 0.08))
	k.box("dark", Vector3(1.2, 0.5, 0.04), Vector3(0, 1.5, zf + 0.01))
	Tanks._hatch(k, Vector3(0.5, 2.8, zf - 1.1), 0.28)
	# kabin arkası: yedek lastik ve yakıt deposu
	k.lathe("rubber", [Vector2(0.25, -0.2), Vector2(0.6, -0.2), Vector2(0.6, 0.2), Vector2(0.25, 0.2)], Vector3(0, 2.0, zf - 2.3), Vector3(90, 0, 0), 12)
	for sx in [-1.0, 1.0]:
		Tanks._cyl(k, "hull2", 0.3, 1.0, Vector3(1.0 * sx, 0.95, zf - 3.2), Vector3(90, 0, 0), 8)


## Roket / füze tüp demeti: nx x ny tüp, r yarıçap, ln boy; p arka alt merkez, e yükseliş.
static func _tubes(k: Kit, p: Vector3, nx: int, ny: int, r: float, ln: float, e: float, s: String) -> void:
	k.push(p, Vector3(-e, 0, 0))
	var w := nx * r * 2.2
	var hg := ny * r * 2.2
	k.box("steel", Vector3(w + 0.1, 0.08, ln * 0.9), Vector3(0, -0.04, ln * 0.5))
	for a in [0.2, 0.75]:
		k.box("steel", Vector3(w + 0.12, hg + 0.1, 0.1), Vector3(0, hg * 0.5, ln * a))
	for i in nx:
		for j in ny:
			var c := Vector3((i - (nx - 1) * 0.5) * r * 2.2, r * 1.1 + j * r * 2.2, 0.0)
			k.lathe(s, [Vector2(0, 0), Vector2(r, 0), Vector2(r, ln), Vector2(r * 0.8, ln), Vector2(r * 0.8, ln - 0.04)], c, Vector3(90, 0, 0), 8)
			k.lathe("dark", [Vector2(0, 0), Vector2(r * 0.81, 0), Vector2(r * 0.81, 0.01), Vector2(0, 0.01)], c + Vector3(0, 0, ln - 0.05), Vector3(90, 0, 0), 8)
	k.pop()


## Pantsir-S1: 8x8 kamyon, dönen modülde iki 30 mm top, 12 füze tüpü, üstte arama radarı.
static func _pantsir(h: Kit, t: Kit) -> float:
	_truck(h, 8.6, [-3.4, -2.0, 1.3, 2.9], false)
	h.box("hull", Vector3(2.5, 1.2, 4.6), Vector3(0, 1.86, -1.9))
	Tanks._crate(h, "hull", Vector3(2.4, 0.5, 0.8), Vector3(0, 2.7, -3.8))
	t.loft("hull", [Tanks._plan(2.46, [Vector2(0.6, 1.0), Vector2(0.9, 0.7), Vector2(0.9, -1.1), Vector2(0.6, -1.3)]),
		Tanks._plan(3.5, [Vector2(0.5, 0.8), Vector2(0.8, 0.6), Vector2(0.8, -1.0), Vector2(0.55, -1.15)])])
	t.box("team", Vector3(1.84, 0.12, 2.0), Vector3(0, 3.0, -0.15))
	t.box("hull2", Vector3(0.9, 0.9, 0.2), Vector3(0, 3.0, 0.95), Vector3(-10, 0, 0))
	t.box("steel", Vector3(0.75, 0.75, 0.03), Vector3(0, 3.0, 1.06), Vector3(-10, 0, 0))
	for sx in [-1.0, 1.0]:
		_tubes(t, Vector3(1.25 * sx, 2.75, -1.0), 2, 3, 0.11, 2.9, 25.0, "hull2")
		_autocannon(t, Vector3(0.95 * sx, 2.9, 0.4), 2.6, 0.04, 12.0)
	_radar(t, Vector3(0, 4.2, -0.9), 1.5, 0.6, -8.0)
	return -1.9


## Iron Dome: kamyon üstünde dikilmiş 20 hücreli önleyici füze atıcı.
static func _irondome(h: Kit) -> void:
	_truck(h, 7.4, [-2.8, -1.4, 2.4], false)
	h.box("hull", Vector3(2.5, 0.5, 4.4), Vector3(0, 1.5, -1.4))
	for sx in [-1.0, 1.0]:
		h.box("steel", Vector3(0.12, 1.7, 0.12), Vector3(1.0 * sx, 2.4, -2.3), Vector3(25, 0, 0))
	h.push(Vector3(0, 2.3, -2.6), Vector3(-58, 0, 0))
	h.box("hull", Vector3(2.3, 1.9, 3.2), Vector3(0, 0.6, 1.2))
	h.box("team", Vector3(2.32, 0.16, 2.6), Vector3(0, 1.4, 1.2))
	for i in 5:
		for j in 4:
			var p := Vector3(-0.84 + i * 0.42, -0.06 + j * 0.44, 2.81)
			h.box("dark", Vector3(0.36, 0.38, 0.02), p)
			h.lathe("missile", [Vector2(0, 0), Vector2(0.13, 0), Vector2(0.1, 0.05), Vector2(0, 0.08)], p, Vector3(90, 0, 0), 8)
	h.pop()
	Tanks._crate(h, "hull", Vector3(2.2, 0.8, 1.0), Vector3(0, 2.15, 0.6))
	Tanks._antenna(h, Vector3(-1.0, 2.55, 0.6), 2.2)


## 2S22 Bohdana / ATMOS / SH-15 / CAESAR: kamyon kasasında açık 155 mm obüs, arkada mesnet küreği.
static func _truck_gun(h: Kit) -> void:
	_truck(h, 8.4, [-3.2, -1.8, 2.8], true)
	h.box("hull", Vector3(2.5, 0.6, 3.0), Vector3(0, 1.56, -0.4))
	Tanks._crate(h, "hull", Vector3(1.0, 0.7, 2.6), Vector3(-0.75, 2.2, -0.2))
	Tanks._crate(h, "hull", Vector3(1.0, 0.7, 2.6), Vector3(0.75, 2.2, -0.2))
	h.box("team", Vector3(2.2, 0.03, 1.4), Vector3(0, 2.6, -0.2))
	# top kundağı ve namlu (kabinin üstünden öne uzanır)
	Tanks._cyl(h, "hull2", 0.75, 0.3, Vector3(0, 1.45, -3.0), Vector3.ZERO, 10)
	for sx in [-1.0, 1.0]:
		h.box("hull2", Vector3(0.18, 1.3, 1.1), Vector3(0.5 * sx, 2.2, -3.0))
		h.box("steel", Vector3(0.14, 0.14, 1.9), Vector3(0.7 * sx, 0.75, -4.7), Vector3(20, 0, 0))
	h.box("hull2", Vector3(0.7, 0.6, 1.6), Vector3(0, 2.75, -3.1), Vector3(-14, 0, 0))
	_howitzer(h, Vector3(0, 2.85, -2.6), 7.2, 14.0)
	h.box("steel", Vector3(2.4, 0.5, 0.1), Vector3(0, 0.45, -5.5), Vector3(20, 0, 0))


## M142 HIMARS: zırhlı kabinli 6x6 kamyon, arkada altı hücreli roket kutusu.
static func _himars(h: Kit) -> void:
	_truck(h, 7.0, [-2.6, -1.2, 2.3], true)
	h.box("hull2", Vector3(1.9, 0.5, 3.6), Vector3(0, 1.5, -1.6))
	Tanks._cyl(h, "hull2", 0.9, 0.2, Vector3(0, 1.82, -1.6), Vector3.ZERO, 10)
	h.push(Vector3(0, 1.95, -3.3), Vector3(-12, 0, 0))
	for sx in [-1.0, 1.0]:
		h.box("hull", Vector3(0.14, 1.3, 3.9), Vector3(1.2 * sx, 0.7, 1.95))
	h.box("hull", Vector3(2.3, 1.15, 3.9), Vector3(0, 0.72, 1.95))
	h.box("team", Vector3(2.32, 0.03, 2.6), Vector3(0, 1.31, 1.9))
	for i in 3:
		for j in 2:
			var p := Vector3(-0.72 + i * 0.72, 0.42 + j * 0.58, 3.91)
			h.box("dark", Vector3(0.62, 0.5, 0.02), p)
			h.lathe("steel", [Vector2(0, 0), Vector2(0.2, 0), Vector2(0.2, 0.02), Vector2(0, 0.02)], p, Vector3(90, 0, 0), 10)
	h.pop()


## Tornado-S / PULS / Fajr-5 / A-100 / Pinaka: 8x8 kamyon, arkada kaldırılmış 12 büyük roket tüpü.
static func _mlrs(h: Kit) -> void:
	_truck(h, 9.6, [-3.9, -2.5, 1.6, 3.4], false)
	h.box("hull", Vector3(2.5, 0.9, 1.6), Vector3(0, 1.75, 1.7))
	Tanks._cyl(h, "hull2", 1.0, 0.3, Vector3(0, 1.45, -2.0), Vector3.ZERO, 10)
	for sx in [-1.0, 1.0]:
		h.box("hull2", Vector3(0.2, 1.1, 1.8), Vector3(1.0 * sx, 2.0, -2.6))
		h.box("steel", Vector3(0.3, 0.9, 0.3), Vector3(1.2 * sx, 0.7, -4.5))
	_tubes(h, Vector3(0, 1.95, -4.6), 4, 3, 0.17, 6.6, 16.0, "hull")
	h.push(Vector3(0, 1.95, -4.6), Vector3(-16, 0, 0))
	h.box("team", Vector3(1.6, 0.03, 2.6), Vector3(0, 1.18, 3.2))
	h.pop()


## Tryzub / Iron Beam: kamyon üstünde güç ve soğutma konteyneri, üstünde dönen ışın yönlendirici.
static func _laser(h: Kit) -> void:
	_truck(h, 7.4, [-2.8, -1.4, 2.4], false)
	h.box("hull", Vector3(2.5, 2.0, 4.6), Vector3(0, 2.26, -1.5))
	h.box("team", Vector3(2.52, 0.16, 4.62), Vector3(0, 2.7, -1.5))
	for sx in [-1.0, 1.0]:
		Tanks._grille(h, Vector3(0.65 * sx, 3.28, -2.6), 0.95, 1.4, 0.0, 6)
		h.push(Vector3(1.26 * sx, 2.0, -1.5), Vector3(0, 0, 90))
		Tanks._grille(h, Vector3.ZERO, 0.9, 2.4, 0.0, 8)
		h.pop()
	Tanks._cyl(h, "hull2", 0.55, 0.5, Vector3(0, 3.5, -0.3), Vector3.ZERO, 12)
	h.box("hull2", Vector3(0.9, 0.9, 1.1), Vector3(0, 4.1, -0.3))
	h.lathe("steel", [Vector2(0.36, 0), Vector2(0.38, 0.5), Vector2(0.3, 0.5), Vector2(0.3, 0.42)], Vector3(0, 4.1, 0.25), Vector3(90, 0, 0), 12)
	h.lathe("beam", [Vector2(0, 0), Vector2(0.31, 0), Vector2(0.31, 0.01), Vector2(0, 0.03)], Vector3(0, 4.1, 0.66), Vector3(90, 0, 0), 12)
	Tanks._sight(h, "hull2", Vector3(0.3, 0.3, 0.4), Vector3(0.62, 4.2, -0.1), 0.0)
	_radar(h, Vector3(0, 3.9, -3.3), 1.2, 0.6, -10.0)


## Elektronik harp aracı (Bukovel-AD, Silok, Drone Dome...): kamyon üstünde konteyner, dört yöne bakan
## karıştırıcı panel anteni ve katlanır direk üstünde algılama radarı.
static func _ew(h: Kit) -> void:
	_truck(h, 7.6, [-2.9, -1.5, 2.4], true)
	h.box("hull", Vector3(2.5, 1.8, 4.6), Vector3(0, 2.16, -1.6))
	h.box("team", Vector3(2.52, 0.14, 4.62), Vector3(0, 2.5, -1.6))
	for sx in [-1.0, 1.0]:
		Tanks._grille(h, Vector3(0.7 * sx, 3.08, -0.4), 0.8, 0.9, 0.0, 5)
		h.box("dark", Vector3(0.04, 0.5, 0.9), Vector3(1.27 * sx, 2.0, -2.4))
	# direk ve radar
	Tanks._cyl(h, "steel", 0.12, 2.6, Vector3(0, 4.35, -2.6), Vector3.ZERO, 8)
	_radar(h, Vector3(0, 5.7, -2.6), 1.0, 0.5, 0.0)
	# dört yöne karıştırıcı panelleri
	for a in [0.0, 90.0, 180.0, 270.0]:
		h.push(Vector3(0, 4.7, -2.6), Vector3(0, a, 0))
		h.box("hull2", Vector3(0.7, 0.9, 0.08), Vector3(0, 0, 0.42), Vector3(-12, 0, 0))
		h.box("dark", Vector3(0.6, 0.8, 0.02), Vector3(0, 0, 0.47), Vector3(-12, 0, 0))
		h.pop()
	# whip antenler
	for sx in [-1.0, 1.0]:
		Tanks._cyl(h, "dark", 0.03, 2.2, Vector3(1.0 * sx, 4.1, -3.6), Vector3.ZERO, 6)
