class_name Models
extends RefCounted
## Bütün modeller kodla üretilir (kutu, silindir, prizma ve düz çokgen levhalar). Ön taraf +Z yönüdür.
## Uçaklar JETS tablosundaki ölçülerle, gerçek siluetlerine benzeyecek şekilde kurulur.

const DARK := Color(0.13, 0.13, 0.14)
const GREY := Color(0.6, 0.62, 0.66)
const CONCRETE := Color(0.5, 0.5, 0.48)
const WOOD := Color(0.45, 0.33, 0.2)
const GLASS := Color(0.12, 0.2, 0.28)

static var _mats := {}
static var _skin := {}   # renk -> [texture türü, ölçek]: bu renkteki parçalar desenli çizilir
static var _vehicles := {}   # model + renkler -> [gövde mesh, kule mesh, kule z]: her araç bir kez kurulur

# Kanat ve yatay kuyruk: sağ yarının köşeleri (x, z). Dikey kuyruk: (z, y).
const JETS := {
	"f16": {len = 5.0, w = 0.5, h = 0.5, eng = 1, tail = "single", intake = true,
		wing = [Vector2(0.25, 0.7), Vector2(1.9, -0.5), Vector2(1.9, -0.9), Vector2(0.25, -1.1)],
		stab = [Vector2(0.25, -1.6), Vector2(1.1, -2.1), Vector2(1.1, -2.4), Vector2(0.25, -2.3)]},
	"jf17": {len = 4.8, w = 0.5, h = 0.5, eng = 1, tail = "single",
		wing = [Vector2(0.25, 0.5), Vector2(1.8, -0.6), Vector2(1.8, -0.95), Vector2(0.25, -1.1)],
		stab = [Vector2(0.25, -1.5), Vector2(1.05, -2.0), Vector2(1.05, -2.3), Vector2(0.25, -2.2)]},
	"mirage": {len = 4.9, w = 0.48, h = 0.5, eng = 1, tail = "single",
		wing = [Vector2(0.24, 0.9), Vector2(1.9, -1.9), Vector2(0.24, -2.0)]},
	"tejas": {len = 4.1, w = 0.44, h = 0.46, eng = 1, tail = "single",
		wing = [Vector2(0.22, 0.7), Vector2(1.55, -1.6), Vector2(0.22, -1.7)]},
	"mig21": {len = 4.4, w = 0.42, h = 0.44, eng = 1, tail = "single",
		wing = [Vector2(0.21, 0.4), Vector2(1.35, -1.0), Vector2(0.21, -1.1)],
		stab = [Vector2(0.21, -1.5), Vector2(0.85, -1.95), Vector2(0.21, -2.0)]},
	"j10": {len = 5.0, w = 0.5, h = 0.52, eng = 1, tail = "single", intake = true,
		wing = [Vector2(0.25, 0.3), Vector2(1.9, -1.7), Vector2(0.25, -1.9)],
		canard = [Vector2(0.25, 1.3), Vector2(1.0, 0.85), Vector2(0.25, 0.7)]},
	"rafale": {len = 5.0, w = 0.62, h = 0.5, eng = 2, tail = "single",
		wing = [Vector2(0.31, 0.5), Vector2(2.0, -1.6), Vector2(0.31, -1.9)],
		canard = [Vector2(0.31, 1.25), Vector2(0.95, 0.9), Vector2(0.31, 0.75)]},
	"f35": {len = 4.9, w = 0.8, h = 0.55, eng = 1, tail = "canted",
		wing = [Vector2(0.4, 0.5), Vector2(1.8, -0.6), Vector2(1.8, -1.0), Vector2(0.4, -1.3)],
		stab = [Vector2(0.4, -1.5), Vector2(1.3, -2.0), Vector2(1.3, -2.4), Vector2(0.4, -2.3)]},
	"f15": {len = 5.9, w = 0.85, h = 0.55, eng = 2, tail = "twin",
		wing = [Vector2(0.42, 0.9), Vector2(2.2, -0.6), Vector2(2.2, -1.1), Vector2(0.42, -1.3)],
		stab = [Vector2(0.5, -1.9), Vector2(1.5, -2.5), Vector2(1.5, -2.9), Vector2(0.5, -2.7)]},
	"f14": {len = 6.0, w = 1.15, h = 0.5, eng = 2, tail = "twin",
		wing = [Vector2(0.57, 0.7), Vector2(2.7, -1.0), Vector2(2.6, -1.5), Vector2(0.57, -0.9)],
		stab = [Vector2(0.57, -2.0), Vector2(1.5, -2.7), Vector2(1.4, -3.0), Vector2(0.57, -2.8)]},
	"f4": {len = 5.6, w = 0.7, h = 0.55, eng = 2, tail = "single",
		wing = [Vector2(0.35, 0.6), Vector2(1.9, -0.9), Vector2(1.9, -1.3), Vector2(0.35, -1.4)],
		stab = [Vector2(0.35, -2.0), Vector2(1.1, -2.5), Vector2(1.0, -2.8), Vector2(0.35, -2.6)]},
	"su35": {len = 6.4, w = 0.9, h = 0.55, eng = 2, tail = "twin",
		wing = [Vector2(0.45, 1.0), Vector2(2.5, -0.9), Vector2(2.5, -1.4), Vector2(0.45, -1.5)],
		stab = [Vector2(0.5, -2.0), Vector2(1.6, -2.9), Vector2(1.6, -3.2), Vector2(0.5, -2.9)]},
	"su30": {len = 6.4, w = 0.9, h = 0.55, eng = 2, tail = "twin",
		wing = [Vector2(0.45, 1.0), Vector2(2.5, -0.9), Vector2(2.5, -1.4), Vector2(0.45, -1.5)],
		stab = [Vector2(0.5, -2.0), Vector2(1.6, -2.9), Vector2(1.6, -3.2), Vector2(0.5, -2.9)],
		canard = [Vector2(0.45, 1.7), Vector2(1.15, 1.3), Vector2(0.45, 1.1)]},
	"su34": {len = 6.6, w = 1.1, h = 0.55, eng = 2, tail = "twin", flat_nose = true,
		wing = [Vector2(0.55, 1.0), Vector2(2.5, -0.9), Vector2(2.5, -1.4), Vector2(0.55, -1.5)],
		stab = [Vector2(0.55, -2.1), Vector2(1.6, -3.0), Vector2(1.6, -3.3), Vector2(0.55, -3.0)],
		canard = [Vector2(0.55, 1.8), Vector2(1.2, 1.4), Vector2(0.55, 1.2)]},
	"mig29": {len = 5.3, w = 0.78, h = 0.5, eng = 2, tail = "twin",
		wing = [Vector2(0.39, 0.8), Vector2(2.0, -0.7), Vector2(2.0, -1.1), Vector2(0.39, -1.2)],
		stab = [Vector2(0.42, -1.7), Vector2(1.3, -2.4), Vector2(1.3, -2.7), Vector2(0.42, -2.4)]},
	"su57": {len = 6.2, w = 1.15, h = 0.42, eng = 2, tail = "canted", flat_nose = true,
		wing = [Vector2(0.57, 1.7), Vector2(2.4, -1.0), Vector2(2.2, -1.7), Vector2(0.57, -1.9)],
		stab = [Vector2(0.6, -2.0), Vector2(1.5, -2.7), Vector2(1.3, -3.1), Vector2(0.6, -2.9)]},
}


