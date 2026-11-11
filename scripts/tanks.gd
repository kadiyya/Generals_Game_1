class_name Tanks
extends RefCounted
## Tank modelleri. Ölçüler gerçek araçlardan (metre) alınmıştır, S ile oyundaki boyuta küçültülür.
## Ön taraf +Z. Gövde (h) ve kule (t) ayrı kurulur; kule parçaları kule yatağının merkezine göre yazılır
## (x ve y mutlak, z yatağa göre), design() yatağın z konumunu döndürür.
## Not: bu dosya yalnızca Kit çağrıları ve düz hesap içerir; geliştirme önizleme aracı da aynı kodu okur.

const S := 0.56


## Renk yuvaları: gövde boyası, ek zırh, çelik, lastik, palet, takım rengi örtüsü, branda, cam.
static func slots(k: Kit, bc: Color, tc: Color) -> void:
	var g := (bc.r + bc.g + bc.b) / 3.0
	var body := bc.lerp(Color(g, g, g), 0.18)
	k.slot("hull", "armor", body, 0.6)
	k.slot("hull2", "armor", body.darkened(0.14), 0.6)
	k.slot("steel", "steel", Color(0.27, 0.27, 0.26), 0.35)
	k.slot("dark", "steel", Color(0.08, 0.08, 0.08), 0.1)
	k.slot("rubber", "steel", Color(0.14, 0.14, 0.13), 0.75)
	k.slot("track", "track", Color(0.36, 0.34, 0.31), 0.85)
	k.slot("team", "fabric", tc.darkened(0.08), 0.08)
	k.slot("canvas", "fabric", Color(0.44, 0.4, 0.3), 0.3)
	k.slot("canvas2", "fabric", Color(0.3, 0.33, 0.24), 0.3)
	k.slot("wood", "steel", Color(0.46, 0.34, 0.22), 0.3)
	k.slot("glass", "optic", Color(0.1, 0.17, 0.22), 0.0)
	k.slot("lamp", "optic", Color(0.78, 0.78, 0.7), 0.0)


static func design(id: String, h: Kit, t: Kit) -> float:
	h.push(Vector3.ZERO, Vector3.ZERO, S)
	t.push(Vector3.ZERO, Vector3.ZERO, S)
	var tz := 0.0
	if id == "tank_ru2":
		tz = _t90(h, t)
	elif id == "tank_leo":
		tz = _leo(h, t)
	elif id == "tank_merkava":
		tz = _merkava(h, t)
	else:
		tz = _t72(h, t)
	return tz * S


# ---------------------------------------------------------------- T-72B3 / T-64BV

static func _t72(h: Kit, t: Kit) -> float:
	_t72_hull(h, false)
	# yuvarlak döküm kule
	var shell := [_egg(1.42, 1.1, 1.18, 1.05), _egg(1.7, 1.12, 1.15, 1.08), _egg(1.92, 1.02, 1.02, 1.0),
		_egg(2.07, 0.82, 0.8, 0.86), _egg(2.16, 0.55, 0.5, 0.66)]
	t.loft("hull", shell, true)
	t.loft("team", [_egg(1.6, 1.126, 1.172, 1.082), _egg(1.7, 1.134, 1.162, 1.094)], true)
	# kalkan brandası ve top
	t.lathe("canvas2", [Vector2(0, 0), Vector2(0.3, 0), Vector2(0.27, 0.16), Vector2(0.17, 0.36), Vector2(0, 0.36)],
		Vector3(0, 1.8, 0.98), Vector3(90, 0, 0), 10)
	_gun125(t, Vector3(0, 1.8, 1.3), 4.5)
	# Kontakt-5 kaş zırhı ve tavan tuğlaları
	for sx in [-1.0, 1.0]:
		t.box("hull2", Vector3(0.82, 0.4, 0.34), Vector3(0.62 * sx, 1.86, 0.88), Vector3(-10, 32 * sx, 0))
		t.box("hull2", Vector3(0.55, 0.07, 0.36), Vector3(0.5 * sx, 2.1, 0.58), Vector3(-8, 22 * sx, 0))
		_smoke(t, Vector3(0.92 * sx, 1.98, 0.38), 48 * sx, 4)
	# komutan kubbesi ve makineli tüfek, nişancı kapağı ve nişangâhı
	t.lathe("hull2", [Vector2(0.4, 0), Vector2(0.4, 0.12), Vector2(0.36, 0.16), Vector2(0, 0.16)],
		Vector3(0.45, 2.1, -0.15), Vector3.ZERO, 12)
	_hatch(t, Vector3(0.45, 2.26, -0.18), 0.27)
	_sight(t, "steel", Vector3(0.2, 0.14, 0.16), Vector3(0.45, 2.33, 0.2), 0.0)
	t.box("steel", Vector3(0.06, 0.2, 0.06), Vector3(0.45, 2.38, -0.05))
	_mg(t, Vector3(0.45, 2.5, 0.05), 0.0, 0.95)
	_hatch(t, Vector3(-0.42, 2.12, -0.3), 0.27)
	_sight(t, "hull2", Vector3(0.36, 0.3, 0.46), Vector3(-0.5, 2.22, 0.45), 0.0)
	# arkada şnorkel borusu ve kutu, antenler
	_cyl(t, "hull2", 0.1, 1.3, Vector3(-0.2, 1.78, -1.12), Vector3(0, 0, 90), 8)
	_crate(t, "hull", Vector3(0.62, 0.32, 0.3), Vector3(0.6, 1.8, -0.98))
	_antenna(t, Vector3(-0.72, 2.02, -0.55), 2.1)
	_antenna(t, Vector3(0.78, 1.98, -0.6), 1.6)
	return 0.15


