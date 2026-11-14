class_name Terrain
extends Node3D
## Arazi. Harita verisi (Defs.MAP) şekillerden kurulur: dikdörtgen [x0, z0, x1, z1], elips {e = [cx, cz, rx, rz]},
## kalın çizgi {p = [[x, z], ...], w = genişlik} ve çokgen {poly = [[x, z], ...]}.
## Nehirler ve yollar çizgidir; yolun nehri kestiği yerde kendiliğinden köprü oluşur (köprüler yıkılabilir).
## Kasabalar evler ve terk edilmiş binalarla, tarlalar ağaç hatlarıyla (rüzgâr kıranlar) kendiliğinden doldurulur.
## Kara birimleri AStarGrid2D ile yol bulur; yol ucuz, orman pahalıdır, bu yüzden ordular yolları izler.
## Görüntü bir yükseklik alanıdır (tepe, dağ, su yatağı); bitki örtüsü rüzgârda salınır (ayrıntı aşağıda, görünüm bölümünde).
## Taktik etkiler: tepe görüş, menzil ve hasar verir; orman ve ağaç hattı gizler ve görüşü keser; yol hızlandırır.

const CELL := 2.0
const LAND := 0
const MOUNTAIN := 1
const WATER := 2
const TREES := 3      # ağaç hattı: geçilir, yavaşlatır, gizler, görüşü keser
const RUINS := 4      # yıkıntı: geçilmez, görüşü keser
const HILL := 5
const FOREST := 6
const ROAD := 7
const BRIDGE := 8
const HILL_H := 2.0
const DECK_H := 0.72     # köprü tabliyesinin üstü: araçlar köprünün üstünden geçer
const WATER_Y := -0.28    # su yüzeyi
const MARGIN_STEPS := [2.0, 4.0, 6.0, 8.0, 12.0, 16.0, 20.0, 24.0, 28.0, 32.0, 36.0, 40.0]   # harita dışı ızgara adımları
const PASSABLE := [LAND, HILL, FOREST, ROAD, TREES, BRIDGE]
const KIND_COLORS := {
	1: Color(0.42, 0.39, 0.35), 2: Color(0.14, 0.3, 0.45), 3: Color(0.16, 0.3, 0.13), 4: Color(0.44, 0.41, 0.38),
	6: Color(0.13, 0.25, 0.11), 8: Color(0.45, 0.42, 0.38),
}

var gw := 0
var gh := 0
var kind := PackedByteArray()
var bld := PackedByteArray()     # hücreyi kaplayan bina sayısı (görüş hattını keser)
var astar := AStarGrid2D.new()
var bridge_data: Array = []      # {a, b, w, cells}
var house_data: Array = []       # [x, z, tür]
var ground_img: Image             # küçük harita ve önizleme için hücre renkleri
# görsel yükseklik alanı: köşe başına (vw x vh), hücre adımıyla
var vw := 0
var vh := 0
var hgt := PackedFloat32Array()
var f_water := PackedFloat32Array()
var fog_mats: Array = []         # savaş sisinde kararan bitki malzemeleri (Fog dokusunu verir)
var _cover := {}                 # hücre -> [[MultiMesh, sıra, Transform3D], ...]; bina kurulunca gizlenir
var _nature := true
var _far := FastNoiseLite.new()
var _pmat: ShaderMaterial = null
var _smats := {}
var _cube := BoxMesh.new()
var deck := {}                   # köprü tabliyesinin altındaki hücreler (kıyıdaki uçlar dahil)


func _ready() -> void:
	var gd := build_grid(Defs.MAP)
	gw = gd.gw
	gh = gd.gh
	kind = gd.kind
	bridge_data = gd.bridges
	house_data = gd.houses
	bld.resize(gw * gh)
	astar.region = Rect2i(0, 0, gw, gh)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in gh:
		for x in gw:
			var k := kind[y * gw + x]
			var c := Vector2i(x, y)
			if not k in PASSABLE:
				astar.set_point_solid(c, true)
			elif k == ROAD or k == BRIDGE:
				astar.set_point_weight_scale(c, 0.55)
			elif k == FOREST:
				astar.set_point_weight_scale(c, 1.7)
			elif k == TREES or k == HILL:
				astar.set_point_weight_scale(c, 1.25)
	for br in bridge_data:
		var a3 := Vector3(br.a.x, 0, br.a.y)
		var b3 := Vector3(br.b.x, 0, br.b.y)
		var lo: Vector2 = Vector2(minf(a3.x, b3.x), minf(a3.z, b3.z)) - Vector2.ONE * br.w
		var hi: Vector2 = Vector2(maxf(a3.x, b3.x), maxf(a3.z, b3.z)) + Vector2.ONE * br.w
		for y in range(maxi(0, int((lo.y + Defs.MAP_H * 0.5) / CELL)), mini(gh, int((hi.y + Defs.MAP_H * 0.5) / CELL) + 1)):
			for x in range(maxi(0, int((lo.x + Defs.MAP_W * 0.5) / CELL)), mini(gw, int((hi.x + Defs.MAP_W * 0.5) / CELL) + 1)):
				var c3 := center(Vector2i(x, y))
				if Bridge.seg_dist(c3, a3, b3) <= br.w * 0.5:
					deck[y * gw + x] = true
	ground_img = make_image(Defs.MAP, gd)
	_visuals()


# ---------------------------------------------------------------- ızgara kurulumu (oyundan bağımsız; menü önizlemesi de kullanır)

static func build_grid(m: Dictionary) -> Dictionary:
	var size: Vector2 = m.size
	var g := {gw = int(ceil(size.x / CELL)), gh = int(ceil(size.y / CELL)), size = size, bridges = [], houses = []}
	var k := PackedByteArray()
	k.resize(g.gw * g.gh)
	g.kind = k
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(m.name)
	_fill(g, m.get("hills", []), HILL)
	_fill(g, m.get("forest", []), FOREST)
	_fill(g, m.get("water", []), WATER)
	_fill(g, m.get("rivers", []), WATER)
	_fill(g, m.get("rock", []), MOUNTAIN)
	if m.has("windbreaks"):
		_windbreaks(g, m, rng)
	_fill(g, m.get("trees", []), TREES, [LAND, HILL])
	_fill(g, m.get("ruins", []), RUINS, [LAND])
	_roads(g, m)
	_towns(g, m, rng)
	# Üslerin ve noktaların çevresi düz kara olsun.
	for b in m.bases_a + m.bases_b:
		_clear(g, Vector2(b.x, b.z), 40.0)
	for p in m.points:
		_clear(g, Vector2(p[0], p[1]), 8.0)
	for h in m.get("big", []):
		_clear(g, Vector2(h[0], h[1]), 5.0)
	for h in m.get("big", []):
		g.houses.append([float(h[0]), float(h[1]), h[2]])
	return g