static func mat(c: Color) -> StandardMaterial3D:
	var k := c.to_html()
	if _skin.has(k):
		return Tex.mat(_skin[k][0], c, _skin[k][1])
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


## Düz, iki yüzlü çokgen levha (kanat, kuyruk). Köşeler dışbükey ve sıralı olmalı.
static func poly(p: Node3D, verts: Array, c: Color) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, verts.size() - 1):
		var a: Vector3 = verts[0]
		var b: Vector3 = verts[i]
		var d: Vector3 = verts[i + 1]
		var n := (d - a).cross(b - a).normalized()
		for v in [a, b, d]:
			st.set_normal(n)
			st.add_vertex(v)
		for v in [a, d, b]:
			st.set_normal(-n)
			st.add_vertex(v)
	var m := MeshInstance3D.new()
	m.mesh = st.commit()
	m.material_override = mat(c)
	p.add_child(m)
	return m


## Yatay levha: sağ yarının (x, z) köşeleri verilir, sol yarı aynalanır.
static func wing(p: Node3D, pts: Array, y: float, c: Color) -> void:
	for s in [1.0, -1.0]:
		var v: Array = []
		for q in pts:
			v.append(Vector3(q.x * s, y, q.y))
		poly(p, v, c)


## Dikey levha: (z, y) köşeleri. cant derece cinsinden dışa yatıklık.
static func fin(p: Node3D, pts: Array, x: float, cant: float, c: Color) -> void:
	var t := tan(deg_to_rad(cant)) * signf(x)
	var v: Array = []
	for q in pts:
		v.append(Vector3(x + q.y * t, q.y, q.x))
	poly(p, v, c)


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


# ---------------------------------------------------------------- ana giriş