## T-72 / T-90 gövdesi: 6 büyük yol tekerleği, lastik etek, arkada varil.
static func _t72_hull(k: Kit, t90: bool) -> void:
	var wz := [-2.25, -1.38, -0.5, 0.38, 1.26, 2.14]
	for sx in [-1.0, 1.0]:
		_running(k, sx, 1.43, 0.58, wz, 0.375, Vector3(3.05, 0.55, 0.27), Vector3(-3.1, 0.58, 0.31), false, [-1.5, 0.0, 1.5], 0.86)
	_side(k, "hull", [Vector2(3.42, 0.95), Vector2(2.2, 1.42), Vector2(-1.0, 1.42), Vector2(-3.42, 1.32),
		Vector2(-3.32, 0.45), Vector2(2.95, 0.45)], -1.12, 1.12)
	# glasi reaktif zırhı
	_era(k, "hull2", Vector2(3.36, 0.98), Vector2(2.26, 1.4), -1.06, 1.06, 2, 6 if t90 else 5, 0.12)
	for sx in [-1.0, 1.0]:
		# çamurluk, eteğin lastik kısmı ve ön tarafta reaktif zırhlı etek
		k.box("hull", Vector3(0.66, 0.04, 6.0), Vector3(1.44 * sx, 1.03, -0.25))
		k.box("hull", Vector3(0.66, 0.04, 0.6), Vector3(1.44 * sx, 0.97, 3.03), Vector3(12, 0, 0))
		k.box("rubber", Vector3(0.03, 0.3, 4.5), Vector3(1.75 * sx, 0.88, -0.75))
		for i in 3:
			k.box("hull2", Vector3(0.08, 0.42, 0.46), Vector3(1.76 * sx, 0.84, 1.75 + i * 0.49))
		# farlar ve çeki kancaları
		k.box("steel", Vector3(0.16, 0.14, 0.12), Vector3(0.98 * sx, 1.36, 2.36))
		_cyl(k, "lamp", 0.055, 0.03, Vector3(0.98 * sx, 1.36, 2.43), Vector3(90, 0, 0), 8)
		k.box("steel", Vector3(0.12, 0.1, 0.14), Vector3(0.72 * sx, 0.74, 3.22))
		# motor ızgaraları
		_grille(k, Vector3(0.5 * sx, 1.39, -2.15), 0.84, 1.4, -2.4, 7)
	_grille(k, Vector3(0, 1.355, -3.15), 2.0, 0.3, -2.4, 3)
	_panel(k, Vector3(0, 1.432, -2.05), 1.45, 1.1, -2.4)
	# sürücü kapağı
	k.box("hull2", Vector3(0.52, 0.05, 0.46), Vector3(0, 1.445, 1.92))
	_sight(k, "steel", Vector3(0.2, 0.07, 0.09), Vector3(0, 1.48, 2.16), 0.0)
	# sağ çamurlukta yakıt depoları, solda kutular ve egzoz
	for i in 4:
		_crate(k, "hull", Vector3(0.5, 0.34, 0.92), Vector3(1.42, 1.22, 1.7 - i * 1.05))
	_crate(k, "hull", Vector3(0.5, 0.34, 1.05), Vector3(-1.42, 1.22, 1.65))
	_crate(k, "hull", Vector3(0.5, 0.34, 0.85), Vector3(-1.42, 1.22, 0.55))
	_crate(k, "hull", Vector3(0.5, 0.34, 0.85), Vector3(-1.42, 1.22, -2.3))
	_grille(k, Vector3(-1.42, 1.06, -0.8), 0.4, 0.42, 0.0, 4)
	# arkada iki yakıt varili ve (T-72'de) kurtarma kütüğü
	for sx in [-1.0, 1.0]:
		_drum(k, Vector3(0.6 * sx, 1.0, -3.7))
	if not t90:
		_cyl(k, "wood", 0.13, 2.9, Vector3(0, 1.47, -3.57), Vector3(0, 0, 90), 8)


# ---------------------------------------------------------------- T-90M / Karrar / Al-Khalid / T-90S

