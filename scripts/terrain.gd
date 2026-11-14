class_name Terrain
extends Node3D
## Arazi: dağ, su, ağaç hattı ve yıkıntı geçilmez. Kara birimleri AStarGrid2D ile yol bulur; hava birimleri etkilenmez.
## Taktik etkiler: tepe görüş ve menzili artırır, alçak engellerin üstünden görür; orman piyadeyi gizler ve aracı
## yavaşlatır; yol hızlandırır. Dağ, ağaç hattı, yıkıntı ve binalar doğrudan atışı keser (topçu ve hava etkilenmez).
## Harita verisi Defs.MAP içindeki dikdörtgenlerden gelir.
##
## Görüntü: dikdörtgenlerden 1 m aralıklı bir yükseklik alanı üretilir (yuvarlak tepeler, sırtlı dağlar, su yatağı)
## ve tek parça arazi olarak çizilir; renk maske dokusundan shader'da karışır. Ağaç, çalı, ot ve kaya MultiMesh ile
## serpilir ve rüzgârda salınır. Oynanış ızgarası (kind) bundan etkilenmez.

const CELL := 2.0
const LAND := 0
const MOUNTAIN := 1
const WATER := 2
const TREES := 3
const RUINS := 4
const HILL := 5
const FOREST := 6
const ROAD := 7
const HILL_H := 1.2
const WATER_Y := -0.28           # su yüzeyi
const MARGIN_STEPS := [2.0, 3.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 22.0]   # harita dışı ızgara adımları
const PASSABLE := [LAND, HILL, FOREST, ROAD]

var gw := 0
var gh := 0
var kind := PackedByteArray()
var bld := PackedByteArray()     # hücreyi kaplayan bina sayısı (görüş hattını keser)
var astar := AStarGrid2D.new()
# 1 m aralıklı görsel alanlar (fw x fh örnek)
var fw := 0
var fh := 0
var hgt := PackedFloat32Array()
var f_water := PackedFloat32Array()
var fog_mats: Array = []         # savaş sisinde kararan bitki malzemeleri (Fog dokusunu verir)
var _cover := {}                 # hücre -> [[MultiMesh, sıra, Transform3D], ...]; bina kurulunca gizlenir
var _wob := PackedFloat32Array()
var _nature := true
var _far := FastNoiseLite.new()


func _ready() -> void:
	gw = int(ceil(Defs.MAP_W / CELL))
	gh = int(ceil(Defs.MAP_H / CELL))
	kind.resize(gw * gh)
	bld.resize(gw * gh)
	var m: Dictionary = Defs.MAP
	_fill(m.get("hills", []), HILL)
	_fill(m.get("forest", []), FOREST)
	_fill(m.water, WATER)
	_fill(m.rock, MOUNTAIN)
	_fill(m.trees, TREES)
	_fill(m.ruins, RUINS)
	_fill(m.bridges, LAND)
	_fill(m.get("roads", []), ROAD, LAND)
	astar.region = Rect2i(0, 0, gw, gh)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in gh:
		for x in gw:
			if not kind[y * gw + x] in PASSABLE:
				astar.set_point_solid(Vector2i(x, y), true)
	_visuals()


func _fill(rects: Array, k: int, only := -1) -> void:
	for r in rects:
		for y in gh:
			var z := (y + 0.5) * CELL - Defs.MAP_H * 0.5
			if z < r[1] or z > r[3]:
				continue
			for x in gw:
				var wx := (x + 0.5) * CELL - Defs.MAP_W * 0.5
				if wx >= r[0] and wx <= r[2] and (only < 0 or kind[y * gw + x] == only):
					kind[y * gw + x] = k


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


## Kara biriminin basacağı yükseklik: tepede arazinin kendisi, başka yerde düz zemin (köprü ve kıyı dahil).
func height(p: Vector3) -> float:
	return maxf(0.0, ground_y(p.x, p.z))