static func build(d: Dictionary, team: int) -> Node3D:
	var n := Node3D.new()
	var tc: Color = Defs.TEAM_COLORS[team]
	var cdef: Dictionary = Scenarios.COUNTRIES.get(d.get("cc", ""), {})
	var bc: Color = cdef.get("body", Color(0.33, 0.4, 0.27))
	var ac: Color = cdef.get("air", GREY)
	var id: String = d.get("model", "")
	# Gövde rengi kamuflaj, uçak rengi panel çizgili, beton panel desenli çizilir.
	_skin[bc.to_html()] = ["camo", 0.3]
	_skin[ac.to_html()] = ["panel", 0.3]
	_skin[CONCRETE.to_html()] = ["panel", 0.12]
	_skin[GREY.to_html()] = ["panel", 0.2]
	if JETS.has(id):
		_jet(n, JETS[id], ac, tc)
		return n
	match id:
		"inf":
			for o in [Vector3(-0.45, 0, 0.45), Vector3(0.45, 0, 0.45), Vector3(-0.45, 0, -0.45), Vector3(0.45, 0, -0.45)]:
				_soldier(n, o, bc, tc, false)
		"at":
			for o in [Vector3(-0.4, 0, 0.0), Vector3(0.4, 0, 0.0)]:
				_soldier(n, o, bc, tc, true)
		"tank_ru", "tank_ru2", "tank_leo", "tank_merkava":
			_vehicle(n, id, bc, tc)
		"ifv_low":
			# BMP sınıfı: alçak, sivri burun, küçük kule
			_tracks(n, 2.1, 3.5)
			box(n, Vector3(1.9, 0.6, 3.0), Vector3(0, 0.6, -0.2), bc)
			prism(n, Vector3(1.9, 0.9, 0.6), Vector3(0, 0.6, 1.7), bc, Vector3(90, 0, 0))
			var t := _turret(n)
			cyl(t, 0.5, 0.6, 0.35, Vector3(0, 1.08, -0.1), bc)
			box(t, Vector3(0.6, 0.06, 0.5), Vector3(0, 1.28, -0.1), tc)
			cyl(t, 0.06, 0.06, 1.6, Vector3(0, 1.08, 0.9), DARK, Vector3(90, 0, 0))
		"ifv_tall":
			# Bradley / Namer: yüksek kutu gövde
			_tracks(n, 2.3, 3.6)
			box(n, Vector3(2.1, 0.95, 3.4), Vector3(0, 0.8, 0), bc)
			box(n, Vector3(2.1, 0.4, 0.5), Vector3(0, 0.7, 1.75), bc, Vector3(-35, 0, 0))
			var t := _turret(n)
			box(t, Vector3(1.0, 0.45, 1.1), Vector3(0, 1.5, 0.1), bc)
			box(t, Vector3(0.7, 0.06, 0.6), Vector3(0, 1.75, 0.1), tc)
			cyl(t, 0.06, 0.06, 1.5, Vector3(0, 1.5, 1.2), DARK, Vector3(90, 0, 0))
			box(t, Vector3(0.3, 0.3, 0.7), Vector3(-0.65, 1.5, 0.1), DARK)
		"gepard":
			_tracks(n, 2.2, 3.6)
			box(n, Vector3(2.0, 0.6, 3.4), Vector3(0, 0.6, 0), bc)
			var t := _turret(n)
			box(t, Vector3(1.3, 0.7, 1.5), Vector3(0, 1.25, 0), bc)
			box(t, Vector3(0.9, 0.06, 0.6), Vector3(0, 1.62, -0.2), tc)
			for x in [-0.8, 0.8]:
				cyl(t, 0.07, 0.07, 2.0, Vector3(x, 1.45, 0.8), DARK, Vector3(60, 0, 0))
			box(t, Vector3(0.9, 0.5, 0.1), Vector3(0, 2.0, -0.7), GREY, Vector3(-15, 0, 0))
		"pantsir":
			_truck(n, bc, 4.2)
			var t := _turret(n)
			box(t, Vector3(1.5, 0.7, 1.6), Vector3(0, 1.75, -0.7), bc)
			box(t, Vector3(1.0, 0.06, 0.8), Vector3(0, 2.12, -0.7), tc)
			for x in [-0.95, 0.95]:
				for i in 3:
					cyl(t, 0.1, 0.1, 1.5, Vector3(x, 1.6 + i * 0.22, -0.4), GREY, Vector3(65, 0, 0))
				cyl(t, 0.05, 0.05, 1.6, Vector3(x * 0.8, 1.5, 0.3), DARK, Vector3(80, 0, 0))
			box(t, Vector3(0.9, 0.5, 0.1), Vector3(0, 2.5, -1.2), GREY)
		"tor":
			_tracks(n, 2.2, 3.6)
			box(n, Vector3(2.0, 0.6, 3.4), Vector3(0, 0.6, 0), bc)
			var t := _turret(n)
			box(t, Vector3(1.5, 1.2, 1.5), Vector3(0, 1.5, -0.1), bc)
			box(t, Vector3(1.0, 0.06, 0.8), Vector3(0, 2.13, -0.1), tc)
			box(t, Vector3(1.2, 0.7, 0.1), Vector3(0, 2.5, -0.8), GREY, Vector3(-10, 0, 0))
			box(t, Vector3(0.8, 0.6, 0.1), Vector3(0, 1.7, 0.7), GREY)
		"irondome":
			_truck(n, bc, 3.6)
			box(n, Vector3(1.7, 1.5, 1.7), Vector3(0, 2.0, -0.8), bc, Vector3(-35, 0, 0))
			box(n, Vector3(1.75, 0.3, 1.75), Vector3(0, 2.0, -0.8), tc, Vector3(-35, 0, 0))
			for x in [-0.5, 0.0, 0.5]:
				for y in [-0.4, 0.2]:
					cyl(n, 0.16, 0.16, 0.2, Vector3(x, 2.5 + y * 0.8, -0.2 + y * 0.6), DARK, Vector3(55, 0, 0))
		"sph":
			# Paletli kundağı motorlu obüs (Msta-S, K9, Raad-2)
			_tracks(n, 2.4, 4.0)
			box(n, Vector3(2.2, 0.7, 3.8), Vector3(0, 0.65, 0), bc)
			var t := _turret(n)
			box(t, Vector3(2.0, 0.95, 2.5), Vector3(0, 1.48, -0.5), bc)
			box(t, Vector3(1.2, 0.07, 0.9), Vector3(0, 1.98, -0.5), tc)
			cyl(t, 0.12, 0.14, 3.9, Vector3(0, 2.15, 2.3), DARK, Vector3(70, 0, 0))
		"truck_gun":
			# Kamyona monte obüs (Bohdana, CAESAR, ATMOS, SH-15)
			_truck(n, bc, 4.6)
			box(n, Vector3(0.9, 0.06, 0.7), Vector3(0, 2.02, 1.5), tc)
			box(n, Vector3(1.2, 0.6, 1.3), Vector3(0, 1.5, -1.1), bc)
			cyl(n, 0.11, 0.13, 4.2, Vector3(0, 2.4, 0.6), DARK, Vector3(68, 0, 0))
			box(n, Vector3(1.9, 0.15, 0.3), Vector3(0, 0.5, -2.4), DARK)
		"himars":
			_truck(n, bc, 4.2)
			box(n, Vector3(0.9, 0.06, 0.7), Vector3(0, 2.02, 1.3), tc)
			box(n, Vector3(1.6, 0.8, 2.2), Vector3(0, 1.75, -0.9), bc, Vector3(-28, 0, 0))
			for x in [-0.45, 0.0, 0.45]:
				for y in [-0.2, 0.2]:
					cyl(n, 0.17, 0.17, 0.15, Vector3(x, 2.25 + y, 0.2 + y * 0.5), DARK, Vector3(62, 0, 0))
		"mlrs_truck":
			_truck(n, bc, 5.0)
			box(n, Vector3(0.9, 0.06, 0.7), Vector3(0, 2.02, 1.7), tc)
			for x in [-0.55, -0.18, 0.18, 0.55]:
				for y in [0.0, 0.36, 0.72]:
					cyl(n, 0.16, 0.16, 3.0, Vector3(x, 1.75 + y * 0.9, -0.9 + y * 0.45), GREY, Vector3(64, 0, 0))
		"tos":
			_tracks(n, 2.3, 3.8)
			box(n, Vector3(2.1, 0.6, 3.6), Vector3(0, 0.6, 0), bc)
			box(n, Vector3(2.0, 1.0, 2.6), Vector3(0, 1.75, -0.2), bc, Vector3(-22, 0, 0))
			box(n, Vector3(2.05, 0.2, 2.65), Vector3(0, 1.75, -0.2), tc, Vector3(-22, 0, 0))
			for x in [-0.6, -0.2, 0.2, 0.6]:
				for y in [-0.25, 0.25]:
					cyl(n, 0.17, 0.17, 0.12, Vector3(x, 2.3 + y, 0.95 + y * 0.4), DARK, Vector3(68, 0, 0))
		"laser_truck":
			_truck(n, bc, 4.0)
			box(n, Vector3(1.8, 1.1, 2.2), Vector3(0, 1.7, -0.8), GREY)
			box(n, Vector3(1.85, 0.25, 2.25), Vector3(0, 1.5, -0.8), tc)
			cyl(n, 0.35, 0.35, 0.5, Vector3(0, 2.5, -0.8), DARK)
			cyl(n, 0.28, 0.2, 0.8, Vector3(0, 2.75, -0.5), Color(0.2, 0.75, 0.9), Vector3(70, 0, 0))
		"quad":
			_multirotor(n, 4, 0.75, tc)
		"hexa":
			_multirotor(n, 6, 1.05, tc)
			box(n, Vector3(0.25, 0.25, 0.5), Vector3(0, -0.25, 0), DARK)
		"small_plane":
			box(n, Vector3(0.22, 0.22, 1.3), Vector3(0, 0, 0), ac)
			box(n, Vector3(2.2, 0.04, 0.32), Vector3(0, 0.12, 0.15), ac)
			box(n, Vector3(0.35, 0.05, 0.34), Vector3(-0.95, 0.12, 0.15), tc)
			box(n, Vector3(0.35, 0.05, 0.34), Vector3(0.95, 0.12, 0.15), tc)
			box(n, Vector3(0.8, 0.04, 0.22), Vector3(0, 0.05, -0.6), ac)
			box(n, Vector3(0.04, 0.35, 0.25), Vector3(0, 0.2, -0.6), tc)
			cyl(n, 0.22, 0.22, 0.03, Vector3(0, 0, 0.67), DARK, Vector3(90, 0, 0))
		"xwing":
			# Lancet tipi: önde büyük, arkada küçük X kanat
			box(n, Vector3(0.18, 0.18, 1.6), Vector3(0, 0, 0), ac)
			for a in [45.0, -45.0]:
				box(n, Vector3(1.5, 0.03, 0.26), Vector3(0, 0, 0.25), ac, Vector3(0, 0, a))
				box(n, Vector3(0.8, 0.03, 0.2), Vector3(0, 0, -0.65), tc, Vector3(0, 0, a))
			cyl(n, 0.16, 0.16, 0.03, Vector3(0, 0, -0.82), DARK, Vector3(90, 0, 0))
		"shahed", "shahed_s", "liutyi":
			if id == "liutyi":
				_twinboom(n, ac, tc)
				n.scale = Vector3.ONE * 0.7
			else:
				# Shahed-136 / Geran-2: delta kanat, uçlarda dikey yüzeyler, arkada pervane
				wing(n, [Vector2(0.0, 1.5), Vector2(1.3, -0.95), Vector2(0.0, -0.95)], 0.0, ac)
				box(n, Vector3(0.32, 0.3, 2.3), Vector3(0, 0.02, 0.15), ac)
				cyl(n, 0.03, 0.16, 0.5, Vector3(0, 0.02, 1.5), ac, Vector3(90, 0, 0), 6)
				for x in [-1.3, 1.3]:
					box(n, Vector3(0.04, 0.5, 0.5), Vector3(x, 0.0, -0.75), tc)
				cyl(n, 0.3, 0.3, 0.03, Vector3(0, 0.02, -1.02), DARK, Vector3(90, 0, 0))
				if id == "shahed_s":
					n.scale = Vector3.ONE * 0.55
		"harop":
			wing(n, [Vector2(0.0, 0.6), Vector2(1.5, -1.0), Vector2(0.0, -1.0)], 0.0, ac)
			box(n, Vector3(0.3, 0.3, 2.4), Vector3(0, 0.02, 0.2), ac)
			wing(n, [Vector2(0.15, 1.2), Vector2(0.6, 0.95), Vector2(0.15, 0.85)], 0.05, tc)
			for x in [-0.9, 0.9]:
				box(n, Vector3(0.04, 0.45, 0.45), Vector3(x, 0.2, -0.75), tc)
			cyl(n, 0.28, 0.28, 0.03, Vector3(0, 0.02, -1.02), DARK, Vector3(90, 0, 0))
		"flyingwing":
			# Okhotnik / Ghatak: kuyruksuz uçan kanat
			var dc := Color(0.3, 0.32, 0.35)
			wing(n, [Vector2(0.0, 2.2), Vector2(3.3, -1.1), Vector2(2.7, -1.6), Vector2(0.0, -0.8)], 0.0, dc)
			box(n, Vector3(0.9, 0.35, 2.4), Vector3(0, 0.1, 0.4), dc)
			box(n, Vector3(0.5, 0.06, 0.9), Vector3(0, 0.3, 0.2), tc)
			cyl(n, 0.2, 0.2, 0.3, Vector3(0, 0.1, -0.85), DARK, Vector3(90, 0, 0))
		"tb2":
			_twinboom(n, ac, tc)
		"twinboom":
			_twinboom(n, ac, tc)
			n.scale = Vector3.ONE * 1.35
		"vtail":
			# MQ-9 / Hermes 900 / Orion: ince gövde, uzun düz kanat, V kuyruk, arkada pervane
			box(n, Vector3(0.42, 0.42, 3.3), Vector3(0, 0, 0), ac)
			ball(n, 0.36, Vector3(0, 0.12, 1.5), ac)
			box(n, Vector3(6.4, 0.07, 0.5), Vector3(0, -0.05, 0.0), ac)
			box(n, Vector3(0.7, 0.09, 0.52), Vector3(-2.9, -0.05, 0.0), tc)
			box(n, Vector3(0.7, 0.09, 0.52), Vector3(2.9, -0.05, 0.0), tc)
			box(n, Vector3(0.07, 1.0, 0.45), Vector3(-0.4, 0.42, -1.5), tc, Vector3(0, 0, 40))
			box(n, Vector3(0.07, 1.0, 0.45), Vector3(0.4, 0.42, -1.5), tc, Vector3(0, 0, -40))
			box(n, Vector3(0.06, 0.5, 0.4), Vector3(0, -0.4, -1.5), ac)
			cyl(n, 0.4, 0.4, 0.04, Vector3(0, 0, -1.68), DARK, Vector3(90, 0, 0))
			for x in [-1.2, 1.2]:
				box(n, Vector3(0.1, 0.1, 0.6), Vector3(x, -0.18, 0.0), DARK)
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
		"maden":
			box(n, Vector3(3.2, 1.8, 2.6), Vector3(-1.0, 0.9, -0.8), CONCRETE)
			box(n, Vector3(3.3, 0.3, 2.7), Vector3(-1.0, 1.6, -0.8), tc)
			box(n, Vector3(0.7, 0.3, 4.2), Vector3(1.2, 1.5, 0.3), DARK, Vector3(-28, 0, 0))
			cyl(n, 0.0, 1.6, 1.6, Vector3(1.2, 0.8, 2.2), Color(0.3, 0.27, 0.24), Vector3.ZERO, 7)
			cyl(n, 0.25, 0.25, 3.4, Vector3(-2.0, 2.6, -1.4), DARK)
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
		"havaalani":
			# pist, iki hangar, kule
			box(n, Vector3(3.0, 0.06, 11.5), Vector3(2.6, 0.04, 0), DARK)
			for i in 5:
				box(n, Vector3(0.18, 0.07, 1.1), Vector3(2.6, 0.05, -4.4 + i * 2.2), Color(0.85, 0.85, 0.8))
			for z in [-2.6, 2.6]:
				box(n, Vector3(3.6, 1.3, 3.4), Vector3(-2.2, 0.65, z), CONCRETE)
				var roof := cyl(n, 1.8, 1.8, 3.4, Vector3(-2.2, 1.3, z), GREY, Vector3(90, 0, 0), 10)
				roof.scale = Vector3(1.0, 1.0, 0.45)
				box(n, Vector3(3.7, 0.22, 3.5), Vector3(-2.2, 1.2, z), tc)
			box(n, Vector3(0.8, 3.6, 0.8), Vector3(-0.2, 1.8, 0), CONCRETE)
			box(n, Vector3(1.3, 0.7, 1.3), Vector3(-0.2, 3.9, 0), GLASS)
			box(n, Vector3(1.4, 0.12, 1.4), Vector3(-0.2, 4.3, 0), tc)
		"teknoloji":
			box(n, Vector3(5.0, 1.8, 4.2), Vector3(0, 0.9, 0), CONCRETE)
			box(n, Vector3(5.1, 0.3, 4.3), Vector3(0, 1.6, 0), tc)
			ball(n, 1.3, Vector3(-1.0, 2.1, 0), Color(0.82, 0.85, 0.88))
			cyl(n, 0.06, 0.06, 3.2, Vector3(1.6, 3.4, 1.0), DARK)
			cyl(n, 0.7, 0.15, 0.4, Vector3(1.6, 2.4, -1.0), GREY, Vector3(35, 0, 0))
		"fuze":
			box(n, Vector3(5.0, 0.3, 5.0), Vector3(0, 0.15, 0), CONCRETE)
			box(n, Vector3(5.1, 0.12, 5.1), Vector3(0, 0.3, 0), tc)
			box(n, Vector3(1.6, 0.9, 3.6), Vector3(-1.2, 0.8, 0), Color(0.3, 0.33, 0.28))
			cyl(n, 0.32, 0.32, 3.6, Vector3(1.2, 2.2, 0), Color(0.85, 0.85, 0.82))
			cyl(n, 0.0, 0.32, 0.9, Vector3(1.2, 4.45, 0), DARK)
			for a in 4:
				box(n, Vector3(0.7, 0.5, 0.05), Vector3(1.2, 0.65, 0), DARK, Vector3(0, a * 45.0, 0))
		"sam_box":
			# Patriot / David's Sling: eğik kutu fırlatıcı
			box(n, Vector3(2.6, 0.5, 2.6), Vector3(0, 0.25, 0), bc)
			box(n, Vector3(2.7, 0.15, 2.7), Vector3(0, 0.5, 0), tc)
			box(n, Vector3(1.5, 1.0, 2.0), Vector3(0, 1.4, 0), bc, Vector3(-45, 0, 0))
			for x in [-0.4, 0.4]:
				for y in [-0.25, 0.25]:
					cyl(n, 0.16, 0.16, 2.2, Vector3(x, 1.5 + y, 0.2 + y), GREY, Vector3(45, 0, 0))
			cyl(n, 0.07, 0.07, 2.2, Vector3(-1.0, 1.6, -1.0), DARK)
			box(n, Vector3(0.9, 0.5, 0.1), Vector3(-1.0, 2.8, -1.0), GREY)
		"sam_tube":
			# S-400 / HQ-9 / Bavar-373: dikey dört tüp
			box(n, Vector3(2.4, 0.6, 3.4), Vector3(0, 0.5, 0), bc)
			box(n, Vector3(2.5, 0.15, 3.5), Vector3(0, 0.8, 0), tc)
			box(n, Vector3(1.9, 0.9, 1.0), Vector3(0, 1.25, 1.3), bc)
			for x in [-0.45, 0.45]:
				for z in [-0.9, -0.1]:
					cyl(n, 0.3, 0.3, 3.4, Vector3(x, 2.5, z), GREY)
			box(n, Vector3(1.2, 0.9, 0.1), Vector3(0, 2.6, 1.6), GREY, Vector3(-10, 0, 0))
	return n


