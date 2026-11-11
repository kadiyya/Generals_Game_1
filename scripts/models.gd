class_name Models
extends RefCounted
## Bütün modeller kutu, silindir ve prizmadan kodla üretilir. Ön taraf +Z yönüdür.

const BODY: Array[Color] = [Color(0.30, 0.38, 0.26), Color(0.60, 0.52, 0.38)]
const DARK := Color(0.13, 0.13, 0.14)
const GREY := Color(0.6, 0.62, 0.66)
const CONCRETE := Color(0.5, 0.5, 0.48)
const WOOD := Color(0.45, 0.33, 0.2)

static var _mats := {}


static func mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[k] = m
	return _mats[k]


static func glow(c: Color) -> StandardMaterial3D:
	var k := "g" + c.to_html()
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mats[k] = m
	return _mats[k]


static func box(p: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat(c)
	m.position = pos
	m.rotation_degrees = rot
	p.add_child(m)
	return m


static func cyl(p: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, rot := Vector3.ZERO, sides := 8) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := CylinderMesh.new()
	b.top_radius = r_top
	b.bottom_radius = r_bot
	b.height = h
	b.radial_segments = sides
	b.rings = 1
	m.mesh = b
	m.material_override = mat(c)
	m.position = pos
	m.rotation_degrees = rot
	p.add_child(m)
	return m


static func ball(p: Node3D, r: float, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := SphereMesh.new()
	b.radius = r
	b.height = r * 2.0
	b.radial_segments = 8
	b.rings = 4
	m.mesh = b
	m.material_override = mat(c)
	m.position = pos
	p.add_child(m)
	return m


static func prism(p: Node3D, size: Vector3, pos: Vector3, c: Color, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var b := PrismMesh.new()
	b.size = size
	m.mesh = b
	m.material_override = mat(c)
	m.position = pos
	m.rotation_degrees = rot
	p.add_child(m)
	return m


static func ring(r: float, c := Color(0.3, 1.0, 0.4)) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r
	t.outer_radius = r + 0.18
	t.rings = 28
	t.ring_segments = 4
	m.mesh = t
	m.material_override = glow(c)
	m.position.y = 0.12
	m.scale.y = 0.2
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return m


static func build(id: String, team: int) -> Node3D:
	var n := Node3D.new()
	var tc: Color = Defs.TEAM_COLORS[team]
	var bc: Color = BODY[team]
	match id:
		"manga":
			for o in [Vector3(-0.45, 0, 0.45), Vector3(0.45, 0, 0.45), Vector3(-0.45, 0, -0.45), Vector3(0.45, 0, -0.45)]:
				_soldier(n, o, bc, tc, false)
		"tanksavar":
			for o in [Vector3(-0.4, 0, 0.0), Vector3(0.4, 0, 0.0)]:
				_soldier(n, o, bc, tc, true)
		"tank":
			_tracks(n, 2.2, 3.6)
			box(n, Vector3(2.0, 0.6, 3.4), Vector3(0, 0.6, 0), bc)
			box(n, Vector3(1.5, 0.5, 1.9), Vector3(0, 1.15, -0.2), bc)
			box(n, Vector3(1.0, 0.08, 0.7), Vector3(0, 1.44, -0.3), tc)
			cyl(n, 0.1, 0.1, 2.5, Vector3(0, 1.15, 1.9), DARK, Vector3(90, 0, 0))
		"obus":
			_tracks(n, 2.4, 4.0)
			box(n, Vector3(2.2, 0.7, 3.8), Vector3(0, 0.65, 0), bc)
			box(n, Vector3(2.0, 0.9, 2.4), Vector3(0, 1.45, -0.5), bc)
			box(n, Vector3(1.2, 0.08, 0.9), Vector3(0, 1.94, -0.5), tc)
			cyl(n, 0.13, 0.15, 3.8, Vector3(0, 2.1, 2.2), DARK, Vector3(70, 0, 0))
		"korkut":
			_tracks(n, 2.2, 3.6)
			box(n, Vector3(2.0, 0.6, 3.4), Vector3(0, 0.6, 0), bc)
			box(n, Vector3(1.3, 0.6, 1.3), Vector3(0, 1.2, 0), bc)
			box(n, Vector3(0.9, 0.08, 0.6), Vector3(0, 1.54, -0.2), tc)
			cyl(n, 0.07, 0.07, 1.9, Vector3(-0.3, 1.75, 0.9), DARK, Vector3(55, 0, 0))
			cyl(n, 0.07, 0.07, 1.9, Vector3(0.3, 1.75, 0.9), DARK, Vector3(55, 0, 0))
			box(n, Vector3(0.8, 0.45, 0.1), Vector3(0, 1.9, -0.6), GREY, Vector3(-15, 0, 0))
		"kesif":
			# Global Hawk: kambur burun, çok uzun düz kanat, V kuyruk, sırtta motor
			box(n, Vector3(0.6, 0.5, 3.4), Vector3(0, 0, 0), GREY)
			ball(n, 0.5, Vector3(0, 0.18, 1.5), GREY)
			box(n, Vector3(9.0, 0.08, 0.65), Vector3(0, -0.05, -0.2), GREY)
			box(n, Vector3(0.9, 0.1, 0.67), Vector3(-4.1, -0.05, -0.2), tc)
			box(n, Vector3(0.9, 0.1, 0.67), Vector3(4.1, -0.05, -0.2), tc)
			box(n, Vector3(0.08, 1.0, 0.55), Vector3(-0.38, 0.5, -1.5), tc, Vector3(0, 0, 35))
			box(n, Vector3(0.08, 1.0, 0.55), Vector3(0.38, 0.5, -1.5), tc, Vector3(0, 0, -35))
			cyl(n, 0.24, 0.24, 1.0, Vector3(0, 0.45, -1.0), DARK, Vector3(90, 0, 0))
		"tb2":
			# Bayraktar TB2: ince gövde, düz kanat, çift kuyruk bomu, ters V kuyruk, itici pervane
			box(n, Vector3(0.42, 0.38, 2.4), Vector3(0, 0, 0.2), GREY)
			ball(n, 0.24, Vector3(0, 0, 1.4), GREY)
			box(n, Vector3(5.4, 0.07, 0.55), Vector3(0, 0.1, 0.2), GREY)
			box(n, Vector3(0.6, 0.09, 0.57), Vector3(-2.4, 0.1, 0.2), tc)
			box(n, Vector3(0.6, 0.09, 0.57), Vector3(2.4, 0.1, 0.2), tc)
			box(n, Vector3(0.09, 0.09, 1.7), Vector3(-0.7, 0.1, -0.9), GREY)
			box(n, Vector3(0.09, 0.09, 1.7), Vector3(0.7, 0.1, -0.9), GREY)
			box(n, Vector3(0.07, 0.95, 0.4), Vector3(-0.35, 0.42, -1.6), tc, Vector3(0, 0, -48))
			box(n, Vector3(0.07, 0.95, 0.4), Vector3(0.35, 0.42, -1.6), tc, Vector3(0, 0, 48))
			cyl(n, 0.4, 0.4, 0.04, Vector3(0, 0, -1.05), DARK, Vector3(90, 0, 0))
			box(n, Vector3(0.1, 0.1, 0.5), Vector3(-1.2, -0.05, 0.2), DARK)
			box(n, Vector3(0.1, 0.1, 0.5), Vector3(1.2, -0.05, 0.2), DARK)
		"hq":
			box(n, Vector3(8.0, 2.2, 8.0), Vector3(0, 1.1, 0), CONCRETE)
			box(n, Vector3(8.15, 0.45, 8.15), Vector3(0, 1.9, 0), tc)
			box(n, Vector3(5.0, 1.6, 5.0), Vector3(0, 3.0, 0), CONCRETE)
			box(n, Vector3(5.1, 0.3, 5.1), Vector3(0, 3.7, 0), tc)
			cyl(n, 0.15, 0.15, 3.5, Vector3(1.6, 5.5, 1.6), DARK)
			box(n, Vector3(1.6, 0.9, 0.06), Vector3(2.45, 6.7, 1.6), tc)
			cyl(n, 0.9, 0.2, 0.5, Vector3(-1.4, 4.2, -1.4), GREY, Vector3(25, 0, 0))
		"santral":
			box(n, Vector3(4.2, 1.6, 3.0), Vector3(0, 0.8, -0.8), CONCRETE)
			box(n, Vector3(4.3, 0.3, 3.1), Vector3(0, 1.45, -0.8), tc)
			cyl(n, 0.7, 1.05, 2.8, Vector3(-1.1, 1.4, 1.4), GREY)
			cyl(n, 0.7, 1.05, 2.8, Vector3(1.1, 1.4, 1.4), GREY)
		"kisla":
			box(n, Vector3(5.2, 1.6, 3.6), Vector3(0, 0.8, 0), CONCRETE)
			prism(n, Vector3(5.4, 1.1, 3.8), Vector3(0, 2.15, 0), tc)
			box(n, Vector3(1.0, 1.2, 0.1), Vector3(0, 0.6, 1.82), DARK)
		"fabrika":
			box(n, Vector3(5.6, 2.2, 5.2), Vector3(0, 1.1, 0), CONCRETE)
			box(n, Vector3(5.7, 0.35, 5.3), Vector3(0, 2.0, 0), tc)
			for i in 3:
				prism(n, Vector3(5.6, 0.9, 1.7), Vector3(0, 2.65, -1.75 + i * 1.75), GREY)
			box(n, Vector3(2.4, 1.6, 0.1), Vector3(0, 0.8, 2.62), DARK)
			cyl(n, 0.3, 0.3, 2.0, Vector3(2.2, 3.2, -2.0), DARK)
		"iha":
			box(n, Vector3(4.0, 1.4, 3.6), Vector3(-1.2, 0.7, 0), CONCRETE)
			var roof := cyl(n, 2.0, 2.0, 3.6, Vector3(-1.2, 1.4, 0), GREY, Vector3(90, 0, 0), 10)
			roof.scale = Vector3(1.0, 1.0, 0.45)
			box(n, Vector3(4.1, 0.25, 3.7), Vector3(-1.2, 1.3, 0), tc)
			box(n, Vector3(1.8, 0.06, 6.8), Vector3(2.4, 0.05, 0), DARK)
			box(n, Vector3(0.15, 0.07, 5.8), Vector3(2.4, 0.06, 0), GREY)
			cyl(n, 0.08, 0.08, 2.4, Vector3(-2.8, 2.6, -1.4), DARK)
			cyl(n, 0.6, 0.15, 0.35, Vector3(-2.8, 3.8, -1.4), GREY, Vector3(30, 0, 0))
		"hisar":
			box(n, Vector3(2.6, 0.5, 2.6), Vector3(0, 0.25, 0), bc)
			box(n, Vector3(2.7, 0.15, 2.7), Vector3(0, 0.5, 0), tc)
			box(n, Vector3(1.5, 1.0, 2.0), Vector3(0, 1.4, 0), bc, Vector3(-45, 0, 0))
			for x in [-0.4, 0.4]:
				for y in [-0.25, 0.25]:
					cyl(n, 0.16, 0.16, 2.2, Vector3(x, 1.5 + y, 0.2 + y), GREY, Vector3(45, 0, 0))
			cyl(n, 0.07, 0.07, 2.2, Vector3(-1.0, 1.6, -1.0), DARK)
			box(n, Vector3(0.9, 0.5, 0.1), Vector3(-1.0, 2.8, -1.0), GREY)
	return n


static func _soldier(n: Node3D, o: Vector3, bc: Color, tc: Color, launcher: bool) -> void:
	var s := Node3D.new()
	s.position = o
	n.add_child(s)
	box(s, Vector3(0.34, 0.6, 0.24), Vector3(0, 0.55, 0), bc)
	box(s, Vector3(0.3, 0.3, 0.22), Vector3(0, 0.15, 0), DARK)
	ball(s, 0.17, Vector3(0, 1.0, 0), tc)
	if launcher:
		cyl(s, 0.09, 0.09, 1.0, Vector3(0.24, 0.95, 0.1), DARK, Vector3(90, 0, 0))
	else:
		box(s, Vector3(0.06, 0.06, 0.6), Vector3(0.2, 0.65, 0.25), DARK)


static func _tracks(n: Node3D, w: float, l: float) -> void:
	box(n, Vector3(0.5, 0.5, l), Vector3(-w * 0.5 + 0.1, 0.27, 0), DARK)
	box(n, Vector3(0.5, 0.5, l), Vector3(w * 0.5 - 0.1, 0.27, 0), DARK)


static func crane() -> Node3D:
	var n := Node3D.new()
	var y := Color(0.9, 0.7, 0.1)
	box(n, Vector3(0.9, 0.3, 0.9), Vector3(0, 0.15, 0), DARK)
	box(n, Vector3(0.3, 6.0, 0.3), Vector3(0, 3.0, 0), y)
	box(n, Vector3(4.5, 0.25, 0.25), Vector3(-1.5, 5.8, 0), y)
	box(n, Vector3(0.6, 0.5, 0.6), Vector3(1.0, 5.6, 0), DARK)
	box(n, Vector3(0.05, 2.2, 0.05), Vector3(-3.2, 4.6, 0), DARK)
	return n


static func supply_point(oil: bool) -> Node3D:
	var n := Node3D.new()
	cyl(n, 3.0, 3.0, 0.08, Vector3(0, 0.04, 0), Color(0.5, 0.47, 0.4), Vector3.ZERO, 16)
	if oil:
		# petrol kulesi
		for a in 4:
			var ang := a * PI * 0.5 + PI * 0.25
			var bx := box(n, Vector3(0.14, 4.4, 0.14), Vector3(cos(ang) * 0.6, 2.1, sin(ang) * 0.6 - 0.6), DARK)
			bx.rotation = Vector3(-sin(ang) * 0.27, 0, cos(ang) * 0.27)
		box(n, Vector3(0.7, 0.25, 0.7), Vector3(0, 4.2, -0.6), DARK)
		cyl(n, 0.9, 0.9, 1.4, Vector3(1.5, 0.7, 0.8), GREY)
		cyl(n, 0.9, 0.9, 1.4, Vector3(-1.5, 0.7, 0.8), GREY)
	else:
		box(n, Vector3(1.0, 0.8, 1.0), Vector3(-0.9, 0.4, -0.5), WOOD)
		box(n, Vector3(1.0, 0.8, 1.0), Vector3(0.3, 0.4, -0.9), WOOD)
		box(n, Vector3(0.9, 0.7, 0.9), Vector3(-0.3, 1.15, -0.7), WOOD)
		box(n, Vector3(1.4, 0.5, 0.8), Vector3(0.9, 0.25, 0.6), Color(0.3, 0.36, 0.25))
	cyl(n, 0.07, 0.07, 4.0, Vector3(-1.9, 2.0, 1.6), DARK)
	return n
