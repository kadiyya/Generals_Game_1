class_name MapPreview
extends Control
## Menüde senaryonun haritası: arazi resmi (nehirler, ormanlar, dağlar, yollar), iki tarafın üsleri,
## köprüler, noktalar ve görev noktası. Arazi bir kez üretilir ve önbellekte tutulur.

static var _cache := {}

var scn: Dictionary = {}
var map: Dictionary = {}
var tex: Texture2D
var grid: Dictionary = {}
var t := 0.0


func setup(s: Dictionary) -> void:
	scn = s
	map = Scenarios.map_def(s.map)
	custom_minimum_size = Vector2(330, 202)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _cache.has(s.map):
		var g := Terrain.build_grid(map)
		var img := Terrain.make_image(map, g)
		for y in img.get_height():
			for x in img.get_width():
				var c := img.get_pixel(x, y)
				if c.a > 0.5:
					c = Color(0.16, 0.34, 0.55)
				elif g.kind[y * int(g.gw) + x] == Terrain.MOUNTAIN:
					c = c.lightened(0.15)
				img.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0))
		_cache[s.map] = [ImageTexture.create_from_image(img), g]
	tex = _cache[s.map][0]
	grid = _cache[s.map][1]


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _p(x: float, z: float) -> Vector2:
	var sz: Vector2 = map.size
	return Vector2((x / sz.x + 0.5) * size.x, (z / sz.y + 0.5) * size.y)


func _draw() -> void:
	draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)
	for br in grid.bridges:
		draw_line(_p(br.a.x, br.a.y), _p(br.b.x, br.b.y), Color(0.9, 0.86, 0.72), 3.0)
	for p in map.points:
		var c := _p(p[0], p[1])
		draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), Color(1, 1, 1, 0.85), false, 1.5)
	# görev noktası: tutma görevlerinde yanıp sönen altın halka
	for o in scn.get("obj", {}).values():
		if o.get("type", "") == "hold":
			var pt: Array = map.points[o.point]
			var c := _p(pt[0], pt[1])
			var r := 6.0 + fmod(t * 8.0, 10.0)
			draw_arc(c, r, 0, TAU, 20, Color(1.0, 0.82, 0.3, 1.0 - (r - 6.0) / 10.0), 2.0)
			draw_circle(c, 4.0, Color(1.0, 0.82, 0.3))
	# stratejik tesisler (senaryo görevinde): kırmızı nişangâh
	if Scenarios.GOALS[Scenarios.goal].id == "senaryo":
		for st in map.get("strategic", []):
			var sc := _p(st[0], st[1])
			draw_arc(sc, 5.0, 0, TAU, 14, Color(1.0, 0.25, 0.2), 1.6)
			draw_line(sc + Vector2(-8, 0), sc + Vector2(8, 0), Color(1.0, 0.25, 0.2), 1.2)
			draw_line(sc + Vector2(0, -8), sc + Vector2(0, 8), Color(1.0, 0.25, 0.2), 1.2)
	var sides := [[map.bases_a, Color(0.35, 0.6, 1.0), scn.a], [map.bases_b, Color(1.0, 0.35, 0.3), scn.b]]
	var font := ThemeDB.fallback_font
	for sd in sides:
		for i in sd[0].size():
			var b: Vector3 = sd[0][i]
			var c := _p(b.x, b.z)
			var r := 7.0 if i == 0 else 5.0
			draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), sd[1])
			draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), Color.BLACK, false, 1.0)
		var b0: Vector3 = sd[0][0]
		var lc := _p(b0.x, b0.z) + Vector2(-20, -12)
		var nm: String = Scenarios.COUNTRIES[sd[2]].name
		draw_string_outline(font, lc, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 4, Color(0, 0, 0, 0.9))
		draw_string(font, lc, nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, sd[1].lightened(0.3))
	draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.5), false, 1.5)