# ---------------------------------------------------------------- parçalar

## Ayrıntılı araç modeli (şimdilik tanklar, tanks.gd): gövde ve kule iki mesh olarak eklenir.
## Kule mesh'i, yatak merkezindeki "turret" düğümünün altındadır; Unit onu hedefe döndürür.
## Toz rengi haritanın toprağından türetilir; mesh model, renk ve toz başına bir kez üretilip paylaşılır.
static func _vehicle(n: Node3D, id: String, bc: Color, tc: Color) -> void:
	var ground: Color = Defs.MAP.get("ground", Color(0.55, 0.5, 0.38))
	var dust := ground.lerp(Color(0.66, 0.6, 0.48), 0.55)
	var key := "%s|%s|%s|%s" % [id, bc.to_html(), tc.to_html(), dust.to_html()]
	if not _vehicles.has(key):
		var h := Kit.new()
		var t := Kit.new()
		h.dust = dust
		t.dust = dust
		Tanks.slots(h, bc, tc)
		Tanks.slots(t, bc, tc)
		var tz := Tanks.design(id, h, t)
		_vehicles[key] = [h.mesh(), t.mesh(), tz]
	var c: Array = _vehicles[key]
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = c[0]
	n.add_child(hull)
	# Unit, "turret" düğümünü bulup hedefe döndürür; düğüm kule yatağının merkezindedir.
	var t := _turret(n)
	t.position.z = c[2]
	var tur := MeshInstance3D.new()
	tur.mesh = c[1]
	t.add_child(tur)


