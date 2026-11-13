class_name Props
extends RefCounted
## Harita süsleri: ağaçlar, kayalar, çalı ve ot öbekleri, yıkık binalar, köprüler ve zeminin renk geçişleri.
## Hepsi Kit ile kurulur. Ölçüler oyun birimindedir. Ağaç ve kayalar tür başına bir kez üretilir ve
## MultiMesh ile çoğaltılır; yıkıntılar ve köprüler kendi dikdörtgenlerine göre ayrı ayrı kurulur.
## Yerleşim ve zemin rengi de buradadır (scatter, ground); rastgelelik sabit tohumlu karmadır, her açılışta aynı çıkar.
## Not: bu dosya yalnızca Kit çağrıları ve düz hesap içerir; geliştirme önizleme aracı da aynı kodu okur.

const LAND := 0
const MOUNTAIN := 1
const WATER := 2
const TREES := 3
const RUINS := 4

# Tür adları. Ağaçlar: çam (pine), yapraklı (oak), huş (birch). Kayalar: kütle, sivri, öbek, katmanlı.
const TREE_PINE := ["pine0", "pine1", "pine2"]
const TREE_LEAF := ["oak0", "oak1", "birch0"]
const ROCKS := ["rock0", "rock1", "rock2", "rock3"]
const SMALL := ["bush0", "bush1", "stone0", "stone1", "tuft", "tuftdry", "shrubdry", "reed"]


## Sabit tohumlu karma: i -> [0, 1).
static func _h(i: int) -> float:
	return fposmod(sin(i * 12.9898 + 4.1) * 43758.5453, 1.0)


static func _r(i: int, a: float, b: float) -> float:
	return lerpf(a, b, _h(i))


## Değer gürültüsü (yumuşak, 0-1) ve üç katlı toplamı.
static func _vn(x: float, z: float, sd: int) -> float:
	var ix := int(floorf(x))
	var iz := int(floorf(z))
	var fx := x - ix
	var fz := z - iz
	fx = fx * fx * (3.0 - 2.0 * fx)
	fz = fz * fz * (3.0 - 2.0 * fz)
	var a := _h2(ix, iz, sd)
	var b := _h2(ix + 1, iz, sd)
	var c := _h2(ix, iz + 1, sd)
	var d := _h2(ix + 1, iz + 1, sd)
	return lerpf(lerpf(a, b, fx), lerpf(c, d, fx), fz)


static func _h2(ix: int, iz: int, sd: int) -> float:
	return fposmod(sin(ix * 127.1 + iz * 311.7 + sd * 74.7) * 43758.5453, 1.0)


static func _fbm(x: float, z: float, sd: int) -> float:
	return _vn(x, z, sd) * 0.55 + _vn(x * 2.03, z * 2.03, sd + 11) * 0.3 + _vn(x * 4.1, z * 4.1, sd + 23) * 0.15


## Haritanın kaya rengi: gri taş, biraz toprak rengine çalar.
static func rock_color(m: Dictionary) -> Color:
	var g: Color = m["ground"]
	if m.get("flora", "mixed") == "desert":
		return Color(0.66, 0.55, 0.42).lerp(g, 0.2)
	return Color(0.52, 0.49, 0.45).lerp(g, 0.28)


static func slots(k: Kit, m: Dictionary) -> void:
	var g: Color = m["ground"]
	var rc := rock_color(m)
	k.slot("bark", "bark", Color(0.3, 0.25, 0.2), 0.3)
	k.slot("birch", "bark", Color(0.82, 0.8, 0.74), 0.2)
	k.slot("needle", "leaf", Color(0.3, 0.42, 0.24), 0.0)
	k.slot("needle2", "leaf", Color(0.25, 0.37, 0.23), 0.0)
	k.slot("reed", "leaf", Color(0.62, 0.6, 0.34), 0.0)
	k.slot("leaf", "leaf", Color(0.27, 0.38, 0.17), 0.0)
	k.slot("leaf2", "leaf", Color(0.34, 0.43, 0.19), 0.0)
	k.slot("leaf3", "leaf", Color(0.42, 0.47, 0.22), 0.0)
	k.slot("dry", "leaf", Color(0.62, 0.56, 0.36), 0.0)
	k.slot("grass", "leaf", g.lerp(Color(0.42, 0.55, 0.22), 0.5).lightened(0.12), 0.0)
	k.slot("rock", "stone", rc, 0.35)
	k.slot("rock2", "stone", rc.darkened(0.14), 0.35)
	k.slot("rock3", "stone", rc.lightened(0.08), 0.3)
	k.slot("plaster", "concrete", Color(0.72, 0.68, 0.6), 0.5)
	k.slot("brick", "concrete", Color(0.55, 0.33, 0.25), 0.45)
	k.slot("conc", "concrete", Color(0.6, 0.59, 0.55), 0.45)
	k.slot("rubble", "stone", Color(0.56, 0.52, 0.47), 0.4)
	k.slot("char", "concrete", Color(0.16, 0.15, 0.14), 0.1)
	k.slot("rebar", "steel", Color(0.32, 0.22, 0.16), 0.0)
	k.slot("wood", "fabric", Color(0.36, 0.27, 0.19), 0.3)
	k.slot("asphalt", "stone", Color(0.3, 0.3, 0.31), 0.25)
	k.slot("steel", "steel", Color(0.44, 0.45, 0.45), 0.2)
	k.slot("paint", "steel", Color(0.32, 0.4, 0.34), 0.25)
	k.slot("white", "concrete", Color(0.86, 0.85, 0.8), 0.1)
	k.slot("lamp", "optic", Color(0.9, 0.86, 0.66), 0.0)