## Görsel arazi yüksekliği (su yatağında eksi). Harita dışında kenar değeri.
func ground_y(x: float, z: float) -> float:
	var fx := clampf(x + Defs.MAP_W * 0.5, 0.0, fw - 1.001)
	var fz := clampf(z + Defs.MAP_H * 0.5, 0.0, fh - 1.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var k := j * fw + i
	return lerpf(lerpf(hgt[k], hgt[k + 1], tx), lerpf(hgt[k + fw], hgt[k + fw + 1], tx), fz - j)


## Kara birimi hız çarpanı: yol hızlandırır, orman araçları çok, piyadeyi az yavaşlatır, tepe yokuştur.
func speed_mult(p: Vector3, armor: String) -> float:
	match kind_at(p):
		ROAD:
			return 1.35
		FOREST:
			return 0.85 if armor == "inf" else 0.55
		HILL:
			return 0.85
	return 1.0


## Doğrudan atış için görüş hattı. Dağ her zaman keser; ağaç hattı, yıkıntı ve binalar yalnızca tepede
## olmayan atıcı için keser. Atıcının ve hedefin hemen yanındaki hücreler sayılmaz (siper, ev, kendi binası).
func los_clear(a: Vector3, b: Vector3) -> bool:
	var dist := Vector2(a.x - b.x, a.z - b.z).length()
	if dist < 4.0:
		return true
	var high := kind_at(a) == HILL
	var n := int(dist / (CELL * 0.5))
	for i in range(1, n):
		var p := a.lerp(b, float(i) / n)
		if Vector2(p.x - a.x, p.z - a.z).length() < 2.4 or Vector2(p.x - b.x, p.z - b.z).length() < 3.0:
			continue
		var c := cell(p)
		var idx := c.y * gw + c.x
		var k := kind[idx]
		if k == MOUNTAIN:
			return false
		if not high and (k == TREES or k == RUINS or bld[idx] > 0):
			return false
	return true


func nearest_free(p: Vector3) -> Vector3:
	var q := Vector3(
		clampf(p.x, -Defs.MAP_W * 0.5 + 1.0, Defs.MAP_W * 0.5 - 1.0), 0,
		clampf(p.z, -Defs.MAP_H * 0.5 + 1.0, Defs.MAP_H * 0.5 - 1.0))
	var c := cell(q)
	if not astar.is_point_solid(c):
		return q
	for r in range(1, 20):
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


# ---------------------------------------------------------------- görüntü

## Dikdörtgenlerin yumuşak kenarlı etki alanı: içeride 1'e, dışarıda 0'a gider. t iç derinliktir (dışarıda eksi);
## lo..hi arası yumuşak geçer, köşeler yuvarlanır, kenar gürültüyle bozulur. Harita kenarına dayanan kenar sonsuz sayılır.
func _blend(rects: Array, lo: float, hi: float, wob: float, rnd := 4.0) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(fw * fh)
	var hw := Defs.MAP_W * 0.5
	var hh := Defs.MAP_H * 0.5
	var m := maxf(0.0, -lo) + wob + 1.0
	for r in rects:
		var x0: float = r[0] if r[0] > -hw + 0.5 else -1e5
		var z0: float = r[1] if r[1] > -hh + 0.5 else -1e5
		var x1: float = r[2] if r[2] < hw - 0.5 else 1e5
		var z1: float = r[3] if r[3] < hh - 0.5 else 1e5
		# Bir kenarı boydan boya komşu dikdörtgene dayanıyorsa o kenar içeri uzatılır; ikisi tek parça görünür.
		for o in rects:
			if o == r:
				continue
			if o[0] <= r[0] + 0.1 and o[2] >= r[2] - 0.1:
				if absf(o[3] - r[1]) < 0.6:
					z0 -= 8.0
				if absf(o[1] - r[3]) < 0.6:
					z1 += 8.0
			if o[1] <= r[1] + 0.1 and o[3] >= r[3] - 0.1:
				if absf(o[2] - r[0]) < 0.6:
					x0 -= 8.0
				if absf(o[0] - r[2]) < 0.6:
					x1 += 8.0
		var rr := minf(rnd, minf(x1 - x0, z1 - z0) * 0.5)
		for j in range(clampi(int(r[1] - m + hh), 0, fh - 1), clampi(int(r[3] + m + hh) + 1, 0, fh - 1) + 1):
			var z := j - hh
			var dz := minf(z - z0, z1 - z)
			for i in range(clampi(int(r[0] - m + hw), 0, fw - 1), clampi(int(r[2] + m + hw) + 1, 0, fw - 1) + 1):
				var x := i - hw
				var dx := minf(x - x0, x1 - x)
				var t := minf(dx, dz)
				if dx < rr and dz < rr:
					t = rr - sqrt((rr - dx) * (rr - dx) + (rr - dz) * (rr - dz))
				var k := j * fw + i
				var v := smoothstep(lo, hi, t + wob * _wob[k])
				if v > out[k]:
					out[k] = v
	return out


func _visuals() -> void:
	var m: Dictionary = Defs.MAP
	var ground: Color = m.ground
	_nature = Settings.get_v("nature")
	var hw := Defs.MAP_W * 0.5
	var hh := Defs.MAP_H * 0.5
	fw = int(Defs.MAP_W) + 1
	fh = int(Defs.MAP_H) + 1
	var n := FastNoiseLite.new()
	n.seed = 23
	n.frequency = 0.11
	n.fractal_octaves = 2
	var ridge := FastNoiseLite.new()
	ridge.seed = 41
	ridge.frequency = 0.085
	ridge.fractal_octaves = 3
	_wob.resize(fw * fh)
	for j in fh:
		for i in fw:
			_wob[j * fw + i] = n.get_noise_2d(i, j)
	# Köprüler: genişleri geçit (toprak dolgu), darları gerçek köprüdür (altından su akar).
	var fords: Array = []
	var spans: Array = []
	for r in m.bridges:
		if maxf(r[2] - r[0], r[3] - r[1]) > 12.0:
			fords.append(r)
		else:
			spans.append(r)
	var f_hill := _blend(m.get("hills", []), -1.6, 3.8, 0.9, 5.0)
	var f_rock := _blend(m.rock, -0.8, 3.6, 0.7, 3.0)
	var f_ford := _blend(fords, -1.6, 0.8, 0.3, 1.0)
	f_water = _blend(m.water, -0.9, 2.4, 0.6, 3.0)
	var f_sand := _blend(m.water, -4.2, -0.4, 1.3, 3.0)
	var f_road := _blend(m.get("roads", []) + fords, -0.7, 0.5, 0.3, 0.5)
	var f_wood := _blend(m.get("forest", []) + m.trees, -2.6, 0.6, 1.2, 3.0)
	hgt.resize(fw * fh)
	var mask := PackedByteArray()
	mask.resize(fw * fh * 4)
	for j in fh:
		for i in fw:
			var k := j * fw + i
			var w := f_water[k] * (1.0 - f_ford[k])
			f_water[k] = w
			var rg := 1.0 - absf(ridge.get_noise_2d(i, j))
			var h := f_hill[k] * (2.5 + 0.5 * _wob[k])
			h += f_rock[k] * (1.4 + 5.8 * rg * rg * rg + 0.9 * _wob[k])
			h = lerpf(h, -1.5, w)
			hgt[k] = h
			mask[k * 4] = int(f_road[k] * (1.0 - w) * 255.0)
			mask[k * 4 + 1] = int(f_wood[k] * 255.0)
			mask[k * 4 + 2] = int(f_sand[k] * (1.0 - f_rock[k]) * 255.0)
			mask[k * 4 + 3] = int(f_rock[k] * 255.0)
	var mask_tex := ImageTexture.create_from_image(Image.create_from_data(fw, fh, false, Image.FORMAT_RGBA8, mask))

	# Arazi ağı: harita içinde 1 m, dışında giderek seyrelen adımlar. Dışarıda uzak tepeler yükselir.
	var xs := _axis(hw)
	var zs := _axis(hh)
	var nx := xs.size()
	var nz := zs.size()
	_far.seed = 9
	_far.frequency = 0.012
	_far.fractal_octaves = 3
	var ys := PackedFloat32Array()
	ys.resize(nx * nz)
	for j in nz:
		var fj := clampi(int(round(zs[j] + hh)), 0, fh - 1)
		for i in nx:
			var fi := clampi(int(round(xs[i] + hw)), 0, fw - 1)
			var h := hgt[fj * fw + fi]
			var od := maxf(absf(xs[i]) - hw, absf(zs[j]) - hh)
			if od > 0.0 and h > WATER_Y:
				var dry := 1.0 - f_water[fj * fw + fi]
				h += dry * smoothstep(4.0, 90.0, od) * (1.5 + 5.5 * (_far.get_noise_2d(xs[i], zs[j]) * 0.5 + 0.5)) \
					+ dry * smoothstep(0.0, 12.0, od) * 0.35 * n.get_noise_2d(xs[i] * 0.4, zs[j] * 0.4)
			ys[j * nx + i] = h
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	verts.resize(nx * nz)
	norms.resize(nx * nz)
	for j in nz:
		var ja := maxi(j - 1, 0)
		var jb := mini(j + 1, nz - 1)
		for i in nx:
			var ia := maxi(i - 1, 0)
			var ib := mini(i + 1, nx - 1)
			var k := j * nx + i
			verts[k] = Vector3(xs[i], ys[k], zs[j])
			norms[k] = Vector3(
				-(ys[j * nx + ib] - ys[j * nx + ia]) / (xs[ib] - xs[ia]), 1.0,
				-(ys[jb * nx + i] - ys[ja * nx + i]) / (zs[jb] - zs[ja])).normalized()
	var idx := PackedInt32Array()
	idx.resize((nx - 1) * (nz - 1) * 6)
	var wmap := PackedInt32Array()      # arazi köşesi -> su ağı köşesi
	wmap.resize(nx * nz)
	wmap.fill(-1)
	var wv := PackedVector3Array()
	var wc := PackedColorArray()
	var wn := PackedVector3Array()
	var widx := PackedInt32Array()
	var sidx := PackedInt32Array()      # gölge düşüren yüksek kesimler (tepe ve dağ)
	var q := 0
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			idx[q] = a
			idx[q + 1] = b
			idx[q + 2] = c
			idx[q + 3] = b
			idx[q + 4] = d
			idx[q + 5] = c
			q += 6
			if maxf(maxf(ys[a], ys[b]), maxf(ys[c], ys[d])) > 0.5 and i > MARGIN_STEPS.size() - 4 and i < nx - MARGIN_STEPS.size() + 3:
				sidx.append_array(PackedInt32Array([a, b, c, b, d, c]))
			if minf(minf(ys[a], ys[b]), minf(ys[c], ys[d])) < WATER_Y:
				for k in [a, b, c, b, d, c]:
					if wmap[k] < 0:
						wmap[k] = wv.size()
						wv.append(Vector3(verts[k].x, WATER_Y, verts[k].z))
						wn.append(Vector3.UP)
						wc.append(Color(clampf((WATER_Y - ys[k]) / 1.1, 0.0, 1.0), 0, 0))
					widx.append(wmap[k])
	var land := MeshInstance3D.new()
	land.mesh = _mesh(verts, norms, idx)
	# Arazinin tamamı gölge geçişine girmesin diye yalnızca yüksek kesimler ayrı bir ağla gölge düşürür.
	land.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if not sidx.is_empty():
		var caster := MeshInstance3D.new()
		caster.mesh = _mesh(verts, norms, sidx)
		caster.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(caster)
	var tm := Scenery.shader_mat(Scenery.TERRAIN_SHADER)
	tm.set_shader_parameter("mask_tex", mask_tex)
	tm.set_shader_parameter("noise_tex", Tex.texture("noise"))
	tm.set_shader_parameter("rock_tex", Tex.texture("rock"))
	tm.set_shader_parameter("bump_tex", Tex.texture("bump"))
	tm.set_shader_parameter("grass", ground)
	tm.set_shader_parameter("lush", ground.lerp(Color(ground.r * 0.72, ground.g * 0.9, ground.b * 0.7), 0.3 if ground.r > ground.g + 0.04 else 0.8))
	tm.set_shader_parameter("dry", m.patch)
	tm.set_shader_parameter("dirt", ground.lerp(Color(0.5, 0.43, 0.33), 0.75))
	tm.set_shader_parameter("floor_col", ground.lerp(Color(0.15, 0.22, 0.1), 0.6))
	tm.set_shader_parameter("sand", ground.lerp(Color(0.74, 0.67, 0.5), 0.7))
	tm.set_shader_parameter("earth", ground.lerp(Color(0.42, 0.34, 0.24), 0.65))
	tm.set_shader_parameter("rock", Color(0.47, 0.44, 0.4).lerp(ground, 0.2))
	tm.set_shader_parameter("map_size", Vector2(Defs.MAP_W, Defs.MAP_H))
	tm.set_shader_parameter("water_y", WATER_Y)
	land.material_override = tm
	add_child(land)
	if not widx.is_empty():
		var water := MeshInstance3D.new()
		water.mesh = _mesh(wv, wn, widx, wc)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var wm := Scenery.shader_mat(Scenery.WATER_SHADER)
		wm.set_shader_parameter("noise_tex", Tex.texture("noise"))
		wm.set_shader_parameter("bump_tex", Tex.texture("bump"))
		wm.set_shader_parameter("deep", Color(0.07, 0.2, 0.3))
		wm.set_shader_parameter("shallow", Color(0.17, 0.4, 0.46))
		wm.set_shader_parameter("bank", ground.lerp(Color(0.5, 0.5, 0.36), 0.6).darkened(0.25))
		wm.set_shader_parameter("map_size", Vector2(Defs.MAP_W, Defs.MAP_H))
		water.material_override = wm
		add_child(water)
	for r in spans:
		_bridge(r)
	_flora(m, ground)


## Bir eksenin köşe konumları: harita içinde 1 m aralık, dışında MARGIN_STEPS.
func _axis(half: float) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	var edge := 0.0
	for s in MARGIN_STEPS:
		edge += s
	var p := -half - edge
	for i in range(MARGIN_STEPS.size() - 1, -1, -1):
		out.append(p)
		p += MARGIN_STEPS[i]
	for i in int(half * 2.0) + 1:
		out.append(-half + i)
	p = half
	for s in MARGIN_STEPS:
		p += s
		out.append(p)
	return out


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


## Savaş sisi için araziye oturan seyrek ağ (2 m). UV harita koordinatıdır.
func drape_mesh(lift: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in gh + 1:
		for x in gw + 1:
			var wx := x * CELL - Defs.MAP_W * 0.5
			var wz := y * CELL - Defs.MAP_H * 0.5
			st.set_uv(Vector2(float(x) / gw, float(y) / gh))
			st.add_vertex(Vector3(wx, maxf(ground_y(wx, wz), WATER_Y) + lift, wz))
	for y in gh:
		for x in gw:
			var a := y * (gw + 1) + x
			var b := a + gw + 1
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(b)
			st.add_index(a + 1)
			st.add_index(b + 1)
			st.add_index(b)
	return st.commit()


## Dar köprü: tabliye, korkuluk ve ayaklar. Uzun kenar suyu geçer.
func _bridge(r: Array) -> void:
	var w: float = r[2] - r[0]
	var h: float = r[3] - r[1]
	var c := Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5)
	var root := Node3D.new()
	root.position = c
	var span := w
	var wide := h
	if h > w:
		root.rotation.y = PI * 0.5
		span = h
		wide = w
	add_child(root)
	var conc := Tex.mat("concrete", Color(0.56, 0.54, 0.5), 0.2, true)
	var deck := Models.box(root, Vector3(span + 1.0, 0.5, wide), Vector3(0, -0.2, 0), Color.WHITE)
	deck.material_override = conc
	var lane := Models.box(root, Vector3(span + 1.0, 0.04, wide - 1.6), Vector3(0, 0.06, 0), Color.WHITE)
	lane.material_override = Tex.mat("ground", Color(0.3, 0.3, 0.3), 0.3, true)
	lane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for s in [-1.0, 1.0]:
		var rail := Models.box(root, Vector3(span + 1.0, 0.12, 0.14), Vector3(0, 0.85, s * (wide * 0.5 - 0.25)), Color.WHITE)
		rail.material_override = conc
		var curb := Models.box(root, Vector3(span + 1.0, 0.22, 0.5), Vector3(0, 0.14, s * (wide * 0.5 - 0.25)), Color.WHITE)
		curb.material_override = conc
		var posts := int(span / 1.6)
		for i in posts + 1:
			var px := -span * 0.5 + i * span / posts
			Models.box(root, Vector3(0.14, 0.7, 0.14), Vector3(px, 0.5, s * (wide * 0.5 - 0.25)), Color.WHITE).material_override = conc
	for i in 3:
		var px := (i - 1) * span * 0.3
		Models.box(root, Vector3(0.9, 1.8, wide - 0.8), Vector3(px, -1.2, 0), Color.WHITE).material_override = conc


func _plant_mat() -> ShaderMaterial:
	var pm := Scenery.shader_mat(Scenery.PLANT_SHADER)
	pm.set_shader_parameter("map_size", Vector2(Defs.MAP_W, Defs.MAP_H))
	pm.set_shader_parameter("wind", 1.0 if _nature else 0.0)
	fog_mats.append(pm)
	return pm


## Bitki örtüsü, kaya ve yıkıntı. Harita rengine göre iklim seçilir: kurak (hurma), dağlık (çam) ya da ılıman (karışık).
func _flora(m: Dictionary, ground: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var arid: bool = ground.r > ground.g + 0.04
	var alpine: bool = not arid and m.rock.size() >= 6
	var line_trees: Array = ["palm"] if arid else (["conifer", "conifer", "leafy"] if alpine else ["poplar", "poplar", "leafy"])
	var wood_trees: Array = ["palm"] if arid else (["conifer"] if alpine else ["leafy", "conifer", "leafy"])
	var tint := Color(1.0, 0.95, 0.8) if arid else Color.WHITE
	var trees := {}   # tür -> [[Transform3D, Color], ...]
	var small := {}   # ot, çalı, kaya: [Transform3D, Color, hücre]
	for k in ["conifer", "leafy", "poplar", "palm"]:
		trees[k] = []
	for k in ["bush", "tuft", "rock"]:
		small[k] = []
	var keep_out: Array = []     # ikmal noktası ve evlerin çevresi temiz kalır
	for p in m.points:
		keep_out.append(Vector3(p[0], 3.5, p[1]))
	for hs in m.get("houses", []):
		keep_out.append(Vector3(hs[0], 3.2, hs[1]))
	for bp in m.bases:
		keep_out.append(Vector3(bp.x, 9.0, bp.z))
	var cover_n := FastNoiseLite.new()
	cover_n.seed = 77
	cover_n.frequency = 0.035
	for y in gh:
		for x in gw:
			var k := kind[y * gw + x]
			var cc := center(Vector2i(x, y))
			match k:
				TREES:
					_tree(trees, line_trees[rng.randi() % line_trees.size()], cc, rng, 1.05, 1.5, tint)
					if rng.randf() < 0.45:
						_tree(trees, line_trees[rng.randi() % line_trees.size()], cc + Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9)), rng, 0.6, 0.9, tint)
					if rng.randf() < 0.5:
						_small(small.bush, cc, rng, 0.8, 1.3, -1, tint)
				FOREST:
					if (x + y * 3) % 2 == 0:
						_tree(trees, wood_trees[rng.randi() % wood_trees.size()], cc, rng, 0.95, 1.55, tint)
					elif rng.randf() < 0.55:
						_small(small.bush, cc, rng, 0.6, 1.1, y * gw + x, tint)
					if rng.randf() < 0.5:
						_small(small.tuft, cc, rng, 0.5, 0.9, y * gw + x, tint)
				MOUNTAIN:
					if rng.randf() < 0.1:
						_small(small.rock, cc, rng, 0.7, 1.8, -1, Color.WHITE)
				LAND, HILL:
					var ok := true
					for ko in keep_out:
						if Vector2(cc.x - ko.x, cc.z - ko.z).length() < ko.y:
							ok = false
							break
					if not ok:
						continue
					var near := _near(x, y)
					var dens := cover_n.get_noise_2d(cc.x, cc.z) * 0.5 + 0.5
					# su kıyısında saz, ağaç dibinde çalı, dağ eteğinde kaya, çayırda ot öbekleri
					if near.has(WATER) and dens > 0.38:
						for i in rng.randi_range(0, 2):
							_small(small.tuft, cc, rng, 0.9, 1.7, y * gw + x, Color(0.95, 0.9, 0.6))
					if (near.has(TREES) or near.has(FOREST)) and rng.randf() < 0.4:
						_small(small.bush, cc, rng, 0.6, 1.2, y * gw + x, tint)
					if (near.has(MOUNTAIN) or near.has(RUINS)) and rng.randf() < 0.22:
						_small(small.rock, cc, rng, 0.5, 1.4, y * gw + x, Color.WHITE)
					if k == HILL and rng.randf() < 0.06:
						_small(small.rock, cc, rng, 0.5, 1.1, y * gw + x, Color.WHITE)
					var chance := (0.1 if arid else 0.38) * smoothstep(0.3, 0.7, dens) + (0.02 if arid else 0.05)
					if rng.randf() < chance:
						var tc := Color(1.5, 1.3, 0.75) if arid else Color(1, 1, 1).lerp(Color(1.1, 1.0, 0.7), rng.randf())
						if not arid and rng.randf() < 0.07:
							tc = [Color(1.6, 1.5, 0.5), Color(1.6, 1.6, 1.5), Color(1.5, 0.6, 0.5)][rng.randi() % 3]
						_small(small.tuft, cc, rng, 0.45, 0.85, y * gw + x, tc)
					if not arid and rng.randf() < 0.004 * (1.0 + dens * 2.0):
						_small(small.bush, cc, rng, 0.7, 1.2, y * gw + x, tint)
					elif arid and rng.randf() < 0.012:
						_small(small.bush, cc, rng, 0.4, 0.8, y * gw + x, Color(1.3, 1.2, 0.7))
	# harita dışı: seyrek ağaçlar ufku doldurur
	var hw := Defs.MAP_W * 0.5
	var hh := Defs.MAP_H * 0.5
	for i in (140 if arid else 520):
		var p := Vector3(rng.randf_range(-hw - 70.0, hw + 70.0), 0, rng.randf_range(-hh - 60.0, hh + 60.0))
		if absf(p.x) < hw + 2.0 and absf(p.z) < hh + 2.0:
			continue
		var ex := clampf(p.x, -hw, hw)
		var ez := clampf(p.z, -hh, hh)
		if f_water[clampi(int(ez + hh), 0, fh - 1) * fw + clampi(int(ex + hw), 0, fw - 1)] > 0.05 or kind_at(Vector3(ex, 0, ez)) == MOUNTAIN:
			continue
		if cover_n.get_noise_2d(p.x * 1.6, p.z * 1.6) < -0.08:
			continue
		_tree(trees, wood_trees[rng.randi() % wood_trees.size()], p, rng, 0.9, 1.6, tint, _outer_y(p))
	for k in trees:
		_emit(k, trees[k], true)
	for k in small:
		if k == "rock" or _nature:
			_emit(k, small[k], k != "tuft")
	_ruins(rng)