static func _jet(n: Node3D, p: Dictionary, col: Color, tc: Color) -> void:
	var l: float = p.len
	var w: float = p.w
	var h: float = p.h
	# gövde: z = -0.44l .. +0.28l, burun konisi +0.5l'ye kadar
	box(n, Vector3(w, h, l * 0.72), Vector3(0, 0, -l * 0.08), col)
	if p.get("flat_nose", false):
		var nose := cyl(n, 0.04, w * 0.5, l * 0.22, Vector3(0, 0, l * 0.39), col, Vector3(90, 0, 0), 6)
		nose.scale = Vector3(1.0, 1.0, 0.55)
	else:
		cyl(n, 0.03, minf(w, h) * 0.5, l * 0.22, Vector3(0, 0, l * 0.39), col, Vector3(90, 0, 0), 6)
	box(n, Vector3(minf(w, 0.5) * 0.6, h * 0.5, l * 0.17), Vector3(0, h * 0.55, l * 0.19), GLASS)
	if p.get("intake", false):
		box(n, Vector3(w * 0.7, h * 0.4, l * 0.3), Vector3(0, -h * 0.6, l * 0.02), col)
	if p.eng == 1:
		cyl(n, w * 0.34, w * 0.4, l * 0.08, Vector3(0, 0, -l * 0.47), DARK, Vector3(90, 0, 0))
	else:
		for x in [-w * 0.27, w * 0.27]:
			cyl(n, w * 0.2, w * 0.24, l * 0.09, Vector3(x, 0, -l * 0.475), DARK, Vector3(90, 0, 0))
	wing(n, p.wing, 0.0, col)
	if p.has("stab"):
		wing(n, p.stab, 0.0, col)
	if p.has("canard"):
		wing(n, p.canard, h * 0.2, col)
	# kanat ucu takım rengi
	var tip: Vector2 = p.wing[0]
	for q in p.wing:
		if q.x > tip.x:
			tip = q
	for s in [1.0, -1.0]:
		box(n, Vector3(0.14, 0.07, 0.7), Vector3((tip.x - 0.05) * s, 0.0, tip.y - 0.25), tc)
	box(n, Vector3(w * 0.5, 0.05, l * 0.22), Vector3(0, h * 0.5 + 0.02, -l * 0.18), tc)
	# dikey kuyruk
	var fh := l * 0.2
	var pts := [Vector2(-l * 0.2, h * 0.5), Vector2(-l * 0.4, h * 0.5 + fh), Vector2(-l * 0.46, h * 0.5 + fh), Vector2(-l * 0.44, h * 0.5)]
	match p.tail:
		"single":
			fin(n, pts, 0.0, 0.0, col)
		"twin":
			fin(n, pts, w * 0.45, 0.0, col)
			fin(n, pts, -w * 0.45, 0.0, col)
		_:
			fin(n, pts, w * 0.45, 26.0, col)
			fin(n, pts, -w * 0.45, 26.0, col)