static func design(id: String, k: Kit) -> void:
	var v: int = maxi(0, "0123".find(id.right(1)))
	# küçük süslerin dibi zemin kadar koyulmasın
	if id in SMALL:
		k.ao_min = 0.62 if id.begins_with("stone") else 0.8
	if id.begins_with("pine"):
		_pine(k, v, 4.6 + 0.5 * v)
	elif id.begins_with("oak"):
		_oak(k, v, 4.2 + 0.6 * v)
	elif id == "birch0":
		_birch(k, 3, 4.8)
	elif id.begins_with("rock"):
		_rock(k, v)
	elif id == "bush0":
		_bush(k, 5, "leaf", 0.7)
	elif id == "bush1":
		_bush(k, 9, "leaf2", 0.55)
	elif id == "shrubdry":
		_bush(k, 13, "dry", 0.45)
	elif id == "stone0":
		_boulder(k, "rock", Vector3.ZERO, 0.32, 0.22, 21)
	elif id == "stone1":
		_boulder(k, "rock2", Vector3(-0.2, 0, 0.1), 0.24, 0.18, 22)
		_boulder(k, "rock", Vector3(0.22, 0, -0.08), 0.18, 0.12, 23)
	elif id == "tuft":
		_tuft(k, "grass", 31)
	elif id == "tuftdry":
		_tuft(k, "dry", 37)
	elif id == "reed":
		for i in 3:
			k.push(Vector3(_r(i + 3, -0.25, 0.25), 0, _r(i + 7, -0.25, 0.25)), Vector3(0, 0, 0), 1.0 + 0.3 * i)
			_tuft(k, "reed", 41 + i)
			k.pop()


# ---------------------------------------------------------------- bitkiler

## Düzensiz yumru: enlem halkaları, her köşenin yarıçapı karmayla oynar. c merkez, r yarıçaplar.
static func _blob(c: Vector3, r: Vector3, sd: int, lats: int, lons: int, rough: float) -> Array:
	var rings: Array = []
	for i in lats:
		var a := lerpf(-PI * 0.5 * 0.9, PI * 0.5 * 0.9, float(i) / (lats - 1))
		var ring: Array = []
		for j in lons:
			var lo := TAU * (j + 0.3 * _h(sd * 53 + j)) / lons
			var jt := 1.0 + rough * (_h(sd * 97 + i * 13 + j) * 2.0 - 1.0)
			ring.append(c + Vector3(cos(a) * cos(lo) * r.x * jt, sin(a) * r.y * jt, cos(a) * sin(lo) * r.z * jt))
		rings.append(ring)
	return rings


## Gövde: kökte genişleyen, hafif eğri koni.
static func _trunk(k: Kit, s: String, base: float, h: float, lean: Vector3) -> void:
	var rings: Array = []
	for i in 4:
		var f := i / 3.0
		var r := base * lerpf(1.0, 0.35, f) * (1.35 if i == 0 else 1.0)
		var c := lean * f * f * h + Vector3(0, f * h - (0.05 if i == 0 else 0.0), 0)
		var ring: Array = []
		for j in 6:
			var a := TAU * j / 6.0
			ring.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
		rings.append(ring)
	k.loft(s, rings, true)


