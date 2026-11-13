class_name Terrain
extends Node3D
## Arazi: dağ ve su geçilmez. Kara birimleri AStarGrid2D ile yol bulur; hava birimleri etkilenmez.
## Harita verisi Defs içindeki dikdörtgenlerden gelir.

const CELL := 2.0
const LAND := 0
const MOUNTAIN := 1
const WATER := 2
const TREES := 3
const RUINS := 4

var gw := 0
var gh := 0
var kind := PackedByteArray()
var astar := AStarGrid2D.new()


func _ready() -> void:
	gw = int(ceil(Defs.MAP_W / CELL))
	gh = int(ceil(Defs.MAP_H / CELL))
	kind.resize(gw * gh)
	var m: Dictionary = Defs.MAP
	_fill(m.water, WATER)
	_fill(m.rock, MOUNTAIN)
	_fill(m.trees, TREES)
	_fill(m.ruins, RUINS)
	_fill(m.bridges, LAND)
	astar.region = Rect2i(0, 0, gw, gh)
	astar.cell_size = Vector2(CELL, CELL)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()
	for y in gh:
		for x in gw:
			if kind[y * gw + x] != LAND:
				astar.set_point_solid(Vector2i(x, y), true)
	_visuals()


func _fill(rects: Array, k: int) -> void:
	for r in rects:
		for y in gh:
			var z := (y + 0.5) * CELL - Defs.MAP_H * 0.5
			if z < r[1] or z > r[3]:
				continue
			for x in gw:
				var wx := (x + 0.5) * CELL - Defs.MAP_W * 0.5
				if wx >= r[0] and wx <= r[2]:
					kind[y * gw + x] = k


func cell(p: Vector3) -> Vector2i:
	return Vector2i(
		clampi(int((p.x + Defs.MAP_W * 0.5) / CELL), 0, gw - 1),
		clampi(int((p.z + Defs.MAP_H * 0.5) / CELL), 0, gh - 1))


func center(c: Vector2i) -> Vector3:
	return Vector3((c.x + 0.5) * CELL - Defs.MAP_W * 0.5, 0, (c.y + 0.5) * CELL - Defs.MAP_H * 0.5)


func solid(p: Vector3) -> bool:
	return astar.is_point_solid(cell(p))


func is_land(p: Vector3) -> bool:
	var c := cell(p)
	return kind[c.y * gw + c.x] == LAND


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
			if kind[q.y * gw + q.x] != LAND:
				continue
			if Vector2(center(q).x - p.x, center(q).z - p.z).length() <= r:
				astar.set_point_solid(q, v)


func _visuals() -> void:
	var m: Dictionary = Defs.MAP
	_ground(m)
	# su: koyu, parlak, dalgacıklı yüzey (kıyıdaki çamur zemin renginde)
	var wm := StandardMaterial3D.new()
	wm.albedo_color = Color(0.13, 0.24, 0.26)
	wm.roughness = 0.06
	wm.metallic = 0.15
	wm.normal_enabled = true
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.as_normal_map = true
	nt.bump_strength = 4.0
	var nn := FastNoiseLite.new()
	nn.frequency = 0.06
	nt.noise = nn
	wm.normal_texture = nt
	wm.normal_scale = 0.6
	wm.uv1_triplanar = true
	wm.uv1_world_triplanar = true
	wm.uv1_scale = Vector3.ONE * 0.08
	for r in m.water:
		var w := Models.box(self, Vector3(r[2] - r[0], 0.06, r[3] - r[1]),
			Vector3((r[0] + r[2]) * 0.5, 0.0, (r[1] + r[3]) * 0.5), Color(0.1, 0.2, 0.23))
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.material_override = wm
	# köprüler, yıkıntılar: kendi dikdörtgenlerine göre kurulur
	for r in m.bridges:
		var along_x := Props.bridge_along_x(m, r)
		var ln: float = (r[2] - r[0]) if along_x else (r[3] - r[1])
		var wd: float = (r[3] - r[1]) if along_x else (r[2] - r[0])
		var k := _kit(m)
		Props.bridge(k, ln, wd, wd > 12.0)
		_place(k.mesh(), Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5), 0.0 if along_x else 90.0)
	var sd := 1
	for r in m.ruins:
		var k := _kit(m)
		Props.ruin(k, r[2] - r[0], r[3] - r[1], sd)
		_place(k.mesh(), Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5), 0.0)
		sd += 1
	# ağaç, kaya, çalı, taş ve ot öbekleri: tür başına bir mesh, MultiMesh ile çoğaltılır
	var sc := Props.scatter(m, Array(kind), gw, gh, CELL, Defs.MAP_W, Defs.MAP_H)
	for id in sc:
		var k := _kit(m)
		Props.design(id, k)
		var big: bool = not (id in Props.SMALL)
		_multi(k.mesh(), sc[id], big)


func _kit(m: Dictionary) -> Kit:
	var k := Kit.new()
	k.dust = Models._dust()
	Props.slots(k, m)
	return k


func _place(mesh: Mesh, p: Vector3, yaw: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = p
	mi.rotation_degrees.y = yaw
	add_child(mi)


func _multi(mesh: Mesh, items: Array, shadow: bool) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = items.size()
	for i in items.size():
		var it: Array = items[i]
		var b := Basis(Vector3.UP, deg_to_rad(it[2])) * Basis.from_scale(Vector3(it[3], it[4], it[3]))
		mm.set_instance_transform(i, Transform3D(b, Vector3(it[0], 0, it[1])))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


## Zemin: köşe renkli tek ağ (renk geçişleri, yollar, orman tabanı, kıyı çamuru) üstünde toprak dokusu.
func _ground(m: Dictionary) -> void:
	var g := Props.ground(m, Array(kind), gw, gh, CELL, Defs.MAP_W, Defs.MAP_H, 1.25)
	var verts := PackedVector3Array(g[0])
	var cols := PackedColorArray(g[1])
	var uvs := PackedVector2Array()
	var nrm := PackedVector3Array()
	for v in verts:
		uvs.append(Vector2(v.x, v.z) * 0.07)
		nrm.append(Vector3.UP)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_COLOR] = cols
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array(g[2])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.albedo_texture = Tex.texture("ground")
	mat.roughness = 0.95
	var mi := MeshInstance3D.new()
	mi.mesh = am
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