static func _twinboom(n: Node3D, ac: Color, tc: Color) -> void:
	# Bayraktar TB2 düzeni: ince gövde, düz kanat, çift kuyruk bomu, ters V kuyruk, itici pervane
	box(n, Vector3(0.42, 0.38, 2.4), Vector3(0, 0, 0.2), ac)
	ball(n, 0.24, Vector3(0, 0, 1.4), ac)
	box(n, Vector3(5.4, 0.07, 0.55), Vector3(0, 0.1, 0.2), ac)
	box(n, Vector3(0.6, 0.09, 0.57), Vector3(-2.4, 0.1, 0.2), tc)
	box(n, Vector3(0.6, 0.09, 0.57), Vector3(2.4, 0.1, 0.2), tc)
	box(n, Vector3(0.09, 0.09, 1.7), Vector3(-0.7, 0.1, -0.9), ac)
	box(n, Vector3(0.09, 0.09, 1.7), Vector3(0.7, 0.1, -0.9), ac)
	box(n, Vector3(0.07, 0.95, 0.4), Vector3(-0.35, 0.42, -1.6), tc, Vector3(0, 0, -48))
	box(n, Vector3(0.07, 0.95, 0.4), Vector3(0.35, 0.42, -1.6), tc, Vector3(0, 0, 48))
	cyl(n, 0.4, 0.4, 0.04, Vector3(0, 0, -1.05), DARK, Vector3(90, 0, 0))
	box(n, Vector3(0.1, 0.1, 0.5), Vector3(-1.2, -0.05, 0.2), DARK)
	box(n, Vector3(0.1, 0.1, 0.5), Vector3(1.2, -0.05, 0.2), DARK)