## Çam: ince gövde, aşağı sarkan düzensiz dal katları (yukarı doğru küçülür).
static func _pine(k: Kit, sd: int, h: float) -> void:
	_trunk(k, "bark", h * 0.035, h * 0.8, Vector3(0.02 * sd, 0, 0.01))
	var tiers := 6
	for t in tiers:
		var f := float(t) / tiers
		var yb := h * (0.18 + 0.68 * f)
		var r := h * 0.25 * (1.0 - f * 0.78) * _r(sd * 17 + t, 0.88, 1.1)
		var th := h * 0.26 * (1.0 - f * 0.4)
		var n := 9
		var rings: Array = []
		var prof := [[1.0, 0.07], [0.5, 0.6], [0.0, 1.0], [0.1, 0.45]]
		for pj in prof.size():
			var q: Array = prof[pj]
			var ring: Array = []
			for j in n:
				var a := TAU * (j + 0.4 * _h(sd * 71 + t * 9 + j)) / n
				var jt := 1.0 if pj == 0 else _r(sd * 131 + t * 17 + j * 3 + pj, 0.78, 1.18)
				var droop := 0.0 if pj != 2 else -r * 0.14 * _h(sd * 7 + t * 5 + j)
				ring.append(Vector3(cos(a) * r * q[1] * jt, yb + th * q[0] + droop, sin(a) * r * q[1] * jt))
			rings.append(ring)
		k.loft("needle" if (t + sd) % 3 != 0 else "needle2", rings, true, true)


## Yapraklı ağaç (meşe, ıhlamur): kalın gövde, iki ana dal, birbirine kaynamış düzensiz yaprak öbekleri.
static func _oak(k: Kit, sd: int, h: float) -> void:
	var tr := h * 0.055
	_trunk(k, "bark", tr, h * 0.5, Vector3(0.05, 0, -0.03 * sd))
	for b in 2:
		var a := TAU * (0.2 + 0.5 * b + 0.1 * sd)
		var d := Vector3(cos(a), 0, sin(a))
		var p0 := Vector3(0, h * 0.4, 0)
		var p1 := p0 + d * h * 0.2 + Vector3(0, h * 0.22, 0)
		k.loft("bark", [_disc(p0, tr * 0.6, 5), _disc(p1, tr * 0.25, 5)])
	var n := 6
	for i in n:
		var a := TAU * (i + _h(sd * 41 + i) * 0.5) / (n - 1)
		var rad := 0.0 if i == 0 else h * _r(sd * 43 + i, 0.17, 0.26)
		var c := Vector3(cos(a) * rad, h * (0.78 if i == 0 else _r(sd * 47 + i, 0.56, 0.74)), sin(a) * rad)
		var rr := h * (0.28 if i == 0 else _r(sd * 49 + i, 0.17, 0.23))
		var s: String = ["leaf", "leaf2", "leaf"][(i + sd) % 3]
		k.loft(s, _blob(c, Vector3(rr, rr * 0.78, rr), sd * 10 + i, 5, 8, 0.2), true, true)


## Huş: ince beyaz gövde, seyrek açık yeşil öbekler.
static func _birch(k: Kit, sd: int, h: float) -> void:
	_trunk(k, "birch", h * 0.03, h * 0.86, Vector3(0.06, 0, 0.02))
	for i in 5:
		var a := TAU * (i + 0.3) / 5.0
		var rad := h * (0.0 if i == 0 else 0.11)
		var c := Vector3(cos(a) * rad, h * (0.8 if i == 0 else _r(sd * 23 + i, 0.5, 0.72)), sin(a) * rad)
		var rr := h * (0.17 if i == 0 else _r(sd * 29 + i, 0.12, 0.15))
		k.loft("leaf3" if i % 2 == 0 else "leaf2", _blob(c, Vector3(rr, rr * 1.15, rr), sd * 10 + i, 5, 7, 0.22), true, true)


static func _disc(c: Vector3, r: float, n: int) -> Array:
	var ring: Array = []
	for j in n:
		var a := TAU * j / n
		ring.append(c + Vector3(cos(a) * r, 0, sin(a) * r))
	return ring


## Çalı: yere yakın 3-4 yumru.
static func _bush(k: Kit, sd: int, s: String, r: float) -> void:
	for i in 4:
		var a := TAU * i / 4.0 + sd
		var rad := 0.0 if i == 0 else r * 0.6
		var rr := r * (1.0 if i == 0 else _r(sd * 7 + i, 0.55, 0.75))
		var c := Vector3(cos(a) * rad, rr * 0.55, sin(a) * rad)
		k.loft(s, _blob(c, Vector3(rr, rr * 0.8, rr), sd * 10 + i, 4, 7, 0.25), true, true)


## Ot öbeği: yelpaze gibi açılan ince yapraklar.
static func _tuft(k: Kit, s: String, sd: int) -> void:
	for i in 6:
		var a := TAU * (i + _h(sd + i)) / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		var hh := _r(sd * 3 + i, 0.35, 0.6)
		var b := d * 0.04
		var t := d * (0.12 + 0.08 * _h(sd * 5 + i)) + Vector3(0, hh, 0)
		var side := Vector3(-d.z, 0, d.x) * 0.035
		k.loft(s, [[b - side, b + side, b + d * 0.02], [t - side * 0.15, t + side * 0.15, t + d * 0.004]])