## Harita dışındaki bir noktanın arazi yüksekliği (ağdan okunmaz; yaklaşık, uzak tepe gürültüsü ağla aynıdır).
func _outer_y(p: Vector3) -> float:
	var od := maxf(absf(p.x) - Defs.MAP_W * 0.5, absf(p.z) - Defs.MAP_H * 0.5)
	return maxf(0.0, ground_y(p.x, p.z)) + smoothstep(4.0, 90.0, od) * (1.5 + 5.5 * (_far.get_noise_2d(p.x, p.z) * 0.5 + 0.5)) - 0.25


## Komşu hücrelerdeki arazi türleri.
func _near(x: int, y: int) -> Array:
	var out: Array = []
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q := Vector2i(x + d.x, y + d.y)
		if q.x >= 0 and q.y >= 0 and q.x < gw and q.y < gh:
			out.append(kind[q.y * gw + q.x])
	return out


func _tree(trees: Dictionary, k: String, at: Vector3, rng: RandomNumberGenerator, s0: float, s1: float, tint: Color, y := INF) -> void:
	var p := at + Vector3(rng.randf_range(-0.55, 0.55), 0, rng.randf_range(-0.55, 0.55))
	p.y = (ground_y(p.x, p.z) if y == INF else y) - 0.05
	var s := rng.randf_range(s0, s1)
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.9, 1.25), s))
	var v := rng.randf_range(0.78, 1.12)
	trees[k].append([Transform3D(b, p), Color(tint.r * v * rng.randf_range(0.92, 1.08), tint.g * v, tint.b * v * rng.randf_range(0.85, 1.0))])