static func _t90(h: Kit, t: Kit) -> float:
	_t72_hull(h, true)
	# kaynaklı köşeli kule
	t.loft("hull", [
		_plan(1.42, [Vector2(0.45, 1.05), Vector2(1.12, 0.78), Vector2(1.18, -0.72), Vector2(0.82, -1.12)]),
		_plan(1.98, [Vector2(0.42, 0.98), Vector2(1.08, 0.72), Vector2(1.14, -0.7), Vector2(0.8, -1.08)]),
		_plan(2.12, [Vector2(0.36, 0.84), Vector2(0.95, 0.62), Vector2(1.02, -0.64), Vector2(0.7, -0.98)]),
	])
	for sx in [-1.0, 1.0]:
		# ön Relikt modülleri: ok ucu biçimli
		t.loft("hull2", [
			[Vector3(0.3 * sx, 1.5, 1.72), Vector3(1.2 * sx, 1.5, 1.0), Vector3(1.2 * sx, 1.5, 0.62), Vector3(0.3 * sx, 1.5, 0.95)],
			[Vector3(0.3 * sx, 2.14, 1.48), Vector3(1.16 * sx, 2.14, 0.88), Vector3(1.16 * sx, 2.14, 0.58), Vector3(0.3 * sx, 2.14, 0.88)],
		])
		for i in 3:
			t.box("hull2", Vector3(0.1, 0.42, 0.42), Vector3(1.22 * sx, 1.72, 0.36 - i * 0.46))
		_smoke(t, Vector3(0.86 * sx, 2.19, 0.8), 34 * sx, 3)
	t.box("hull2", Vector3(0.58, 0.52, 0.55), Vector3(0, 1.8, 1.25))
	_gun125(t, Vector3(0, 1.8, 1.5), 4.4)
	# arka sepet ve kafes zırh
	t.box("hull", Vector3(1.9, 0.52, 0.74), Vector3(0, 1.82, -1.42))
	t.box("team", Vector3(1.92, 0.1, 0.76), Vector3(0, 1.9, -1.42))
	for i in 13:
		t.box("steel", Vector3(0.03, 0.62, 0.03), Vector3(-1.05 + i * 0.175, 1.8, -1.96))
	for sx in [-1.0, 1.0]:
		for i in 5:
			t.box("steel", Vector3(0.03, 0.62, 0.03), Vector3(1.08 * sx, 1.8, -1.06 - i * 0.2))
	for y in [1.55, 2.08]:
		t.box("steel", Vector3(2.19, 0.03, 0.03), Vector3(0, y, -1.96))
		for sx in [-1.0, 1.0]:
			t.box("steel", Vector3(0.03, 0.03, 0.95), Vector3(1.08 * sx, y, -1.48))
	# tavan: komutan panoramik nişangâhı, nişancı nişangâhı, kapaklar, uzaktan kumandalı tüfek
	_cyl(t, "hull2", 0.15, 0.32, Vector3(0.5, 2.26, 0.22), Vector3.ZERO, 10)
	_sight(t, "hull2", Vector3(0.34, 0.28, 0.36), Vector3(0.5, 2.5, 0.22), 0.0)
	_sight(t, "hull2", Vector3(0.36, 0.28, 0.5), Vector3(-0.5, 2.25, 0.45), 0.0)
	_hatch(t, Vector3(0.48, 2.12, -0.42), 0.27)
	_hatch(t, Vector3(-0.48, 2.12, -0.38), 0.27)
	t.box("hull2", Vector3(0.3, 0.16, 0.36), Vector3(0.48, 2.28, -0.14))
	_mg(t, Vector3(0.48, 2.42, -0.1), 0.0, 0.95)
	_cyl(t, "steel", 0.02, 0.6, Vector3(0.0, 2.42, -0.85), Vector3.ZERO, 4)
	_antenna(t, Vector3(-0.75, 2.12, -0.8), 2.1)
	_antenna(t, Vector3(0.75, 2.12, -0.85), 1.6)
	return 0.15


# ---------------------------------------------------------------- Leopard 2A6 / Arjun / VT-4