static func _multirotor(n: Node3D, arms: int, r: float, tc: Color) -> void:
	box(n, Vector3(r * 0.5, 0.14, r * 0.7), Vector3(0, 0, 0), DARK)
	box(n, Vector3(r * 0.3, 0.05, r * 0.3), Vector3(0, 0.1, 0), tc)
	for i in arms:
		var a := TAU * (i + 0.5) / arms
		var e := Vector3(cos(a), 0, sin(a)) * r
		box(n, Vector3(0.06, 0.05, r), e * 0.5, DARK, Vector3(0, -rad_to_deg(a) + 90.0, 0))
		cyl(n, r * 0.42, r * 0.42, 0.02, e + Vector3(0, 0.08, 0), Color(0.75, 0.78, 0.8), Vector3.ZERO, 8)


static func _truck(n: Node3D, bc: Color, l: float) -> void:
	box(n, Vector3(1.9, 0.5, l), Vector3(0, 0.85, 0), bc)
	box(n, Vector3(1.9, 0.95, 1.2), Vector3(0, 1.5, l * 0.5 - 0.6), bc)
	box(n, Vector3(1.7, 0.4, 0.05), Vector3(0, 1.65, l * 0.5 + 0.01), GLASS)
	var k := int(l / 1.5)
	for i in k:
		var z := -l * 0.5 + 0.6 + i * (l - 1.2) / maxf(1.0, k - 1)
		for x in [-0.95, 0.95]:
			cyl(n, 0.45, 0.45, 0.3, Vector3(x, 0.45, z), DARK, Vector3(0, 0, 90))


## Hedefe dönen parçaların (kule, namlu) toplandığı düğüm. Unit bunu adıyla bulur.
static func _turret(n: Node3D) -> Node3D:
	var t := Node3D.new()
	t.name = "turret"
	n.add_child(t)
	return t


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