# ---------------------------------------------------------------- kayalar

## Kaya bloğu: tabanı toprağa gömülü, düzensiz, köşeli yüzeyli yumru.
static func _boulder(k: Kit, s: String, c: Vector3, r: float, h: float, sd: int) -> void:
	var rings: Array = []
	var lats := 5
	var lons := 8
	for i in lats:
		var f := float(i) / (lats - 1)
		var y := lerpf(-0.15, 1.0, f) * h
		var rr := r * (1.0 - pow(f, 2.2) * 0.8) * (1.06 if i == 1 else 1.0)
		var ring: Array = []
		for j in lons:
			var a := TAU * (j + 0.35 * _h(sd * 61 + j)) / lons
			var jt := _r(sd * 83 + i * 11 + j, 0.78, 1.2)
			ring.append(c + Vector3(cos(a) * rr * jt, y + (0.0 if i == 0 else h * 0.12 * (_h(sd * 89 + i * 7 + j) - 0.5)), sin(a) * rr * jt))
		rings.append(ring)
	k.loft(s, rings)


## Dağ hücresi kayaları (yaklaşık 2,4 yarıçap, 4,5 yükseklik). 0: iri kütle, 1: sivri kayalık, 2: öbek, 3: katmanlı.
static func _rock(k: Kit, v: int) -> void:
	if v == 0:
		_boulder(k, "rock", Vector3.ZERO, 2.4, 3.6, 101)
		_boulder(k, "rock2", Vector3(1.3, 0, 0.9), 1.2, 1.6, 102)
	elif v == 1:
		# sivri kayalık: yukarı daralan, basamaklı, kırık yüzeyli kule ve dibinde döküntü
		var rings: Array = []
		for i in 7:
			var f := i / 6.0
			var rr := 2.3 * (1.0 - f * 0.82)
			var ring: Array = []
			for j in 7:
				var a := TAU * (j + 0.4 * _h(211 + j)) / 7.0
				var jt := _r(223 + i * 9 + j, 0.72, 1.18)
				var step := 0.0 if i % 2 == 0 else 0.25
				ring.append(Vector3(cos(a) * rr * jt + f * 0.4, f * 5.4 - 0.2 + step * (_h(227 + j) - 0.3), sin(a) * rr * jt))
			rings.append(ring)
		k.loft("rock", rings)
		_boulder(k, "rock2", Vector3(-1.6, 0, 1.0), 0.9, 0.9, 231)
		_boulder(k, "rock3", Vector3(1.7, 0, -1.2), 0.7, 0.6, 232)
	elif v == 2:
		_boulder(k, "rock2", Vector3(-0.9, 0, -0.4), 1.6, 2.8, 301)
		_boulder(k, "rock", Vector3(0.9, 0, 0.5), 1.7, 3.4, 302)
		_boulder(k, "rock3", Vector3(0.1, 0, -1.5), 1.1, 1.7, 303)
	else:
		# katmanlı kaya (tortul): üst üste kaymış yassı tabakalar
		for i in 4:
			var f := i / 3.0
			var c := Vector3(0.35 * sin(i * 2.1), f * 1.1, 0.3 * cos(i * 1.7))
			_boulder(k, "rock" if i % 2 == 0 else "rock3", c, 2.5 * (1.0 - f * 0.3), 1.35, 401 + i)


# ---------------------------------------------------------------- yıkıntılar

