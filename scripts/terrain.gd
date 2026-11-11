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
	for r in m.water:
		var w := Models.box(self, Vector3(r[2] - r[0], 0.06, r[3] - r[1]),
			Vector3((r[0] + r[2]) * 0.5, 0.0, (r[1] + r[3]) * 0.5), Color(0.16, 0.36, 0.55))
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		w.material_override = Tex.mat("water", Color(0.16, 0.36, 0.55), 0.06, true)
	for r in m.bridges:
		var big: bool = (r[2] - r[0]) > 12.0
		Models.box(self, Vector3(r[2] - r[0], 0.12, r[3] - r[1]),
			Vector3((r[0] + r[2]) * 0.5, 0.03, (r[1] + r[3]) * 0.5),
			m.ground.darkened(0.08) if big else Color(0.5, 0.48, 0.44))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.0
	cone.height = 1.0
	cone.radial_segments = 5
	cone.rings = 1
	var cube := BoxMesh.new()
	_scatter(MOUNTAIN, cone, Tex.mat("rock", Color(0.5, 0.46, 0.41), 0.22, true), Vector2(1.7, 2.6), Vector2(3.5, 8.5))
	_scatter(TREES, cone, Tex.mat("rock", Color(0.2, 0.42, 0.22), 0.5, true), Vector2(1.0, 1.5), Vector2(3.0, 5.0))
	_scatter(RUINS, cube, Tex.mat("panel", Color(0.55, 0.52, 0.48), 0.25, true), Vector2(1.3, 1.9), Vector2(1.0, 3.2))


func _scatter(k: int, mesh: Mesh, material: Material, size: Vector2, height: Vector2) -> void:
	var cells: Array = []
	for y in gh:
		for x in gw:
			if kind[y * gw + x] == k:
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = cells.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11 + k
	for i in cells.size():
		var w := center(cells[i]) + Vector3(rng.randf_range(-0.4, 0.4), 0, rng.randf_range(-0.4, 0.4))
		var s := rng.randf_range(size.x, size.y)
		var h := rng.randf_range(height.x, height.y)
		var b := Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(s, h, s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(w.x, h * 0.5, w.z)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = material
	add_child(mi)