static func _leo(h: Kit, t: Kit) -> float:
	var wz := [-2.46, -1.64, -0.82, 0.0, 0.82, 1.64, 2.46]
	for sx in [-1.0, 1.0]:
		_running(h, sx, 1.5, 0.635, wz, 0.35, Vector3(3.38, 0.6, 0.3), Vector3(-3.42, 0.64, 0.33), false, [-2.05, -0.41, 1.23], 0.92)
	# geniş üst gövde (paletlerin üstüne taşar) ve paletler arası alt gövde
	_side(h, "hull", [Vector2(3.85, 1.02), Vector2(2.75, 1.5), Vector2(-3.55, 1.52), Vector2(-3.85, 1.45), Vector2(-3.85, 1.07)], -1.86, 1.86)
	_side(h, "hull", [Vector2(3.85, 1.02), Vector2(3.45, 0.5), Vector2(-3.7, 0.5), Vector2(-3.85, 1.07)], -1.15, 1.15)
	for sx in [-1.0, 1.0]:
		# önde kalın zırhlı etekler, arkada ince etekler
		for i in 3:
			h.box("hull", Vector3(0.1, 0.62, 0.78), Vector3(1.91 * sx, 0.8, 3.15 - i * 0.8))
		for i in 5:
			h.box("hull", Vector3(0.04, 0.52, 0.9), Vector3(1.88 * sx, 0.85, 0.73 - i * 0.92))
		h.box("steel", Vector3(0.18, 0.16, 0.14), Vector3(1.5 * sx, 1.27, 3.42), Vector3(-26, 0, 0))
		_cyl(h, "lamp", 0.06, 0.03, Vector3(1.5 * sx, 1.25, 3.5), Vector3(64, 0, 0), 8)
		_cyl(h, "steel", 0.03, 3.2, Vector3(1.74 * sx, 1.55, -1.2), Vector3(90, 0, 0), 5)
		_grille(h, Vector3(0.78 * sx, 1.535, -2.95), 1.15, 1.15, 0.0, 6)
		h.box("dark", Vector3(0.9, 0.3, 0.03), Vector3(1.05 * sx, 1.25, -3.86))
		h.box("lamp", Vector3(0.12, 0.08, 0.02), Vector3(1.6 * sx, 1.38, -3.86))
	_grille(h, Vector3(0, 1.53, -3.48), 3.2, 0.3, 0.0, 3)
	_panel(h, Vector3(0, 1.575, -3.1), 1.7, 0.8, 0.0)
	# sürücü kapağı ve periskopları
	h.box("hull2", Vector3(0.62, 0.05, 0.55), Vector3(-0.62, 1.53, 2.25))
	for i in 3:
		h.box("glass", Vector3(0.14, 0.06, 0.06), Vector3(-0.8 + i * 0.18, 1.55, 2.58))
	# kule
	var tb := [Vector2(0.4, 1.35), Vector2(1.6, 1.35), Vector2(1.62, -0.92), Vector2(1.32, -1.25)]
	t.loft("hull", [_plan(1.52, tb), _plan(2.3, tb),
		_plan(2.42, [Vector2(0.4, 1.3), Vector2(1.53, 1.3), Vector2(1.55, -0.88), Vector2(1.26, -1.2)])])
	for sx in [-1.0, 1.0]:
		# kama zırh
		t.loft("hull2", [
			[Vector3(0.4 * sx, 1.62, 2.45), Vector3(1.6 * sx, 1.62, 1.35), Vector3(0.4 * sx, 1.62, 1.35)],
			[Vector3(0.4 * sx, 1.98, 2.45), Vector3(1.6 * sx, 2.36, 1.35), Vector3(0.4 * sx, 2.36, 1.35)],
		])
		t.box("team", Vector3(0.012, 0.11, 2.25), Vector3(1.63 * sx, 2.08, 0.22))
		_smoke(t, Vector3(1.66 * sx, 2.22, -0.62), 70 * sx, 4)
		_crate(t, "hull", Vector3(0.26, 0.42, 1.0), Vector3(1.4 * sx, 2.0, -1.85))
		_antenna(t, Vector3(1.0 * sx, 2.34, -2.25), 2.0)
	t.box("hull2", Vector3(0.8, 0.6, 0.55), Vector3(0, 1.95, 1.55))
	_gun120(t, Vector3(0, 1.95, 1.8), 5.4)
	# arka sepet ve içindeki yükler
	t.box("hull", Vector3(2.55, 0.68, 1.2), Vector3(0, 2.0, -1.85))
	t.box("team", Vector3(2.57, 0.11, 1.22), Vector3(0, 2.08, -1.85))
	t.box("steel", Vector3(2.5, 0.03, 0.38), Vector3(0, 1.75, -2.64))
	t.box("steel", Vector3(2.5, 0.03, 0.03), Vector3(0, 2.14, -2.82))
	for x in [-1.24, -0.42, 0.42, 1.24]:
		t.box("steel", Vector3(0.03, 0.4, 0.03), Vector3(x, 1.95, -2.82))
	_bag(t, "canvas", Vector3(0.34, 0.32, 0.72), Vector3(-0.8, 1.93, -2.62), 90.0)
	_bag(t, "canvas2", Vector3(0.32, 0.36, 0.62), Vector3(0.05, 1.95, -2.63), 90.0)
	_bag(t, "canvas", Vector3(0.3, 0.3, 0.6), Vector3(0.8, 1.92, -2.62), 90.0)
	# tavan: nişancı EMES nişangâhı, komutan PERI periskopu, kapaklar, yükleyici tüfeği
	_sight(t, "hull2", Vector3(0.62, 0.28, 0.78), Vector3(0.85, 2.52, 0.72), 0.0)
	_cyl(t, "hull2", 0.17, 0.25, Vector3(0.22, 2.52, -0.32), Vector3.ZERO, 10)
	_sight(t, "hull2", Vector3(0.32, 0.28, 0.38), Vector3(0.22, 2.76, -0.32), 0.0)
	_hatch(t, Vector3(0.85, 2.42, -0.5), 0.32)
	_hatch(t, Vector3(-0.75, 2.42, -0.42), 0.32)
	t.box("steel", Vector3(0.05, 0.22, 0.05), Vector3(-0.75, 2.58, -0.12))
	_mg(t, Vector3(-0.75, 2.72, -0.05), 0.0, 0.7)
	return -0.1


# ---------------------------------------------------------------- Merkava Mk 4

