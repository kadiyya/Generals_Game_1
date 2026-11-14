class_name Terrain
extends Node3D
## Arazi. Harita verisi (Defs.MAP) şekillerden kurulur: dikdörtgen [x0, z0, x1, z1], elips {e = [cx, cz, rx, rz]},
## kalın çizgi {p = [[x, z], ...], w = genişlik} ve çokgen {poly = [[x, z], ...]}.
## Nehirler ve yollar çizgidir; yolun nehri kestiği yerde kendiliğinden köprü oluşur (köprüler yıkılabilir).
## Kasabalar evler ve terk edilmiş binalarla, tarlalar ağaç hatlarıyla (rüzgâr kıranlar) kendiliğinden doldurulur.
## Kara birimleri AStarGrid2D ile yol bulur; yol ucuz, orman pahalıdır, bu yüzden ordular yolları izler.
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
var ground_tex: ImageTexture
var ground_img: Image
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
	# Zemin için üç kat büyütülüp yumuşatılır: kıyılar ve orman kenarları basamaklı görünmez.
	var big := ground_img.duplicate()
	big.resize(gw * 3, gh * 3, Image.INTERPOLATE_CUBIC)
	ground_tex = ImageTexture.create_from_image(big)
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


func height(p: Vector3) -> float:
	var c := cell(p)
	var k := kind[c.y * gw + c.x]
	if k == HILL:
		return HILL_H
	if k == BRIDGE or (k != WATER and deck.has(c.y * gw + c.x)):
		return DECK_H
	return 0.0


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


## Köprü yıkılınca hücreleri suya döner (geçilmez); onarılınca yeniden açılır.
func set_bridge(cells: Array, up: bool) -> void:
	for c in cells:
		var idx: int = c.y * gw + c.x
		kind[idx] = BRIDGE if up else WATER
		astar.set_point_solid(c, not up or bld[idx] > 0)
		if up:
			astar.set_point_weight_scale(c, 0.55)


# ---------------------------------------------------------------- görünüm

const GROUND_SHADER := """
shader_type spatial;
uniform sampler2D kinds : source_color, filter_linear, repeat_disable;
uniform sampler2D detail : filter_linear_mipmap, repeat_enable;
uniform bool use_detail = true;
varying vec3 wp;
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec4 k = texture(kinds, UV);
	float d = use_detail ? texture(detail, wp.xz / 7.0).r : 0.85;
	float d2 = use_detail ? texture(detail, wp.xz / 37.0).r : 0.85;
	vec3 c = k.rgb * (0.8 + 0.28 * d) * (0.92 + 0.14 * d2);
	// su maskesi beş örnekle yumuşatılır: kıyılar hücre basamağı yerine yuvarlak görünür
	vec2 px = 2.2 / vec2(textureSize(kinds, 0));
	float wa = k.a * 0.2 + 0.2 * (texture(kinds, UV + vec2(px.x, px.y)).a + texture(kinds, UV + vec2(-px.x, px.y)).a
		+ texture(kinds, UV + vec2(px.x, -px.y)).a + texture(kinds, UV + vec2(-px.x, -px.y)).a);
	k.a = wa;
	float w = smoothstep(0.4, 0.6, wa);
	float r1 = use_detail ? texture(detail, wp.xz / 16.0 + vec2(TIME * 0.012, TIME * 0.007)).r : 0.8;
	float r2 = use_detail ? texture(detail, wp.xz / 23.0 - vec2(TIME * 0.009, TIME * 0.011)).r : 0.8;
	vec3 wc = vec3(0.1, 0.25, 0.38) * (0.8 + 0.35 * r1 * r2);
	float bank = w * (1.0 - smoothstep(0.7, 1.0, k.a));
	ALBEDO = mix(c, wc, w) * (1.0 - bank * 0.35);
	ROUGHNESS = mix(0.95, 0.12, w);
	SPECULAR = mix(0.25, 0.7, w);
}
"""