static func _idx(g: Dictionary, x: int, y: int) -> int:
	return y * int(g.gw) + x


static func _cx(g: Dictionary, x: int) -> float:
	return (x + 0.5) * CELL - g.size.x * 0.5


static func _cz(g: Dictionary, y: int) -> float:
	return (y + 0.5) * CELL - g.size.y * 0.5


## Şeklin dünya koordinatında sınır kutusu: [x0, z0, x1, z1].
static func _bbox(s) -> Array:
	if s is Array:
		return [minf(s[0], s[2]), minf(s[1], s[3]), maxf(s[0], s[2]), maxf(s[1], s[3])]
	if s.has("e"):
		return [s.e[0] - s.e[2], s.e[1] - s.e[3], s.e[0] + s.e[2], s.e[1] + s.e[3]]
	var pts: Array = s.get("p", s.get("poly", []))
	var b := [1e9, 1e9, -1e9, -1e9]
	for p in pts:
		b = [minf(b[0], p[0]), minf(b[1], p[1]), maxf(b[2], p[0]), maxf(b[3], p[1])]
	var w := float(s.get("w", 0.0)) * 0.5
	return [b[0] - w, b[1] - w, b[2] + w, b[3] + w]


static func shape_has(s, x: float, z: float) -> bool:
	if s is Array:
		return x >= minf(s[0], s[2]) and x <= maxf(s[0], s[2]) and z >= minf(s[1], s[3]) and z <= maxf(s[1], s[3])
	if s.has("e"):
		var dx: float = (x - s.e[0]) / s.e[2]
		var dz: float = (z - s.e[1]) / s.e[3]
		return dx * dx + dz * dz <= 1.0
	if s.has("p"):
		var w := float(s.w) * 0.5
		var pts: Array = s.p
		for i in pts.size() - 1:
			if _seg_dist(Vector2(x, z), Vector2(pts[i][0], pts[i][1]), Vector2(pts[i + 1][0], pts[i + 1][1])) <= w:
				return true
		return false
	var poly: Array = s.poly
	var inside := false
	var j := poly.size() - 1
	for i in poly.size():
		var a: Array = poly[i]
		var b: Array = poly[j]
		if (a[1] > z) != (b[1] > z) and x < (b[0] - a[0]) * (z - a[1]) / (b[1] - a[1]) + a[0]:
			inside = not inside
		j = i
	return inside


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var l2 := ab.length_squared()
	if l2 < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)


## Şekillerin kapladığı hücreleri k türüne çevirir. only: yalnızca bu türlerin üstüne yazar.
static func _fill(g: Dictionary, shapes: Array, k: int, only := []) -> void:
	var kd: PackedByteArray = g.kind
	for s in shapes:
		var bb := _bbox(s)
		var x0 := clampi(int((bb[0] + g.size.x * 0.5) / CELL), 0, g.gw - 1)
		var x1 := clampi(int((bb[2] + g.size.x * 0.5) / CELL), 0, g.gw - 1)
		var y0 := clampi(int((bb[1] + g.size.y * 0.5) / CELL), 0, g.gh - 1)
		var y1 := clampi(int((bb[3] + g.size.y * 0.5) / CELL), 0, g.gh - 1)
		for y in range(y0, y1 + 1):
			var z := _cz(g, y)
			for x in range(x0, x1 + 1):
				var i := _idx(g, x, y)
				if not only.is_empty() and not kd[i] in only:
					continue
				if shape_has(s, _cx(g, x), z):
					kd[i] = k
	g.kind = kd


static func _clear(g: Dictionary, c: Vector2, r: float) -> void:
	var kd: PackedByteArray = g.kind
	for y in range(maxi(0, int((c.y - r + g.size.y * 0.5) / CELL)), mini(g.gh, int((c.y + r + g.size.y * 0.5) / CELL) + 1)):
		for x in range(maxi(0, int((c.x - r + g.size.x * 0.5) / CELL)), mini(g.gw, int((c.x + r + g.size.x * 0.5) / CELL) + 1)):
			var i := _idx(g, x, y)
			if kd[i] in [ROAD, BRIDGE, WATER]:
				continue
			if Vector2(_cx(g, x), _cz(g, y)).distance_to(c) <= r:
				kd[i] = LAND
	g.kind = kd