static func _merkava(h: Kit, t: Kit) -> float:
	var wz := [-2.4, -1.46, -0.52, 0.42, 1.36, 2.3]
	for sx in [-1.0, 1.0]:
		_running(h, sx, 1.47, 0.64, wz, 0.395, Vector3(3.3, 0.66, 0.33), Vector3(-3.3, 0.62, 0.3), true, [-1.9, 0.0, 1.9], 0.98)
	# motor önde: uzun eğik glasi, kule arkada
	_side(h, "hull", [Vector2(3.8, 1.0), Vector2(0.6, 1.66), Vector2(-3.45, 1.66), Vector2(-3.8, 1.5), Vector2(-3.8, 1.07)], -1.86, 1.86)
	_side(h, "hull", [Vector2(3.8, 1.0), Vector2(3.3, 0.5), Vector2(-3.6, 0.5), Vector2(-3.8, 1.07)], -1.15, 1.15)
	for sx in [-1.0, 1.0]:
		for i in 4:
			h.box("hull", Vector3(0.12, 0.6, 0.9), Vector3(1.92 * sx, 0.8, 3.15 - i * 0.92))
		for i in 4:
			h.box("hull", Vector3(0.05, 0.5, 0.9), Vector3(1.9 * sx, 0.84, -0.6 - i * 0.92))
		h.box("steel", Vector3(0.2, 0.14, 0.14), Vector3(1.55 * sx, 1.1, 3.62), Vector3(-12, 0, 0))
		_cyl(h, "lamp", 0.06, 0.03, Vector3(1.55 * sx, 1.1, 3.7), Vector3(78, 0, 0), 8)
		h.box("steel", Vector3(0.14, 0.12, 0.14), Vector3(0.8 * sx, 0.78, 3.65))
		# arka köşelerde yük sepetleri
		h.box("steel", Vector3(0.95, 0.03, 0.55), Vector3(1.25 * sx, 1.7, -3.55))
		h.box("steel", Vector3(0.95, 0.03, 0.03), Vector3(1.25 * sx, 2.02, -3.82))
		_bag(h, "canvas2", Vector3(0.8, 0.34, 0.45), Vector3(1.25 * sx, 1.88, -3.55), 0.0)
	# glaside motor ızgarası (sağ) ve sürücü kapağı (sol)
	_grille(h, Vector3(0.62, 1.39, 2.0), 1.0, 1.4, 11.65, 7)
	h.box("hull2", Vector3(0.55, 0.06, 0.6), Vector3(-0.65, 1.55, 1.2), Vector3(11.65, 0, 0))
	for i in 3:
		h.box("glass", Vector3(0.13, 0.06, 0.05), Vector3(-0.83 + i * 0.18, 1.53, 1.58), Vector3(11.65, 0, 0))
	h.box("hull2", Vector3(1.1, 0.7, 0.04), Vector3(0, 1.0, -3.81))
	# kule: alt gövde, üstte arkaya ve yanlara taşan uzun kama
	t.loft("hull2", [_plan(1.66, [Vector2(0.45, 1.5), Vector2(1.2, 0.8), Vector2(1.25, -1.0), Vector2(0.9, -1.4)]),
		_plan(1.96, [Vector2(0.45, 1.5), Vector2(1.2, 0.8), Vector2(1.25, -1.0), Vector2(0.9, -1.4)])])
	t.loft("hull", [
		_plan(1.92, [Vector2(0.38, 2.6), Vector2(1.68, 0.45), Vector2(1.74, -1.55), Vector2(1.46, -2.3)]),
		_plan(2.38, [Vector2(0.36, 1.35), Vector2(1.56, 0.25), Vector2(1.62, -1.5), Vector2(1.38, -2.25)]),
		_plan(2.5, [Vector2(0.3, 1.0), Vector2(1.45, 0.15), Vector2(1.52, -1.45), Vector2(1.3, -2.15)]),
	])
	t.box("hull2", Vector3(0.6, 0.32, 0.4), Vector3(0, 2.12, 2.02))
	_gun120(t, Vector3(0, 2.12, 2.15), 4.6)
	# kule arkasında asılı top-zincir perdesi
	for i in 15:
		_chain(t, Vector3(-1.3 + i * 0.186, 1.9, -2.24))
	for sx in [-1.0, 1.0]:
		for i in 7:
			_chain(t, Vector3(1.66 * sx, 1.9, -1.9 + i * 0.3))
		# yanlarda takım şeridi, Trophy radar panelleri ve atıcıları, sis atarlar
		t.box("team", Vector3(0.012, 0.12, 1.9), Vector3(1.7 * sx, 2.15, -0.6), Vector3(0, 0, 14.6 * sx))
		t.box("hull2", Vector3(0.07, 0.42, 0.52), Vector3(1.66 * sx, 2.18, 0.45), Vector3(0, 24 * sx, 14 * sx))
		t.box("hull2", Vector3(0.07, 0.42, 0.52), Vector3(1.6 * sx, 2.18, -1.85), Vector3(0, -24 * sx, 14 * sx))
		_cyl(t, "steel", 0.11, 0.16, Vector3(1.3 * sx, 2.58, -0.05), Vector3.ZERO, 8)
		_smoke(t, Vector3(1.32 * sx, 2.55, 0.42), 40 * sx, 3)
		_antenna(t, Vector3(1.1 * sx, 2.5, -1.95), 2.0)
	# tavan: kapaklar, komutan kubbesi ve nişangâhlar, havan, tüfek, tanıma örtüsü, yük sepeti
	t.lathe("hull2", [Vector2(0.44, 0), Vector2(0.44, 0.14), Vector2(0.4, 0.18), Vector2(0, 0.18)],
		Vector3(0.65, 2.48, -0.75), Vector3.ZERO, 12)
	_hatch(t, Vector3(0.65, 2.66, -0.78), 0.3)
	_sight(t, "hull2", Vector3(0.3, 0.32, 0.34), Vector3(0.85, 2.82, -0.25), 0.0)
	_sight(t, "hull2", Vector3(0.46, 0.24, 0.56), Vector3(0.78, 2.6, 0.5), 0.0)
	_hatch(t, Vector3(-0.7, 2.5, -0.9), 0.3)
	t.lathe("steel", [Vector2(0, 0), Vector2(0.065, 0), Vector2(0.065, 0.9), Vector2(0.05, 0.9), Vector2(0, 0.88)],
		Vector3(-0.78, 2.55, 0.05), Vector3(62, 0, 0), 8)
	_mg(t, Vector3(0.65, 2.85, -0.55), 0.0, 0.9)
	_panel(t, Vector3(-0.1, 2.515, -1.55), 1.5, 0.85, 0.0)
	t.box("steel", Vector3(2.4, 0.03, 0.03), Vector3(0, 2.72, -2.1))
	for x in [-1.15, 0.0, 1.15]:
		t.box("steel", Vector3(0.03, 0.22, 0.03), Vector3(x, 2.61, -2.1))
	_bag(t, "canvas", Vector3(0.36, 0.3, 0.8), Vector3(-0.6, 2.64, -1.95), 90.0)
	_bag(t, "canvas2", Vector3(0.34, 0.28, 0.7), Vector3(0.45, 2.63, -1.95), 90.0)
	return -0.95