func _visuals() -> void:
	var m: Dictionary = Defs.MAP
	var ground: Color = m.ground
	var sh := Shader.new()
	sh.code = GROUND_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("kinds", ground_tex)
	mat.set_shader_parameter("detail", Tex.texture("ground"))
	mat.set_shader_parameter("use_detail", Settings.get_v("textures"))
	var pm := PlaneMesh.new()
	pm.size = Vector2(Defs.MAP_W, Defs.MAP_H)
	var plane := MeshInstance3D.new()
	plane.mesh = pm
	plane.material_override = mat
	plane.position.y = 0.0
	add_child(plane)
	# yollar: keskin kenarlı şeritler (zemin resminin üstünde)
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
	# tepeler: yumuşak yamaçlı höyükler
	var hill_mat := Tex.mat("ground", ground.lightened(0.04), 0.07, true)
	for s in m.get("hills", []):
		var bb := _bbox(s)
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.82
		cyl.bottom_radius = 1.12
		cyl.height = HILL_H
		cyl.radial_segments = 28
		cyl.rings = 1
		var mi := MeshInstance3D.new()
		mi.mesh = cyl
		mi.material_override = hill_mat
		mi.position = Vector3((bb[0] + bb[2]) * 0.5, HILL_H * 0.5, (bb[1] + bb[3]) * 0.5)
		mi.scale = Vector3((bb[2] - bb[0]) * 0.5, 1.0, (bb[3] - bb[1]) * 0.5)
		add_child(mi)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 6
	cone.rings = 1
	var cube := BoxMesh.new()
	_scatter(MOUNTAIN, cone, Tex.mat("rock", ground.lerp(Color(0.5, 0.46, 0.41), 0.75), 0.18, true), Vector2(2.6, 4.2), Vector2(6.0, 15.0), 2)
	_scatter(TREES, cone, Tex.mat("rock", m.get("tree_col", Color(0.2, 0.38, 0.18)), 0.5, true), Vector2(1.1, 1.6), Vector2(3.5, 5.5), 1)
	_scatter(FOREST, cone, Tex.mat("rock", m.get("tree_col", Color(0.2, 0.38, 0.18)).darkened(0.15), 0.5, true), Vector2(1.2, 1.9), Vector2(4.0, 7.5), 2)
	_scatter(RUINS, cube, Tex.mat("panel", Color(0.55, 0.52, 0.48), 0.25, true), Vector2(1.3, 1.9), Vector2(1.0, 3.2), 1)
	# harita sınırının dışı
	var outer := Models.box(self, Vector3(Defs.MAP_W + 200, 0.2, Defs.MAP_H + 200), Vector3(0, -1.2, 0), ground)
	outer.material_override = Tex.mat("ground", ground.darkened(0.45), 0.05, true)


## Hücrelere ağaç / kaya / moloz dağıtır. Harita 64 birimlik parçalara bölünür: her parça ayrı bir MultiMesh'tir,
## böylece kameranın ve gölgenin dışında kalan parçalar hiç çizilmez.
func _scatter(k: int, mesh: Mesh, material: Material, size: Vector2, hgt: Vector2, every := 1) -> void:
	const CHUNK := 32   # hücre (64 birim)
	var groups := {}
	for y in gh:
		for x in gw:
			if kind[y * gw + x] == k and (every == 1 or (x + y) % every == 0):
				var key := Vector2i(x / CHUNK, y / CHUNK)
				if not groups.has(key):
					groups[key] = []
				groups[key].append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + k
	for key in groups:
		var cells: Array = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = cells.size()
		for i in cells.size():
			var w := center(cells[i]) + Vector3(rng.randf_range(-0.6, 0.6), 0, rng.randf_range(-0.6, 0.6))
			var s := rng.randf_range(size.x, size.y)
			var h := rng.randf_range(hgt.x, hgt.y)
			var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, h, s))
			mm.set_instance_transform(i, Transform3D(b, Vector3(w.x, h * 0.5, w.z)))
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = material
		add_child(mi)