## Tarla aralarındaki ağaç hatları: parsel ızgarası boyunca, aralıklı, yalnızca düz arazide.
static func _windbreaks(g: Dictionary, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var sp: float = m.windbreaks.sp
	var shapes: Array = []
	var hw: float = g.size.x * 0.5
	var hh: float = g.size.y * 0.5
	var bases: Array = m.bases_a + m.bases_b
	var x := -hw + sp * 0.5
	while x < hw:
		var z := -hh
		while z < hh:
			var l := rng.randf_range(sp * 0.4, sp * 0.95)
			if rng.randf() < 0.6:
				shapes.append({p = [[x, z], [x + rng.randf_range(-3, 3), z + l]], w = 3.0})
			z += l + rng.randf_range(8.0, 22.0)
		x += sp * rng.randf_range(0.8, 1.2)
	var z2 := -hh + sp * 0.5
	while z2 < hh:
		var x2 := -hw
		while x2 < hw:
			var l := rng.randf_range(sp * 0.4, sp * 0.95)
			if rng.randf() < 0.55:
				shapes.append({p = [[x2, z2], [x2 + l, z2 + rng.randf_range(-3, 3)]], w = 3.0})
			x2 += l + rng.randf_range(8.0, 22.0)
		z2 += sp * rng.randf_range(0.8, 1.2)
	var keep: Array = []
	for s in shapes:
		var ok := true
		for b in bases:
			if Vector2(s.p[0][0], s.p[0][1]).distance_to(Vector2(b.x, b.z)) < 60.0:
				ok = false
		if ok:
			keep.append(s)
	_fill(g, keep, TREES, [LAND])


## Kasabalar: evler, apartmanlar ve yıkıntı yığınları. [x, z, ev sayısı, yarıçap, ad, apartman oranı]
static func _towns(g: Dictionary, m: Dictionary, rng: RandomNumberGenerator) -> void:
	var kd: PackedByteArray = g.kind
	for t in m.get("towns", []):
		var c := Vector2(t[0], t[1])
		var placed: Array = []
		var tries := 0
		while placed.size() < int(t[2]) and tries < int(t[2]) * 40:
			tries += 1
			var a := rng.randf() * TAU
			var r: float = sqrt(rng.randf()) * float(t[3])
			var p := c + Vector2(cos(a), sin(a)) * r
			p = Vector2(snappedf(p.x, 2.0) + 1.0, snappedf(p.y, 2.0) + 1.0)
			if absf(p.x) > g.size.x * 0.5 - 8 or absf(p.y) > g.size.y * 0.5 - 8:
				continue
			var ok := true
			for q in placed:
				if q.distance_to(p) < 7.5:
					ok = false
			for pt in m.points:
				if p.distance_to(Vector2(pt[0], pt[1])) < 11.0:
					ok = false
			if not ok:
				continue
			var cx := int((p.x + g.size.x * 0.5) / CELL)
			var cy := int((p.y + g.size.y * 0.5) / CELL)
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					var xx := clampi(cx + dx, 0, g.gw - 1)
					var yy := clampi(cy + dy, 0, g.gh - 1)
					if kd[_idx(g, xx, yy)] != LAND:
						ok = false
			if not ok:
				continue
			placed.append(p)
			var tp := "block" if rng.randf() < float(t[5] if t.size() > 5 else 0.2) else "house"
			g.houses.append([p.x, p.y, tp])
		# yıkıntı yığınları: kasabanın arasında görüşü kesen moloz
		for i in int(t[2]) / 2:
			var a := rng.randf() * TAU
			var p := c + Vector2(cos(a), sin(a)) * sqrt(rng.randf()) * float(t[3])
			var cx := int((p.x + g.size.x * 0.5) / CELL)
			var cy := int((p.y + g.size.y * 0.5) / CELL)
			if cx < 1 or cy < 1 or cx >= g.gw - 1 or cy >= g.gh - 1:
				continue
			var near := false
			for q in placed:
				if q.distance_to(p) < 5.0:
					near = true
			if not near and kd[_idx(g, cx, cy)] == LAND:
				kd[_idx(g, cx, cy)] = RUINS
	g.kind = kd


## Yollar: nehri kestiği yerde köprü kurar, sonra yol hücrelerini işler.
static func _roads(g: Dictionary, m: Dictionary) -> void:
	for r in m.get("roads", []):
		var pts: Array = r.p
		for i in pts.size() - 1:
			var a := Vector2(pts[i][0], pts[i][1])
			var b := Vector2(pts[i + 1][0], pts[i + 1][1])
			var l := a.distance_to(b)
			var dir := (b - a) / l
			var t := 0.0
			var run_start := -1.0
			while t <= l:
				var p := a + dir * t
				var wet := _kind_at(g, p) in [WATER, BRIDGE]
				if wet and run_start < 0.0:
					run_start = t
				elif (not wet or t + 0.5 > l) and run_start >= 0.0:
					var ba := a + dir * maxf(0.0, run_start - 2.5)
					var bb := a + dir * minf(l, t + 2.5)
					var br := {a = ba, b = bb, w = float(r.w) + 2.0, cells = []}
					_mark_bridge(g, br)
					if not br.cells.is_empty():
						g.bridges.append(br)
					run_start = -1.0
				t += 0.5
	_fill(g, m.get("roads", []), ROAD, [LAND, FOREST, TREES, RUINS])


static func _kind_at(g: Dictionary, p: Vector2) -> int:
	var x := clampi(int((p.x + g.size.x * 0.5) / CELL), 0, g.gw - 1)
	var y := clampi(int((p.y + g.size.y * 0.5) / CELL), 0, g.gh - 1)
	return g.kind[_idx(g, x, y)]


static func _mark_bridge(g: Dictionary, br: Dictionary) -> void:
	var kd: PackedByteArray = g.kind
	var s := {p = [[br.a.x, br.a.y], [br.b.x, br.b.y]], w = br.w - 1.0}
	var bb := _bbox(s)
	for y in range(clampi(int((bb[1] + g.size.y * 0.5) / CELL), 0, g.gh - 1), clampi(int((bb[3] + g.size.y * 0.5) / CELL), 0, g.gh - 1) + 1):
		for x in range(clampi(int((bb[0] + g.size.x * 0.5) / CELL), 0, g.gw - 1), clampi(int((bb[2] + g.size.x * 0.5) / CELL), 0, g.gw - 1) + 1):
			var i := _idx(g, x, y)
			if kd[i] == WATER and shape_has(s, _cx(g, x), _cz(g, y)):
				kd[i] = BRIDGE
				br.cells.append(Vector2i(x, y))
	g.kind = kd


## Zemin resmi: her hücre bir piksel; renk araziden, alfa suyun yeri. Tarlalar parsel parsel farklı tondadır.
static func make_image(m: Dictionary, g: Dictionary) -> Image:
	var gw2: int = g.gw
	var gh2: int = g.gh
	var data := PackedByteArray()
	data.resize(gw2 * gh2 * 4)
	var ground: Color = m.ground
	var patch: Color = m.patch
	var fields: Array = m.get("fields", [ground, patch, ground.darkened(0.08)])
	var sp: float = m.get("windbreaks", {}).get("sp", 70.0)
	var kd: PackedByteArray = g.kind
	var noise := FastNoiseLite.new()
	noise.seed = hash(m.name) % 997
	noise.frequency = 0.04
	for y in gh2:
		for x in gw2:
			var k := kd[y * gw2 + x]
			var c: Color
			var wx: float = (x + 0.5) * CELL - g.size.x * 0.5
			var wz: float = (y + 0.5) * CELL - g.size.y * 0.5
			match k:
				LAND:
					var pi := int(floor(wx / sp) * 7 + floor(wz / (sp * 0.6)) * 13)
					c = fields[absi(pi) % fields.size()].lerp(ground, 0.5)
					c = c.lerp(patch, clampf(noise.get_noise_2d(wx, wz) * 0.9 + 0.2, 0.0, 0.7))
				HILL:
					c = ground.lightened(0.1)
				ROAD:
					c = ground.lerp(Color(0.42, 0.37, 0.3), 0.7)
				MOUNTAIN:
					c = ground.lerp(KIND_COLORS[1], 0.7)
				_:
					c = ground.lerp(KIND_COLORS[k], 0.75)
			var i := (y * gw2 + x) * 4
			data[i] = int(clampf(c.r, 0, 1) * 255)
			data[i + 1] = int(clampf(c.g, 0, 1) * 255)
			data[i + 2] = int(clampf(c.b, 0, 1) * 255)
			data[i + 3] = 255 if k == WATER or k == BRIDGE else 0
	return Image.create_from_data(gw2, gh2, false, Image.FORMAT_RGBA8, data)


# ---------------------------------------------------------------- sorgular

func cell(p: Vector3) -> Vector2i:
	return Vector2i(
		clampi(int((p.x + Defs.MAP_W * 0.5) / CELL), 0, gw - 1),
		clampi(int((p.z + Defs.MAP_H * 0.5) / CELL), 0, gh - 1))


func center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL - Defs.MAP_W * 0.5, 0, (c.y + 0.5) * CELL - Defs.MAP_H * 0.5)