## Yıkık bina: w x l taban; kırık üst kenarlı duvarlar, pencere boşlukları, çökmüş döşeme, moloz, çıkık demirler, is.
static func ruin(k: Kit, w: float, l: float, sd: int) -> void:
	var hw := w * 0.5 - 0.3
	var hl := l * 0.5 - 0.3
	var wall: String = "plaster" if sd % 2 == 0 else "brick"
	var tall := 4.6 if sd % 3 == 0 else 2.9
	k.box("conc", Vector3(w - 0.2, 0.16, l - 0.2), Vector3(0, 0.06, 0))
	k.box("char", Vector3(w * 0.5, 0.02, l * 0.4), Vector3(w * 0.1, 0.15, -l * 0.1), Vector3(0, 23, 0))
	# dört duvar: 0,5 birimlik dilimler, yükseklik karmayla kırılır, aralarda yıkık boşluklar
	var sides := [[Vector3(-hw, 0, -hl), Vector3(hw, 0, -hl)], [Vector3(hw, 0, -hl), Vector3(hw, 0, hl)],
		[Vector3(hw, 0, hl), Vector3(-hw, 0, hl)], [Vector3(-hw, 0, hl), Vector3(-hw, 0, -hl)]]
	for si in 4:
		var a: Vector3 = sides[si][0]
		var b: Vector3 = sides[si][1]
		var ln := a.distance_to(b)
		var dir := (b - a) / ln
		k.push(a, Vector3(0, rad_to_deg(atan2(dir.x, dir.z)), 0))
		var n := int(ln / 0.5)
		var run: Array = []
		for i in n + 1:
			var z := ln * i / n
			var edge := minf(z, ln - z)
			var hv := _vn(z * 0.9 + si * 3.0, sd * 1.3, sd) + (0.55 if edge < 0.7 else 0.0)
			var hgt := tall * clampf(hv * 1.3 - 0.3, 0.0, 1.0) + 0.25 * (_h(sd * 31 + si * 17 + i) - 0.5)
			var win := i % 4 == 2 and edge > 1.0 and hgt > 2.1
			if hgt < 0.35 or win or i == n:
				if hgt >= 0.35 and i == n:
					run.append([z, hgt])
				_wall(k, wall, run)
				run = []
				if win:
					# pencere boşluğu: denizlik altı ve lento üstü duvar, kararmış kenar
					k.box(wall, Vector3(0.28, 0.9, 0.9), Vector3(0, 0.55, z))
					k.box(wall, Vector3(0.28, hgt - 1.95, 0.9), Vector3(0, 1.95 + (hgt - 1.95) * 0.5, z))
					k.box("char", Vector3(0.3, 0.05, 0.92), Vector3(0, 1.94, z))
					run.append([z + 0.45, hgt])
				elif _h(sd * 37 + si * 13 + i) < 0.5:
					_boulder(k, "rubble", Vector3(0.3, 0.05, z), 0.4, 0.35, sd * 100 + si * 20 + i)
				continue
			run.append([z, hgt])
			if hgt > tall * 0.6 and _h(sd * 41 + si * 13 + i) < 0.25:
				k.box("rebar", Vector3(0.025, 0.5, 0.025), Vector3(0.05, hgt + 0.2, z), Vector3(12, 0, 8))
			if tall > 4.0 and hgt > 2.7 and i % 2 == 0:
				k.box("conc", Vector3(0.5, 0.14, 0.55), Vector3(0.4, 2.55, z))
		k.pop()
	# çökmüş döşeme parçası, moloz yığınları, kırık tuğlalar
	k.box("conc", Vector3(w * 0.45, 0.14, l * 0.35), Vector3(-w * 0.12, 0.7, l * 0.08), Vector3(24, 15 * sd, 8))
	for i in 3:
		var c := Vector3(_r(sd * 5 + i, -hw * 0.6, hw * 0.6), 0.05, _r(sd * 7 + i, -hl * 0.6, hl * 0.6))
		_boulder(k, "rubble" if i % 2 == 0 else wall, c, _r(sd * 11 + i, 0.7, 1.1), _r(sd * 13 + i, 0.5, 0.9), sd * 50 + i)
	for i in 10:
		var c := Vector3(_r(sd * 17 + i, -w * 0.55, w * 0.55), 0.06, _r(sd * 19 + i, -l * 0.55, l * 0.55))
		k.box(wall if i % 3 != 0 else "conc", Vector3(0.25, 0.12, 0.18), c, Vector3(_r(i, -20, 20), _r(sd + i, 0, 180), 0))
	k.box("wood", Vector3(0.12, 0.12, minf(w, l) * 0.7), Vector3(hw * 0.3, 0.45, 0), Vector3(18, 35, 0))


## Duvar parçası: run = [[z, yükseklik], ...]; kalınlık x yönünde, üst kenar noktalar arasında kırık çizgi.
static func _wall(k: Kit, s: String, run: Array) -> void:
	if run.size() < 2:
		return
	var rings: Array = []
	for q in run:
		var z: float = q[0]
		var h: float = q[1]
		rings.append([Vector3(-0.14, 0.12, z), Vector3(0.14, 0.12, z), Vector3(0.14, h + 0.12, z), Vector3(-0.14, h + 0.12, z)])
	k.loft(s, rings)


# ---------------------------------------------------------------- köprüler