# ---------------------------------------------------------------- ortak parçalar

## Bir yanın yürüyen aksamı. sx: +1 sağ, -1 sol. x: palet orta çizgisi, tw: palet genişliği.
## wz: yol tekerleklerinin z'leri, wr: yarıçapları. front / rear: ön ve arka dişli (z, y, yarıçap);
## front_drive ise öndeki çeker dişlidir (dişli çark), değilse arkadaki. rr / rry: dönüş makaraları.
static func _running(k: Kit, sx: float, x: float, tw: float, wz: Array, wr: float, front: Vector3, rear: Vector3,
		front_drive: bool, rr: Array, rry: float) -> void:
	var th := 0.08
	var xc := x * sx
	# palet bandı: bütün tekerleklerin çevresinden geçen dışbükey zarf
	var circ: Array = []
	for z in wz:
		circ.append(Vector3(z, wr + th, wr))
	circ.append(front)
	circ.append(rear)
	for z in rr:
		circ.append(Vector3(z, rry, 0.09))
	var pts: Array = []
	for c in circ:
		for i in 20:
			var a := TAU * i / 20.0
			pts.append(Vector2(c.x + cos(a) * (c.z + th * 0.5), c.y + sin(a) * (c.z + th * 0.5)))
	k.belt("track", _hull2(pts), xc, tw, th, 0.15)
	var rot := Vector3(0, 0, -90.0 * sx)
	var h0 := -tw * 0.42
	var h1 := tw * 0.42
	# yol tekerlekleri: lastik bandaj, boyalı jant, göbek
	for z in wz:
		var p := Vector3(xc, wr + th, z)
		k.lathe("rubber", [Vector2(wr, h0), Vector2(wr, h1 - 0.03), Vector2(wr * 0.84, h1)], p, rot, 11)
		k.lathe("hull", [Vector2(wr * 0.84, h1), Vector2(wr * 0.76, h1 + 0.015), Vector2(wr * 0.6, h1 - 0.03),
			Vector2(wr * 0.3, h1 - 0.03), Vector2(wr * 0.24, h1 + 0.05), Vector2(0, h1 + 0.06)], p, rot, 11)
	# avare ve çeker dişli
	for c in [front, rear]:
		var p := Vector3(xc, c.y, c.x)
		var r: float = c.z
		k.lathe("steel", [Vector2(r, h0), Vector2(r, h1 - 0.02), Vector2(r * 0.78, h1)], p, rot, 12)
		k.lathe("hull", [Vector2(r * 0.78, h1), Vector2(r * 0.55, h1 - 0.04), Vector2(r * 0.3, h1 - 0.04),
			Vector2(r * 0.22, h1 + 0.06), Vector2(0, h1 + 0.06)], p, rot, 12)
		if (c == front) == front_drive:
			for i in 11:
				k.push(p, Vector3(360.0 * i / 11.0, 0, 0))
				k.box("steel", Vector3(0.05, 0.1, 0.08), Vector3(sx * (h1 + 0.01), r * 0.82, 0))
				k.pop()
	for z in rr:
		k.lathe("rubber", [Vector2(0.09, -tw * 0.25), Vector2(0.09, tw * 0.25), Vector2(0, tw * 0.25)], Vector3(xc, rry, z), rot, 8)


## Noktaların dışbükey zarfı: (z, y) düzleminde saat tersi yön, en alttaki noktadan başlar.
static func _hull2(pts: Array) -> Array:
	var start := 0
	for i in pts.size():
		var p: Vector2 = pts[i]
		var b: Vector2 = pts[start]
		if p.y < b.y - 1e-6 or (absf(p.y - b.y) <= 1e-6 and p.x < b.x):
			start = i
	var out: Array = []
	var cur := start
	for _guard in pts.size():
		out.append(pts[cur])
		var nxt := (cur + 1) % pts.size()
		var o: Vector2 = pts[cur]
		for i in pts.size():
			var d1: Vector2 = pts[nxt] - o
			var d2: Vector2 = pts[i] - o
			var cr := d1.x * d2.y - d1.y * d2.x
			if cr < -1e-9 or (absf(cr) <= 1e-9 and d2.length_squared() > d1.length_squared()):
				nxt = i
		cur = nxt
		if cur == start:
			break
	return out


## Yan kesiti (z, y) x0..x1 arasında enine uzatır.
static func _side(k: Kit, s: String, prof: Array, x0: float, x1: float) -> void:
	var a: Array = []
	var b: Array = []
	for p in prof:
		a.append(Vector3(x0, p.y, p.x))
		b.append(Vector3(x1, p.y, p.x))
	k.loft(s, [a, b])


## Üstten görünüşün sağ yarısı (x, z), önden arkaya sıralı; y yüksekliğinde simetrik halka döndürür.
static func _plan(y: float, half: Array) -> Array:
	var r: Array = []
	for p in half:
		r.append(Vector3(p.x, y, p.y))
	for i in range(half.size() - 1, -1, -1):
		var q: Vector2 = half[i]
		r.append(Vector3(-q.x, y, q.y))
	return r