func solid(p: Vector3) -> bool:
	return astar.is_point_solid(cell(p))


## Bina kurulabilir mi: yalnızca düz kara ve yol.
func is_land(p: Vector3) -> bool:
	var k := kind_at(p)
	return k == LAND or k == ROAD


func kind_at(p: Vector3) -> int:
	var c := cell(p)
	return kind[c.y * gw + c.x]


## Kara biriminin basacağı yükseklik: köprüde tabliye, tepede arazinin kendisi, başka yerde düz zemin.
func height(p: Vector3) -> float:
	var c := cell(p)
	var k := kind[c.y * gw + c.x]
	if k == BRIDGE or (k != WATER and deck.has(c.y * gw + c.x)):
		return DECK_H
	return maxf(0.0, ground_y(p.x, p.z))


## Görsel arazi yüksekliği (su yatağında eksi). Harita dışında kenar değeri.
func ground_y(x: float, z: float) -> float:
	var fx := clampf((x + Defs.MAP_W * 0.5) / CELL, 0.0, vw - 1.001)
	var fz := clampf((z + Defs.MAP_H * 0.5) / CELL, 0.0, vh - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var k := j * vw + i
	return lerpf(lerpf(hgt[k], hgt[k + 1], tx), lerpf(hgt[k + vw], hgt[k + vw + 1], tx), fz - j)


## Kara birimi hız çarpanı: yol hızlandırır, orman ve ağaç hattı araçları çok, piyadeyi az yavaşlatır, tepe yokuştur.
func speed_mult(p: Vector3, armor: String) -> float:
	match kind_at(p):
		ROAD, BRIDGE:
			return 1.5
		FOREST:
			return 0.85 if armor == "inf" else 0.55
		TREES:
			return 0.9 if armor == "inf" else 0.65
		HILL:
			return 0.85
	return 1.0


## Gizlenme yeri: orman ve ağaç hattı.
func cover_at(p: Vector3) -> bool:
	var k := kind_at(p)
	return k == FOREST or k == TREES


## Doğrudan atış için görüş hattı. Dağ her zaman keser; ağaç hattı, yıkıntı, binalar ve derin orman
## (üç hücreden fazlası) yalnızca tepede olmayan atıcı için keser. Atıcının ve hedefin hemen yanı sayılmaz.
func los_clear(a: Vector3, b: Vector3) -> bool:
	var dist := Vector2(a.x - b.x, a.z - b.z).length()
	if dist < 4.0:
		return true
	var high := kind_at(a) == HILL
	var n := int(dist / (CELL * 0.5))
	var woods := 0
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		if Vector2(p.x - a.x, p.z - a.z).length() < 2.4 or Vector2(p.x - b.x, p.z - b.z).length() < 3.0:
			continue
		var c := cell(p)
		var idx := c.y * gw + c.x
		var k := kind[idx]
		if k == MOUNTAIN:
			return false
		if high:
			continue
		if k == TREES or k == RUINS or bld[idx] > 0:
			return false
		if k == FOREST:
			woods += 1
			if woods > 6:
				return false
	return true


func nearest_free(p: Vector3) -> Vector3:
	var q := Vector3(
		clampf(p.x, -Defs.MAP_W * 0.5 + 1.0, Defs.MAP_W * 0.5 - 1.0), 0,
		clampf(p.z, -Defs.MAP_H * 0.5 + 1.0, Defs.MAP_H * 0.5 - 1.0))
	var c := cell(q)
	if not astar.is_point_solid(c):
		return q
	for r in range(1, 30):
		var best := Vector3.INF
		var bd := 1e9
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if maxi(absi(dx), absi(dy)) != r:
					continue
				var n := Vector2i(c.x + dx, c.y + dy)
				if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh or astar.is_point_solid(n):
					continue
				var w := center(n)
				var d := w.distance_squared_to(q)
				if d < bd:
					bd = d
					best = w
		if best != Vector3.INF:
			return best
	return q


func line_clear(a: Vector3, b: Vector3) -> bool:
	var d := Vector2(a.x - b.x, a.z - b.z).length()
	var n := int(d / (CELL * 0.5)) + 1
	for i in range(1, n + 1):
		if astar.is_point_solid(cell(a.lerp(b, float(i) / n))):
			return false
	return true


func find_path(a: Vector3, b: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	var goal := nearest_free(b)
	var ids := astar.get_id_path(cell(nearest_free(a)), cell(goal))
	for id in ids:
		out.append(center(id))
	if out.size() > 0:
		out[out.size() - 1] = goal
	return out


func block_circle(p: Vector3, r: float, v: bool) -> void:
	var c := cell(p)
	var n := int(ceil(r / CELL)) + 1
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			var q := Vector2i(c.x + dx, c.y + dy)
			if q.x < 0 or q.y < 0 or q.x >= gw or q.y >= gh:
				continue
			var idx := q.y * gw + q.x
			if not kind[idx] in PASSABLE:
				continue
			if Vector2(center(q).x - p.x, center(q).z - p.z).length() <= r:
				bld[idx] = clampi(bld[idx] + (1 if v else -1), 0, 255)
				astar.set_point_solid(q, bld[idx] > 0)
				# binanın altındaki ot ve çalı gizlenir
				if _cover.has(idx):
					for cv in _cover[idx]:
						cv[0].set_instance_transform(cv[1], cv[2] if bld[idx] == 0 else Transform3D(Basis.from_scale(Vector3.ZERO), cv[2].origin))


## Köprü yıkılınca hücreleri suya döner (geçilmez); onarılınca yeniden açılır.
func set_bridge(cells: Array, up: bool) -> void:
	for c in cells:
		var idx: int = c.y * gw + c.x
		kind[idx] = BRIDGE if up else WATER
		astar.set_point_solid(c, not up or bld[idx] > 0)
		if up:
			astar.set_point_weight_scale(c, 0.55)


# ---------------------------------------------------------------- görünüm
# Hücre ızgarasından bir yükseklik alanı üretilir (yuvarlak tepeler, sırtlı dağlar, kumsallı su yatağı) ve parça parça
# tek arazi olarak çizilir; renk tarla dokusu ile maske dokusundan shader'da karışır. Ağaç, çalı, ot ve kaya
# parça başına MultiMesh ile serpilir ve rüzgârda salınır. Oynanış ızgarası (kind) bundan etkilenmez.

## Her hücrenin, işaretli (mask = 1) en yakın hücreye hücre cinsinden uzaklığı (iki geçişli yaklaşık ölçüm).
func _dist_to(mask: PackedByteArray) -> PackedFloat32Array:
	var d := PackedFloat32Array()
	d.resize(gw * gh)
	for i in gw * gh:
		d[i] = 0.0 if mask[i] == 1 else 999.0
	for y in gh:
		var row := y * gw
		for x in gw:
			var k := row + x
			var v := d[k]
			if v == 0.0:
				continue
			if x > 0:
				v = minf(v, d[k - 1] + 1.0)
			if y > 0:
				v = minf(v, d[k - gw] + 1.0)
				if x > 0:
					v = minf(v, d[k - gw - 1] + 1.414)
				if x < gw - 1:
					v = minf(v, d[k - gw + 1] + 1.414)
			d[k] = v
	for y in range(gh - 1, -1, -1):
		var row := y * gw
		for x in range(gw - 1, -1, -1):
			var k := row + x
			var v := d[k]
			if v == 0.0:
				continue
			if x < gw - 1:
				v = minf(v, d[k + 1] + 1.0)
			if y < gh - 1:
				v = minf(v, d[k + gw] + 1.0)
				if x < gw - 1:
					v = minf(v, d[k + gw + 1] + 1.414)
				if x > 0:
					v = minf(v, d[k + gw - 1] + 1.414)
			d[k] = v
	return d


## k türündeki hücrelerin içeri doğru derinliği (hücre): tür dışındaki en yakın hücreye uzaklık.
func _depth(kinds: Array) -> PackedFloat32Array:
	var mask := PackedByteArray()
	mask.resize(gw * gh)
	for i in gw * gh:
		mask[i] = 0 if kind[i] in kinds else 1
	return _dist_to(mask)


func _visuals() -> void:
	var m: Dictionary = Defs.MAP
	var ground: Color = m.ground
	_nature = Settings.get_v("nature")
	var hw := Defs.MAP_W * 0.5
	var hh := Defs.MAP_H * 0.5
	var n := FastNoiseLite.new()
	n.seed = 23
	n.frequency = 0.11
	n.fractal_octaves = 2
	var ridge := FastNoiseLite.new()
	ridge.seed = 41
	ridge.frequency = 0.05
	ridge.fractal_octaves = 3
	_far.seed = 9
	_far.frequency = 0.008
	_far.fractal_octaves = 3
	# Hücre başına alanlar: tepe, dağ ve su derinliği; kıyıya uzaklık. Köprünün altı da sudur.
	var d_hill := _depth([HILL])
	var d_rock := _depth([MOUNTAIN])
	var d_water := _depth([WATER, BRIDGE])
	var wmask := PackedByteArray()
	wmask.resize(gw * gh)
	for i in gw * gh:
		wmask[i] = 1 if kind[i] == WATER or kind[i] == BRIDGE else 0
	var d_shore := _dist_to(wmask)
	var ch := PackedFloat32Array()      # hücre yüksekliği
	ch.resize(gw * gh)
	f_water.resize(gw * gh)
	var mask := PackedByteArray()
	mask.resize(gw * gh * 4)
	var field := PackedByteArray()
	field.resize(gw * gh * 3)
	var fields: Array = m.get("fields", [ground, m.patch, ground.darkened(0.08)])
	var sp: float = m.get("windbreaks", {}).get("sp", 70.0)
	for y in gh:
		for x in gw:
			var k := y * gw + x
			var wx := (x + 0.5) * CELL - hw
			var wz := (y + 0.5) * CELL - hh
			var wob := n.get_noise_2d(wx, wz)
			var hill := smoothstep(0.0, 3.5, d_hill[k] + wob * 0.6) if d_hill[k] > 0.0 else 0.0
			var rock := smoothstep(0.0, 3.2, d_rock[k] + wob * 0.5) if d_rock[k] > 0.0 else 0.0
			var w := smoothstep(0.0, 1.7, d_water[k]) if d_water[k] > 0.0 else 0.0
			var rg := 1.0 - absf(ridge.get_noise_2d(wx, wz))
			var h := hill * (HILL_H * 1.3 + 0.5 * wob) + rock * (2.2 + 9.0 * rg * rg * rg + 1.2 * wob)
			ch[k] = lerpf(h, -1.5, w)
			f_water[k] = w
			var kd := kind[k]
			var sand := smoothstep(2.4, 0.7, d_shore[k] + wob * 0.8) * (1.0 - rock)
			mask[k * 4] = 255 if kd == ROAD else 0
			mask[k * 4 + 1] = 255 if kd == FOREST or kd == TREES else 0
			mask[k * 4 + 2] = int(sand * 255.0)
			mask[k * 4 + 3] = int(rock * 255.0)
			# tarla parselleri (zemin resmindekiyle aynı düzen)
			var pi := int(floor(wx / sp) * 7 + floor(wz / (sp * 0.6)) * 13)
			var fc: Color = fields[absi(pi) % fields.size()].lerp(ground, 0.5)
			field[k * 3] = int(clampf(fc.r, 0, 1) * 255)
			field[k * 3 + 1] = int(clampf(fc.g, 0, 1) * 255)
			field[k * 3 + 2] = int(clampf(fc.b, 0, 1) * 255)
	var mask_tex := ImageTexture.create_from_image(Image.create_from_data(gw, gh, false, Image.FORMAT_RGBA8, mask))
	var field_tex := ImageTexture.create_from_image(Image.create_from_data(gw, gh, false, Image.FORMAT_RGB8, field))
	# Köşe yükseklikleri: komşu dört hücrenin ortalaması (yumuşak yamaç).
	vw = gw + 1
	vh = gh + 1
	hgt.resize(vw * vh)
	for y in vh:
		var y0 := maxi(y - 1, 0)
		var y1 := mini(y, gh - 1)
		for x in vw:
			var x0 := maxi(x - 1, 0)
			var x1 := mini(x, gw - 1)
			hgt[y * vw + x] = (ch[y0 * gw + x0] + ch[y0 * gw + x1] + ch[y1 * gw + x0] + ch[y1 * gw + x1]) * 0.25

	# Arazi ağı: harita içinde hücre adımı, dışında giderek seyrelen adımlar. Dışarıda uzak tepeler yükselir.
	var xs := _axis(hw, vw)
	var zs := _axis(hh, vh)
	var nx := xs.size()
	var nz := zs.size()
	var mg := MARGIN_STEPS.size()
	var ys := PackedFloat32Array()
	ys.resize(nx * nz)
	for j in nz:
		var fj := clampi(j - mg, 0, vh - 1)
		for i in nx:
			var fi := clampi(i - mg, 0, vw - 1)
			var h := hgt[fj * vw + fi]
			var od := maxf(absf(xs[i]) - hw, absf(zs[j]) - hh)
			if od > 0.0 and h > WATER_Y:
				var fh := 2.0 + 9.0 * (_far.get_noise_2d(xs[i], zs[j]) * 0.5 + 0.5)
				if h > 3.0:
					# kenara dayanan dağ dışarıda sıradağ olarak sürer (kenar değeri uzayıp çizgi yapmasın)
					h = lerpf(h, fh + 7.0, smoothstep(0.0, 30.0, od))
				else:
					h += smoothstep(4.0, 110.0, od) * fh
				h += smoothstep(0.0, 12.0, od) * 0.35 * n.get_noise_2d(xs[i] * 0.4, zs[j] * 0.4)
			ys[j * nx + i] = h
	var tm := Scenery.shader_mat(Scenery.TERRAIN_SHADER)
	var arid: bool = ground.r > ground.g + 0.04
	tm.set_shader_parameter("mask_tex", mask_tex)
	tm.set_shader_parameter("field_tex", field_tex)
	tm.set_shader_parameter("noise_tex", Tex.texture("noise"))
	tm.set_shader_parameter("rock_tex", Tex.texture("rock"))
	tm.set_shader_parameter("bump_tex", Tex.texture("bump"))
	tm.set_shader_parameter("lush_mul", Vector3(0.72, 0.9, 0.7))
	tm.set_shader_parameter("lush_k", 0.3 if arid else 0.8)
	tm.set_shader_parameter("dry", m.patch)
	tm.set_shader_parameter("dirt", ground.lerp(Color(0.5, 0.43, 0.33), 0.75))
	tm.set_shader_parameter("floor_col", ground.lerp(Color(0.15, 0.22, 0.1), 0.6))
	tm.set_shader_parameter("sand", ground.lerp(Color(0.7, 0.63, 0.46), 0.6))
	tm.set_shader_parameter("earth", ground.lerp(Color(0.42, 0.34, 0.24), 0.65))
	tm.set_shader_parameter("rock", Color(0.47, 0.44, 0.4).lerp(ground, 0.2))
	tm.set_shader_parameter("map_size", Vector2(Defs.MAP_W, Defs.MAP_H))
	tm.set_shader_parameter("water_y", WATER_Y)
	var wm := Scenery.shader_mat(Scenery.WATER_SHADER)
	wm.set_shader_parameter("noise_tex", Tex.texture("noise"))
	wm.set_shader_parameter("bump_tex", Tex.texture("bump"))
	wm.set_shader_parameter("deep", Color(0.07, 0.2, 0.3))
	wm.set_shader_parameter("shallow", Color(0.17, 0.4, 0.46))
	wm.set_shader_parameter("bank", ground.lerp(Color(0.5, 0.5, 0.36), 0.6).darkened(0.25))
	wm.set_shader_parameter("map_size", Vector2(Defs.MAP_W, Defs.MAP_H))
	# Parçalara bölünür: kameranın dışında kalan parçalar hiç çizilmez.
	const PIECE := 40
	var j0 := 0
	while j0 < nz - 1:
		var j1 := mini(j0 + PIECE, nz - 1)
		var i0 := 0
		while i0 < nx - 1:
			var i1 := mini(i0 + PIECE, nx - 1)
			_piece(xs, zs, ys, nx, nz, i0, j0, i1, j1, tm, wm)
			i0 = i1
		j0 = j1

	# yollar: keskin kenarlı şeritler (zeminin üstünde)
	var road_mat := Tex.mat("ground", ground.lerp(Color(0.4, 0.36, 0.3), 0.72), 0.15, true)
	var asphalt := Tex.mat("ground", Color(0.27, 0.27, 0.27), 0.15, true)
	for r in m.get("roads", []):
		var pts: Array = r.p
		var w: float = r.w
		var mt: Material = asphalt if r.get("asphalt", false) else road_mat
		for i in pts.size() - 1:
			var a := Vector3(pts[i][0], 0.03, pts[i][1])
			var b := Vector3(pts[i + 1][0], 0.03, pts[i + 1][1])
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(w, 0.04, a.distance_to(b))
			seg.mesh = bm
			seg.material_override = mt
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(seg)
			seg.look_at_from_position((a + b) * 0.5, b, Vector3.UP)
			var j := Models.cyl(self, w * 0.5, w * 0.5, 0.04, b, Color.WHITE, Vector3.ZERO, 10)
			j.material_override = mt
			j.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flora(m, ground, arid)


## Bir eksenin köşe konumları: harita içinde hücre adımı, dışında MARGIN_STEPS.
func _axis(half: float, count: int) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var edge := 0.0
	for s in MARGIN_STEPS:
		edge += s
	var p := -half - edge
	for i in range(MARGIN_STEPS.size() - 1, -1, -1):
		out.append(p)
		p += MARGIN_STEPS[i]
	for i in count:
		out.append(minf(-half + i * CELL, half))
	p = half
	for s in MARGIN_STEPS:
		p += s
		out.append(p)
	return out


## Arazi ağının bir parçası (ve varsa o parçadaki su yüzeyi). Yüksek kesim içeren parçalar gölge düşürür.
func _piece(xs: PackedFloat32Array, zs: PackedFloat32Array, ys: PackedFloat32Array, nx: int, nz: int,
		i0: int, j0: int, i1: int, j1: int, tm: Material, wm: Material) -> void:
	var w := i1 - i0 + 1
	var h := j1 - j0 + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(w * h)
	norms.resize(w * h)
	var top := -10.0
	var low := 10.0
	for j in h:
		var gj := j0 + j
		var ja := maxi(gj - 1, 0)
		var jb := mini(gj + 1, nz - 1)
		for i in w:
			var gi := i0 + i
			var ia := maxi(gi - 1, 0)
			var ib := mini(gi + 1, nx - 1)
			var y := ys[gj * nx + gi]
			top = maxf(top, y)
			low = minf(low, y)
			verts[j * w + i] = Vector3(xs[gi], y, zs[gj])
			norms[j * w + i] = Vector3(
				-(ys[gj * nx + ib] - ys[gj * nx + ia]) / maxf(0.01, xs[ib] - xs[ia]), 1.0,
				-(ys[jb * nx + gi] - ys[ja * nx + gi]) / maxf(0.01, zs[jb] - zs[ja])).normalized()
	var idx := PackedInt32Array()
	idx.resize((w - 1) * (h - 1) * 6)
	var wmap := PackedInt32Array()
	var wv := PackedVector3Array()
	var wc := PackedColorArray()
	var wn := PackedVector3Array()
	var widx := PackedInt32Array()
	if low < WATER_Y:
		wmap.resize(w * h)
		wmap.fill(-1)
	var q := 0
	for j in h - 1:
		for i in w - 1:
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var d := c + 1
			idx[q] = a
			idx[q + 1] = b
			idx[q + 2] = c
			idx[q + 3] = b
			idx[q + 4] = d
			idx[q + 5] = c
			q += 6
			if low < WATER_Y and minf(minf(verts[a].y, verts[b].y), minf(verts[c].y, verts[d].y)) < WATER_Y:
				for k in [a, b, c, b, d, c]:
					if wmap[k] < 0:
						wmap[k] = wv.size()
						wv.append(Vector3(verts[k].x, WATER_Y, verts[k].z))
						wn.append(Vector3.UP)
						wc.append(Color(clampf((WATER_Y - verts[k].y) / 1.1, 0.0, 1.0), 0, 0))
					widx.append(wmap[k])
	var land := MeshInstance3D.new()
	land.mesh = _mesh(verts, norms, idx)
	land.material_override = tm
	var inside: bool = absf(xs[i0]) < Defs.MAP_W * 0.5 + 30.0 and absf(zs[j0]) < Defs.MAP_H * 0.5 + 30.0
	if top < 0.6 or not inside:
		land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(land)
	if not widx.is_empty():
		var water := MeshInstance3D.new()
		water.mesh = _mesh(wv, wn, widx, wc)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		water.material_override = wm
		add_child(water)


func _mesh(v: PackedVector3Array, nr: PackedVector3Array, idx: PackedInt32Array, col := PackedColorArray()) -> ArrayMesh:
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = v
	arr[Mesh.ARRAY_NORMAL] = nr
	arr[Mesh.ARRAY_INDEX] = idx
	if not col.is_empty():
		arr[Mesh.ARRAY_COLOR] = col
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## Savaş sisi için araziye oturan seyrek ağ (4 m). UV harita koordinatıdır.
func drape_mesh(lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cw := int(ceil(gw / 2.0))
	var chh := int(ceil(gh / 2.0))
	for y in chh + 1:
		for x in cw + 1:
			var wx := minf(x * CELL * 2.0, Defs.MAP_W) - Defs.MAP_W * 0.5
			var wz := minf(y * CELL * 2.0, Defs.MAP_H) - Defs.MAP_H * 0.5
			st.set_uv(Vector2((wx + Defs.MAP_W * 0.5) / Defs.MAP_W, (wz + Defs.MAP_H * 0.5) / Defs.MAP_H))
			st.add_vertex(Vector3(wx, maxf(ground_y(wx, wz), WATER_Y) + lift, wz))
	for y in chh:
		for x in cw:
			var a := y * (cw + 1) + x
			var b := a + cw + 1
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
			st.add_index(b)
	return st.commit()


func _plant_mat() -> ShaderMaterial:
	if _pmat == null:
		_pmat = Scenery.shader_mat(Scenery.PLANT_SHADER)
		_pmat.set_shader_parameter("map_size", Vector2(Defs.MAP_W, Defs.MAP_H))
		_pmat.set_shader_parameter("wind", 1.0 if _nature else 0.0)
		fog_mats.append(_pmat)
	return _pmat


## Bitki örtüsü, kaya ve yıkıntı. İklim haritadan seçilir: kurak (hurma), dağlık (çam) ya da ılıman (kavak ve karışık).
## Harita 64 birimlik parçalara bölünür; her parça ve tür ayrı bir MultiMesh'tir, kamera dışındakiler çizilmez.
func _flora(m: Dictionary, ground: Color, arid: bool) -> void:
	const CHUNK := 32
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var alpine: bool = not arid and m.get("style", "") in ["pk", "in"]
	var line_trees: Array = ["palm"] if arid else (["conifer", "conifer", "leafy"] if alpine else ["poplar", "poplar", "leafy"])
	var wood_trees: Array = ["palm"] if arid else (["conifer"] if alpine else ["leafy", "conifer", "leafy"])
	var tint := Color(1.0, 0.95, 0.8) if arid else Color.WHITE
	var groups := {}     # "tür|parça" -> [[Transform3D, Color, hücre], ...]
	var keep_out: Array = []     # üs, ikmal noktası ve evlerin çevresi temiz kalır
	for p in m.points:
		keep_out.append(Vector3(p[0], 4.5, p[1]))
	for hs in house_data:
		keep_out.append(Vector3(hs[0], 4.0, hs[1]))
	for bp in m.bases_a + m.bases_b:
		keep_out.append(Vector3(bp.x, 9.0, bp.z))
	var ko := {}     # hücre -> yasak
	for k3 in keep_out:
		var c0 := cell(Vector3(k3.x, 0, k3.z))
		var rr := int(ceil(k3.y / CELL))
		for dy in range(-rr, rr + 1):
			for dx in range(-rr, rr + 1):
				ko[(c0.y + dy) * gw + c0.x + dx] = true
	var cover_n := FastNoiseLite.new()
	cover_n.seed = 77
	cover_n.frequency = 0.035
	for y in gh:
		for x in gw:
			var ci := y * gw + x
			var k := kind[ci]
			if k == WATER or k == BRIDGE or k == ROAD:
				continue
			var cc := center(Vector2i(x, y))
			var key := "|%d" % ((y / CHUNK) * 1000 + x / CHUNK)
			match k:
				TREES:
					_plant(groups, line_trees[rng.randi() % line_trees.size()] + key, cc, rng, 1.05, 1.5, tint, -1, 0.55)
					if rng.randf() < 0.3:
						_plant(groups, "bush" + key, cc, rng, 0.8, 1.3, tint, -1)
				FOREST:
					if (x + y) % 2 == 0:
						_plant(groups, wood_trees[rng.randi() % wood_trees.size()] + key, cc, rng, 0.95, 1.6, tint, -1, 0.55)
					elif rng.randf() < 0.35:
						_plant(groups, "bush" + key, cc, rng, 0.6, 1.1, tint, ci)
				MOUNTAIN:
					if rng.randf() < 0.05:
						_plant(groups, "rock" + key, cc, rng, 0.9, 2.4, Color.WHITE, -1)
				RUINS:
					_ruin(groups, "ruin" + key, cc, rng)
				LAND, HILL:
					if ko.has(ci):
						continue
					var near := _near(x, y)
					var dens := cover_n.get_noise_2d(cc.x, cc.z) * 0.5 + 0.5
					# su kıyısında saz, ağaç dibinde çalı, dağ eteğinde kaya, çayırda ot öbekleri
					if near.has(WATER) and dens > 0.38:
						for i in rng.randi_range(0, 2):
							_plant(groups, "tuft" + key, cc, rng, 0.9, 1.7, Color(0.95, 0.9, 0.6), ci)
					if (near.has(TREES) or near.has(FOREST)) and rng.randf() < 0.3:
						_plant(groups, "bush" + key, cc, rng, 0.6, 1.2, tint, ci)
					if (near.has(MOUNTAIN) or near.has(RUINS)) and rng.randf() < 0.22:
						_plant(groups, "rock" + key, cc, rng, 0.5, 1.5, Color.WHITE, ci)
					if k == HILL and rng.randf() < 0.05:
						_plant(groups, "rock" + key, cc, rng, 0.5, 1.1, Color.WHITE, ci)
					var chance := (0.07 if arid else 0.26) * smoothstep(0.3, 0.7, dens) + (0.015 if arid else 0.03)
					if rng.randf() < chance:
						var tc := Color(1.5, 1.3, 0.75) if arid else Color(1, 1, 1).lerp(Color(1.1, 1.0, 0.7), rng.randf())
						if not arid and rng.randf() < 0.07:
							tc = [Color(1.6, 1.5, 0.5), Color(1.6, 1.6, 1.5), Color(1.5, 0.6, 0.5)][rng.randi() % 3]
						_plant(groups, "tuft" + key, cc, rng, 0.45, 0.85, tc, ci)
					if not arid and rng.randf() < 0.004 * (1.0 + dens * 2.0):
						_plant(groups, "bush" + key, cc, rng, 0.7, 1.2, tint, ci)
					elif arid and rng.randf() < 0.01:
						_plant(groups, "bush" + key, cc, rng, 0.4, 0.8, Color(1.3, 1.2, 0.7), ci)
	# harita dışı: seyrek ağaçlar ufku doldurur
	var hw := Defs.MAP_W * 0.5
	var hh := Defs.MAP_H * 0.5
	for i in (350 if arid else 1500):
		var p := Vector3(rng.randf_range(-hw - 110.0, hw + 110.0), 0, rng.randf_range(-hh - 100.0, hh + 100.0))
		if absf(p.x) < hw + 2.0 and absf(p.z) < hh + 2.0:
			continue
		var e := Vector3(clampf(p.x, -hw, hw), 0, clampf(p.z, -hh, hh))
		var ec := cell(e)
		if f_water[ec.y * gw + ec.x] > 0.02 or kind_at(e) == MOUNTAIN:
			continue
		if cover_n.get_noise_2d(p.x * 1.6, p.z * 1.6) < -0.08:
			continue
		var od := maxf(absf(p.x) - hw, absf(p.z) - hh)
		var oy := maxf(0.0, ground_y(p.x, p.z)) + smoothstep(4.0, 110.0, od) * (2.0 + 9.0 * (_far.get_noise_2d(p.x, p.z) * 0.5 + 0.5)) - 0.3
		var side := "|out%d" % (int(p.x > 0.0) + 2 * int(p.z > 0.0))
		_plant(groups, wood_trees[rng.randi() % wood_trees.size()] + side, p, rng, 0.9, 1.6, tint, -1, 0.0, oy)
	for gk in groups:
		var nm: String = gk.split("|")[0]
		if nm in ["tuft", "bush"] and not _nature:
			continue
		_emit(nm, groups[gk])


## Komşu hücrelerdeki arazi türleri.
func _near(x: int, y: int) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q := Vector2i(x + d.x, y + d.y)
		if q.x >= 0 and q.y >= 0 and q.x < gw and q.y < gh:
			out.append(kind[q.y * gw + q.x])
	return out


func _plant(groups: Dictionary, key: String, at: Vector3, rng: RandomNumberGenerator, s0: float, s1: float, tint: Color,
		cell_idx: int, jit := 0.95, y := INF) -> void:
	var p := at + Vector3(rng.randf_range(-jit, jit), 0, rng.randf_range(-jit, jit))
	p.y = (ground_y(p.x, p.z) if y == INF else y) - 0.05
	if p.y < WATER_Y - 0.1:
		return
	var s := rng.randf_range(s0, s1)
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.85, 1.25), s))
	var v := rng.randf_range(0.78, 1.12)
	if not groups.has(key):
		groups[key] = []
	groups[key].append([Transform3D(b, p), Color(tint.r * v * rng.randf_range(0.92, 1.08), tint.g * v, tint.b * v * rng.randf_range(0.85, 1.0)), cell_idx])