## Köprü: x yönünde L boyunda, W genişliğinde. Asfalt tabliye, kaldırım ve korkuluk, altta kirişler ve
## sudaki ayaklar. big: geniş karayolu köprüsü (şerit çizgileri, aydınlatma direkleri).
static func bridge(k: Kit, L: float, W: float, big: bool) -> void:
	var hl := L * 0.5
	var hw := W * 0.5
	var top := 0.07
	k.ao_min = 0.82
	k.box("asphalt", Vector3(L, 0.36, W - 0.8), Vector3(0, top - 0.18, 0))
	for sz in [-1.0, 1.0]:
		k.box("conc", Vector3(L, 0.5, 0.4), Vector3(0, top - 0.13, sz * (hw - 0.2)))
		# korkuluk: dikmeler ve iki sıra boru
		var n := int(L / 1.2)
		for i in n + 1:
			var x := -hl + 0.3 + (L - 0.6) * i / n
			k.box("steel", Vector3(0.07, 0.6, 0.07), Vector3(x, top + 0.42, sz * (hw - 0.12)))
		for y in [0.45, 0.68]:
			k.box("paint", Vector3(L - 0.5, 0.06, 0.06), Vector3(0, top + y, sz * (hw - 0.12)))
		# yan kiriş
		k.box("conc", Vector3(L, 0.55, 0.3), Vector3(0, top - 0.6, sz * (hw - 0.6)))
	# ayaklar: her ~6 birimde bir, suya inen beton ayak ve başlık kirişi
	var np := maxi(1, int(L / 6.0))
	for i in np:
		var x := -hl + L * (i + 0.5) / np
		k.box("conc", Vector3(0.9, 0.3, W - 0.4), Vector3(x, top - 0.95, 0))
		for sz in [-1.0, 1.0]:
			k.lathe("conc", [Vector2(0.4, -2.0), Vector2(0.38, -0.95)], Vector3(x, top, sz * hw * 0.45), Vector3.ZERO, 8)
	if big:
		var nd := int(L / 2.0)
		for i in nd:
			var x := -hl + 0.8 + (L - 1.6) * i / maxf(nd - 1, 1)
			k.box("white", Vector3(0.9, 0.012, 0.12), Vector3(x, top + 0.005, 0))
		for sz in [-1.0, 1.0]:
			for i in 2:
				var x := -hl * 0.5 + L * 0.5 * i
				k.lathe("steel", [Vector2(0.06, 0), Vector2(0.04, 2.6)], Vector3(x, top, sz * (hw - 0.15)), Vector3.ZERO, 6)
				k.box("steel", Vector3(0.08, 0.06, 0.7), Vector3(x, top + 2.6, sz * (hw - 0.45)))
				k.box("lamp", Vector3(0.2, 0.06, 0.3), Vector3(x, top + 2.55, sz * (hw - 0.75)))
	else:
		for sz in [-1.0, 1.0]:
			k.box("white", Vector3(L - 1.0, 0.012, 0.08), Vector3(0, top + 0.005, sz * (hw - 0.65)))


# ---------------------------------------------------------------- yerleşim

## Haritadaki toprak yollar: iki üs arasında kıvrılan ana yol ve her ikmal noktasından ana yola kısa sapaklar.
## Dönüş: [[Vector2 a, Vector2 b], ...]
static func roads(m: Dictionary) -> Array:
	var bases: Array = m["bases"]
	var a: Vector3 = bases[0]
	var b: Vector3 = bases[1]
	var pts: Array = []
	var n := 9
	for i in n + 1:
		var t := float(i) / n
		var p := Vector2(lerpf(a.x, b.x, t), lerpf(a.z, b.z, t))
		if i > 0 and i < n:
			p.y += (_vn(t * 3.0, 0.5, 5) - 0.5) * 16.0
		pts.append(p)
	var segs: Array = []
	for i in n:
		segs.append([pts[i], pts[i + 1]])
	for q in m["points"]:
		var p := Vector2(q[0], q[1])
		var best: Vector2 = pts[0]
		var bd := 1e9
		for s in pts:
			var d := p.distance_to(s)
			if d < bd:
				bd = d
				best = s
		if bd > 4.0:
			segs.append([p, best])
	return segs