func _small(list: Array, at: Vector3, rng: RandomNumberGenerator, s0: float, s1: float, cell_idx: int, tint: Color) -> void:
	var p := at + Vector3(rng.randf_range(-0.95, 0.95), 0, rng.randf_range(-0.95, 0.95))
	p.y = ground_y(p.x, p.z) - 0.04
	if p.y < WATER_Y - 0.1:
		return
	var s := rng.randf_range(s0, s1)
	var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
	var v := rng.randf_range(0.8, 1.1)
	list.append([Transform3D(b, p), Color(tint.r * v, tint.g * v, tint.b * v), cell_idx])


func _emit(k: String, list: Array, shadows: bool) -> void:
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = Scenery.mesh(k)
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_color(i, list[i][1])
		if list[i].size() > 2 and list[i][2] >= 0:
			if not _cover.has(list[i][2]):
				_cover[list[i][2]] = []
			_cover[list[i][2]].append([mm, i, list[i][0]])
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if k == "rock":
		var rm := Tex.mat("rock", Color(0.56, 0.52, 0.47).lerp(Defs.MAP.ground, 0.15), 0.3, true).duplicate()
		rm.vertex_color_use_as_albedo = true
		rm.vertex_color_is_srgb = true
		mi.material_override = rm
	else:
		mi.material_override = _plant_mat()
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Yıkıntı: ayakta kalmış duvar parçaları, devrik bloklar ve moloz.
func _ruins(rng: RandomNumberGenerator) -> void:
	var list: Array = []
	for y in gh:
		for x in gw:
			if kind[y * gw + x] != RUINS:
				continue
			var cc := center(Vector2i(x, y))
			var near := _near(x, y)
			var edge := near.count(RUINS) < 4
			# duvar: kenar hücrelerde yüksek, içeride alçak kalıntı
			var wh := rng.randf_range(1.6, 3.4) if edge else rng.randf_range(0.5, 1.4)
			var rot := (rng.randi() % 2) * PI * 0.5 + rng.randf_range(-0.08, 0.08)
			var tone := rng.randf_range(0.75, 1.05)
			var wcol := Color(0.62, 0.58, 0.53) * tone if rng.randf() < 0.7 else Color(0.6, 0.42, 0.34) * tone
			list.append([Transform3D(Basis(Vector3.UP, rot) * Basis.from_scale(Vector3(rng.randf_range(1.3, 2.0), wh, 0.38)),
				cc + Vector3(rng.randf_range(-0.4, 0.4), wh * 0.5, rng.randf_range(-0.4, 0.4))), wcol])
			if edge and rng.randf() < 0.6:
				var h2 := wh * rng.randf_range(0.35, 0.7)
				list.append([Transform3D(Basis(Vector3.UP, rot + PI * 0.5) * Basis.from_scale(Vector3(rng.randf_range(0.9, 1.6), h2, 0.38)),
					cc + Vector3(rng.randf_range(-0.6, 0.6), h2 * 0.5, rng.randf_range(-0.6, 0.6))), wcol])
			for i in 3:
				var s := rng.randf_range(0.25, 0.7)
				var bb := Basis.from_euler(Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))) * Basis.from_scale(Vector3(s * 1.4, s * 0.7, s))
				list.append([Transform3D(bb, cc + Vector3(rng.randf_range(-0.9, 0.9), s * 0.2, rng.randf_range(-0.9, 0.9))),
					Color(0.5, 0.48, 0.45) * rng.randf_range(0.7, 1.1)])
	if list.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = BoxMesh.new()
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i][0])
		mm.set_instance_color(i, Color(list[i][1].r, list[i][1].g, list[i][1].b))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var rm: StandardMaterial3D = Tex.mat("concrete", Color.WHITE, 0.3, true).duplicate()
	rm.vertex_color_use_as_albedo = true
	rm.vertex_color_is_srgb = true
	mi.material_override = rm
	add_child(mi)