## Döküm kule kesiti: y yüksekliğinde, yanlara rx, öne rf, arkaya rr uzanan yumurta biçimli halka.
static func _egg(y: float, rx: float, rf: float, rr: float) -> Array:
	var r: Array = []
	for i in 18:
		var a := TAU * i / 18.0
		var c := cos(a)
		r.append(Vector3(rx * sin(a), y, (rf if c > 0.0 else rr) * c))
	return r


static func _cyl(k: Kit, s: String, r: float, l: float, pos: Vector3, rot: Vector3, sides: int) -> void:
	k.lathe(s, [Vector2(0, -l * 0.5), Vector2(r, -l * 0.5), Vector2(r, l * 0.5), Vector2(0, l * 0.5)], pos, rot, sides)


## Eğik bir yüzey (yan görünüşte p0 alt-ön, p1 üst-arka) üstünde satır x sütun reaktif zırh tuğlası.
static func _era(k: Kit, s: String, p0: Vector2, p1: Vector2, x0: float, x1: float, rows: int, cols: int, th: float) -> void:
	var d := (p0 - p1).normalized()
	var nz := -d.y
	var ny := d.x
	var ang := rad_to_deg(atan2(-d.y, d.x))
	var ln := p0.distance_to(p1)
	for i in rows:
		for j in cols:
			var c := p1.lerp(p0, (i + 0.5) / rows)
			var x := lerpf(x0, x1, (j + 0.5) / cols)
			k.box(s, Vector3((x1 - x0) / cols * 0.93, th, ln / rows * 0.92), Vector3(x, c.y + ny * th * 0.5, c.x + nz * th * 0.5), Vector3(ang, 0, 0))


## 125 mm top: ısı kılıfı bölümleri ve kelepçeleri, ortada duman tahliye silindiri.
static func _gun125(k: Kit, p: Vector3, l: float) -> void:
	k.lathe("hull2", [Vector2(0, 0), Vector2(0.13, 0), Vector2(0.13, l * 0.2), Vector2(0.142, l * 0.205), Vector2(0.142, l * 0.22),
		Vector2(0.125, l * 0.225), Vector2(0.125, l * 0.43), Vector2(0.135, l * 0.435), Vector2(0.135, l * 0.45), Vector2(0.12, l * 0.455),
		Vector2(0.12, l * 0.55), Vector2(0.17, l * 0.585), Vector2(0.17, l * 0.7), Vector2(0.115, l * 0.73), Vector2(0.11, l * 0.985),
		Vector2(0.118, l), Vector2(0.06, l), Vector2(0.06, l - 0.05), Vector2(0, l - 0.05)], p, Vector3(90, 0, 0), 10)


## 120 mm uzun namlu (L55 tipi): ısı kılıfı, duman tahliye silindiri, ağızda referans algılayıcısı.
static func _gun120(k: Kit, p: Vector3, l: float) -> void:
	k.lathe("hull2", [Vector2(0, 0), Vector2(0.14, 0), Vector2(0.14, l * 0.06), Vector2(0.125, l * 0.065), Vector2(0.125, l * 0.24),
		Vector2(0.135, l * 0.245), Vector2(0.135, l * 0.26), Vector2(0.12, l * 0.265), Vector2(0.12, l * 0.4), Vector2(0.18, l * 0.43),
		Vector2(0.18, l * 0.55), Vector2(0.12, l * 0.58), Vector2(0.12, l * 0.75), Vector2(0.128, l * 0.755), Vector2(0.128, l * 0.77),
		Vector2(0.11, l * 0.775), Vector2(0.105, l), Vector2(0.055, l), Vector2(0.055, l - 0.04), Vector2(0, l - 0.04)], p, Vector3(90, 0, 0), 10)
	k.box("steel", Vector3(0.08, 0.07, 0.14), p + Vector3(0, 0.13, l - 0.25))


## Sis bombası atar: n tüp yan yana, öne ve yukarı bakar. yaw derece.
static func _smoke(k: Kit, p: Vector3, yaw: float, n: int) -> void:
	k.push(p, Vector3(0, yaw, 0))
	for i in n:
		var x := (i - (n - 1) * 0.5) * 0.11
		k.lathe("steel", [Vector2(0.045, 0), Vector2(0.045, 0.3), Vector2(0.03, 0.3), Vector2(0, 0.26)],
			Vector3(x, 0, 0), Vector3(65, 0, 0), 6)
	k.box("steel", Vector3(n * 0.11 + 0.04, 0.05, 0.12), Vector3(0, -0.03, 0.02))
	k.pop()


## Makineli tüfek: gövde, mermi kutusu, namlu. p gövde merkezi, ön +z.
static func _mg(k: Kit, p: Vector3, yaw: float, l: float) -> void:
	k.push(p, Vector3(0, yaw, 0))
	k.box("steel", Vector3(0.12, 0.14, 0.5), Vector3.ZERO)
	k.box("steel", Vector3(0.14, 0.13, 0.15), Vector3(-0.13, -0.02, 0.0))
	k.lathe("dark", [Vector2(0, 0), Vector2(0.032, 0), Vector2(0.032, l), Vector2(0.024, l), Vector2(0, l - 0.02)],
		Vector3(0, 0.02, 0.25), Vector3(90, 0, 0), 6)
	k.pop()