## Yıkıntı hücresi: ayakta kalmış duvar parçası, yanında alçak kalıntı ve moloz.
func _ruin(groups: Dictionary, key: String, cc: Vector3, rng: RandomNumberGenerator) -> void:
	if not groups.has(key):
		groups[key] = []
	var list: Array = groups[key]
	var wh := rng.randf_range(1.4, 3.2)
	var rot := (rng.randi() % 2) * PI * 0.5 + rng.randf_range(-0.08, 0.08)
	var tone := rng.randf_range(0.75, 1.05)
	var wcol := Color(0.62, 0.58, 0.53) * tone if rng.randf() < 0.7 else Color(0.6, 0.42, 0.34) * tone
	list.append([Transform3D(Basis(Vector3.UP, rot) * Basis.from_scale(Vector3(rng.randf_range(1.3, 2.0), wh, 0.38)),
		cc + Vector3(rng.randf_range(-0.4, 0.4), wh * 0.5, rng.randf_range(-0.4, 0.4))), wcol, -1])
	if rng.randf() < 0.6:
		var h2 := wh * rng.randf_range(0.35, 0.7)
		list.append([Transform3D(Basis(Vector3.UP, rot + PI * 0.5) * Basis.from_scale(Vector3(rng.randf_range(0.9, 1.6), h2, 0.38)),
			cc + Vector3(rng.randf_range(-0.6, 0.6), h2 * 0.5, rng.randf_range(-0.6, 0.6))), wcol, -1])
	for i in 3:
		var s := rng.randf_range(0.25, 0.7)
		var bb := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))) * Basis.from_scale(Vector3(s * 1.4, s * 0.7, s))
		list.append([Transform3D(bb, cc + Vector3(rng.randf_range(-0.9, 0.9), s * 0.2, rng.randf_range(-0.9, 0.9))),
			Color(0.5, 0.48, 0.45) * rng.randf_range(0.7, 1.1), -1])


func _emit(k: String, list: Array) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _cube if k == "ruin" else Scenery.mesh(k)
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_color(i, Color(list[i][1].r, list[i][1].g, list[i][1].b))
		if list[i][2] >= 0:
			if not _cover.has(list[i][2]):
				_cover[list[i][2]] = []
			_cover[list[i][2]].append([mm, i, list[i][0]])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if k == "rock" or k == "ruin":
		var mk := "rock" if k == "rock" else "concrete"
		if not _smats.has(mk):
			var rm: StandardMaterial3D = Tex.mat(mk, Color(0.56, 0.52, 0.47).lerp(Defs.MAP.ground, 0.15) if k == "rock" else Color.WHITE, 0.3, true).duplicate()
			rm.vertex_color_use_as_albedo = true
			rm.vertex_color_is_srgb = true
			_smats[mk] = rm
		mi.material_override = _smats[mk]
	else:
		mi.material_override = _plant_mat()
	if k == "tuft":
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