static func _segd(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.dot(ab), 0.001), 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Yolun ve ezilmiş toprağın ağırlığı (0-1): yol ortası, ikmal noktası ve üs çevresi.
static func wear(m: Dictionary, segs: Array, x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := 1e9
	for s in segs:
		d = minf(d, _segd(p, s[0], s[1]))
	d += (_vn(x * 0.2, z * 0.2, 9) - 0.5) * 0.8
	var w := 1.0 - smoothstep(0.7, 1.7, d)
	for q in m["points"]:
		var e := p.distance_to(Vector2(q[0], q[1]))
		w = maxf(w, 1.0 - smoothstep(4.0, 7.5, e + (_vn(x * 0.3, z * 0.3, 4) - 0.5) * 2.0))
	for bs in m["bases"]:
		var e := p.distance_to(Vector2(bs.x, bs.z))
		w = maxf(w, (1.0 - smoothstep(9.0, 15.0, e + (_vn(x * 0.2, z * 0.2, 6) - 0.5) * 4.0)) * 0.85)
	return w


## Zemin rengi: harita toprağı ve yama rengi arasında yumuşak geçişler, çıplak toprak benekleri; orman tabanı,
## kaya dibinde çakıl, su kenarında çamur, yollarda ezilmiş toprak. wf/wr/ww: çevredeki ağaç/kaya/su oranı.
static func ground_color(m: Dictionary, x: float, z: float, wf: float, wr: float, ww: float, road: float) -> Color:
	var g: Color = m["ground"]
	var pc: Color = m["patch"]
	var desert: bool = m.get("flora", "mixed") == "desert"
	var n1 := _fbm(x * 0.022, z * 0.022, 1)
	var n2 := _fbm(x * 0.13, z * 0.13, 2)
	var n3 := _fbm(x * 0.05 + 7.0, z * 0.05, 3)
	var c := g.lerp(pc, smoothstep(0.4, 0.66, n1))
	c = c.lerp(g.darkened(0.16), smoothstep(0.58, 0.8, n3) * 0.75)
	var dirt := g.lerp(Color(0.47, 0.4, 0.3), 0.3 if desert else 0.62)
	c = c.lerp(dirt, smoothstep(0.62, 0.8, n2) * 0.55)
	c = c.lerp(g.darkened(0.34).lerp(Color(0.2, 0.22, 0.12), 0.3), wf * 0.85)
	c = c.lerp(rock_color(m).lerp(g, 0.35), wr * 0.75)
	c = c.lerp(Color(0.33, 0.3, 0.22), minf(ww * 2.2, 0.9))
	c = c.lerp(dirt.darkened(0.05), road * 0.85)
	var kk := 0.92 + 0.16 * n2
	return Color(c.r * kk, c.g * kk, c.b * kk)


## Hücre başına çevre oranları (yarıçap 2 hücre): [ağaç, kaya, su] dizileri.
static func near(kind: Array, gw: int, gh: int) -> Array:
	var wf: Array = []
	var wr: Array = []
	var ww: Array = []
	for y in gh:
		for x in gw:
			var f := 0
			var r := 0
			var w := 0
			var n := 0
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var xx := clampi(x + dx, 0, gw - 1)
					var yy := clampi(y + dy, 0, gh - 1)
					var kd: int = kind[yy * gw + xx]
					n += 1
					if kd == TREES:
						f += 1
					elif kd == MOUNTAIN or kd == RUINS:
						r += 1
					elif kd == WATER:
						w += 1
			wf.append(float(f) / n)
			wr.append(float(r) / n)
			ww.append(float(w) / n)
	return [wf, wr, ww]


## Zemin ağı: step aralıklı köşeler. Dönüş: [köşeler, renkler, üçgen indisleri].
static func ground(m: Dictionary, kind: Array, gw: int, gh: int, cell: float, mw: float, mh: float, step: float) -> Array:
	var nb := near(kind, gw, gh)
	var segs := roads(m)
	var nx := int(mw / step) + 1
	var nz := int(mh / step) + 1
	var verts: Array = []
	var cols: Array = []
	for j in nz:
		for i in nx:
			var x := -mw * 0.5 + i * step
			var z := -mh * 0.5 + j * step
			var cx := clampi(int((x + mw * 0.5) / cell), 0, gw - 1)
			var cz := clampi(int((z + mh * 0.5) / cell), 0, gh - 1)
			var ci := cz * gw + cx
			verts.append(Vector3(x, 0.0, z))
			cols.append(ground_color(m, x, z, nb[0][ci], nb[1][ci], nb[2][ci], wear(m, segs, x, z)))
	var idx: Array = []
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			idx.append_array([a, a + 1, a + nx, a + 1, a + nx + 1, a + nx])
	return [verts, cols, idx]


## Süslerin yerleşimi: tür adı -> [[x, z, dönüş (derece), yatay ölçek, dikey ölçek], ...].
## Ağaç ve kaya geçilmez hücrelere birer tane; çalı, taş ve ot öbekleri açık araziye serpilir (yollar ve
## ikmal noktaları boş kalır).
static func scatter(m: Dictionary, kind: Array, gw: int, gh: int, cell: float, mw: float, mh: float) -> Dictionary:
	var out := {}
	var flora: String = m.get("flora", "mixed")
	var pine_p := 0.75 if flora == "pine" else 0.45
	var nb := near(kind, gw, gh)
	var segs := roads(m)
	for y in gh:
		for x in gw:
			var i := y * gw + x
			var kd: int = kind[i]
			var wx := (x + 0.5) * cell - mw * 0.5 + _r(i * 3 + 1, -0.6, 0.6)
			var wz := (y + 0.5) * cell - mh * 0.5 + _r(i * 3 + 2, -0.6, 0.6)
			var yaw := _r(i * 5 + 3, 0.0, 360.0)
			var h1 := _h(i * 7 + 4)
			var id := ""
			var s := 1.0
			var hh := 1.0
			if kd == TREES:
				if h1 < pine_p:
					id = TREE_PINE[int(_h(i * 11 + 5) * 3.0) % 3]
				else:
					id = TREE_LEAF[int(_h(i * 11 + 5) * 3.0) % 3]
				s = _r(i * 13 + 6, 0.8, 1.15)
				hh = s * _r(i * 17 + 7, 0.9, 1.12)
			elif kd == MOUNTAIN:
				var depth := 0
				for dd in range(1, 4):
					var inside := true
					for o in [[dd, 0], [-dd, 0], [0, dd], [0, -dd]]:
						var xx: int = clampi(x + o[0], 0, gw - 1)
						var yy: int = clampi(y + o[1], 0, gh - 1)
						if kind[yy * gw + xx] != MOUNTAIN:
							inside = false
					if inside:
						depth = dd
				# iç hücrelerin yarısı boş kalır, komşuları biraz iri çizilir (görünmeyen üçgen az olsun)
				if depth >= 2 and (x + y) % 2 == 1:
					continue
				id = ROCKS[int(_h(i * 11 + 5) * 4.0) % 4]
				s = _r(i * 13 + 6, 0.75, 1.05) * (1.15 if depth >= 2 else 1.0)
				hh = (0.6 + 0.22 * depth) * _r(i * 17 + 7, 0.8, 1.2)
				# dağ eteğinde seyrek çam
				if depth == 0 and flora != "desert" and _h(i * 29 + 10) < 0.16:
					if not out.has("pine1"):
						out["pine1"] = []
					out["pine1"].append([wx + 0.8, wz - 0.6, yaw, 0.8, 0.85])
			elif kd == LAND:
				if _inside(m["bridges"], wx, wz, 1.5):
					continue
				var road := wear(m, segs, wx, wz) if h1 < 0.35 else 0.0
				if road > 0.3:
					continue
				var edge: float = nb[0][i] + nb[1][i]
				if nb[2][i] > 0.0 and h1 < 0.45:
					id = "stone0" if flora == "desert" else "reed"
					s = _r(i * 13 + 6, 0.8, 1.3)
				elif edge > 0.0 and h1 < 0.22:
					if nb[1][i] > nb[0][i]:
						id = "stone1" if _h(i * 19 + 8) < 0.5 else "stone0"
						s = _r(i * 13 + 6, 0.8, 1.6)
					elif flora == "desert":
						id = "shrubdry"
					else:
						id = "bush0" if _h(i * 19 + 8) < 0.5 else "bush1"
						s = _r(i * 13 + 6, 0.8, 1.3)
				elif h1 < (0.06 if flora == "desert" else 0.13):
					id = "tuftdry" if flora == "desert" or _h(i * 23 + 9) < 0.25 else "tuft"
					s = _r(i * 13 + 6, 0.8, 1.4)
				elif h1 < 0.15 and flora == "desert":
					id = "stone0"
					s = _r(i * 13 + 6, 0.5, 1.0)
				elif h1 < 0.145:
					id = "shrubdry" if flora == "desert" else "bush1"
					s = _r(i * 13 + 6, 0.6, 1.0)
				hh = s
			if id == "":
				continue
			if not out.has(id):
				out[id] = []
			out[id].append([wx, wz, yaw, s, hh])
	return out


static func _inside(rects: Array, x: float, z: float, pad: float) -> bool:
	for r in rects:
		if x >= r[0] - pad and x <= r[2] + pad and z >= r[1] - pad and z <= r[3] + pad:
			return true
	return false


## Köprünün yönü: altındaki su dikdörtgeni boylamasına (z) uzunsa köprü x yönünde uzanır.
static func bridge_along_x(m: Dictionary, r: Array) -> bool:
	var cx: float = (r[0] + r[2]) * 0.5
	var cz: float = (r[1] + r[3]) * 0.5
	for w in m["water"]:
		if cx >= w[0] and cx <= w[2] and cz >= w[1] and cz <= w[3]:
			return (w[3] - w[1]) >= (w[2] - w[0])
	return (r[2] - r[0]) >= (r[3] - r[1])