## Yuvarlak kapak: çerçeve, kapak ve tutamak.
static func _hatch(k: Kit, p: Vector3, r: float) -> void:
	k.lathe("hull2", [Vector2(r + 0.05, 0), Vector2(r + 0.05, 0.05), Vector2(r, 0.07), Vector2(0, 0.08)], p, Vector3.ZERO, 12)
	k.box("steel", Vector3(r * 0.9, 0.03, 0.05), p + Vector3(0, 0.09, -r * 0.3))


## Nişangâh / periskop kutusu, önünde cam.
static func _sight(k: Kit, s: String, size: Vector3, p: Vector3, yaw: float) -> void:
	k.push(p, Vector3(0, yaw, 0))
	k.box(s, size, Vector3.ZERO)
	k.box("glass", Vector3(size.x * 0.76, size.y * 0.48, 0.02), Vector3(0, size.y * 0.06, size.z * 0.5 + 0.006))
	k.pop()


## Telsiz anteni: taban ve ince çubuk.
static func _antenna(k: Kit, p: Vector3, l: float) -> void:
	_cyl(k, "steel", 0.06, 0.1, p + Vector3(0, 0.05, 0), Vector3.ZERO, 6)
	k.lathe("dark", [Vector2(0, 0), Vector2(0.022, 0), Vector2(0.012, l), Vector2(0, l)], p, Vector3(-6, 0, 0), 4)


## Motor ızgarası: koyu çukur ve üstünde çıtalar. w x yönünde, l z yönünde, pitch derece.
static func _grille(k: Kit, p: Vector3, w: float, l: float, pitch: float, slats: int) -> void:
	k.push(p, Vector3(pitch, 0, 0))
	k.box("dark", Vector3(w, 0.03, l), Vector3.ZERO)
	for i in slats:
		k.box("hull2", Vector3(w * 0.96, 0.03, l / slats * 0.45), Vector3(0, 0.02, -l * 0.5 + l * (i + 0.5) / slats))
	k.pop()


## Hava tanıma örtüsü (takım rengi): ince kumaş.
static func _panel(k: Kit, p: Vector3, w: float, l: float, pitch: float) -> void:
	k.push(p, Vector3(pitch, 0, 0))
	k.box("team", Vector3(w, 0.015, l), Vector3.ZERO)
	k.box("team", Vector3(w * 0.3, 0.02, l * 0.25), Vector3(w * 0.3, 0.005, l * 0.32), Vector3(0, 8, 0))
	k.pop()


## Kapaklı kutu ve iki kilit.
static func _crate(k: Kit, s: String, size: Vector3, p: Vector3) -> void:
	k.box(s, size, p)
	k.box(s, Vector3(size.x + 0.03, 0.04, size.z + 0.03), p + Vector3(0, size.y * 0.5 - 0.01, 0))
	for f in [-0.3, 0.3]:
		k.box("steel", Vector3(0.025, 0.08, 0.05), p + Vector3(size.x * 0.5 + 0.01, size.y * 0.25, size.z * f))


## Yatay yakıt varili (ekseni x yönünde), çember çıkıntılı.
static func _drum(k: Kit, p: Vector3) -> void:
	k.lathe("hull2", [Vector2(0, -0.45), Vector2(0.27, -0.45), Vector2(0.29, -0.42), Vector2(0.29, -0.17), Vector2(0.305, -0.15),
		Vector2(0.29, -0.13), Vector2(0.29, 0.13), Vector2(0.305, 0.15), Vector2(0.29, 0.17), Vector2(0.29, 0.42),
		Vector2(0.27, 0.45), Vector2(0, 0.45)], p, Vector3(0, 0, 90), 12)
	for f in [-0.32, 0.32]:
		k.box("steel", Vector3(0.05, 0.08, 0.12), p + Vector3(f, -0.2, 0.3))


## Yumuşak kenarlı çanta / branda yükü. size.z boyuna uzunluk.
static func _bag(k: Kit, s: String, size: Vector3, p: Vector3, yaw: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var cx := hx * 0.6
	var cy := hy * 0.55
	var rings: Array = []
	for zf in [-0.5, -0.42, 0.42, 0.5]:
		var sh := 0.8 if absf(zf) > 0.45 else 1.0
		var r: Array = []
		for q in [Vector2(cx, -hy), Vector2(hx, -cy), Vector2(hx, cy), Vector2(cx, hy), Vector2(-cx, hy), Vector2(-hx, cy), Vector2(-hx, -cy), Vector2(-cx, -hy)]:
			r.append(Vector3(q.x * sh, q.y * sh, size.z * zf))
		rings.append(r)
	k.push(p, Vector3(0, yaw, 0))
	k.loft(s, rings, true)
	k.box("steel", Vector3(size.x * 1.02, size.y * 1.02, 0.03), Vector3(0, 0, size.z * 0.2))
	k.pop()


## Merkava top-zincir perdesi: ince zincir ve iki top.
static func _chain(k: Kit, p: Vector3) -> void:
	k.box("dark", Vector3(0.02, 0.26, 0.02), p + Vector3(0, -0.13, 0))
	k.box("steel", Vector3(0.07, 0.07, 0.07), p + Vector3(0, -0.12, 0))
	k.box("steel", Vector3(0.08, 0.08, 0.08), p + Vector3(0, -0.24, 0))
