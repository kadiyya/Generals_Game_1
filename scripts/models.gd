class_name Models
extends RefCounted
## Bütün modeller kodla üretilir (kutu, silindir, prizma ve düz çokgen levhalar). Ön taraf +Z yönüdür.
## Tanklar (tanks.gd) ve hava araçları (aircraft.gd) ayrıntılı, tek parça mesh olarak Kit ile kurulur.

const DARK := Color(0.13, 0.13, 0.14)
const GREY := Color(0.6, 0.62, 0.66)
const CONCRETE := Color(0.5, 0.5, 0.48)
const WOOD := Color(0.45, 0.33, 0.2)
const GLASS := Color(0.12, 0.2, 0.28)

static var _mats := {}
static var _skin := {}   # renk -> [texture türü, ölçek]: bu renkteki parçalar desenli çizilir
static var _vehicles := {}   # model + renkler -> [gövde mesh, kule mesh, kule z]: her araç bir kez kurulur
static var _air := {}        # model + renkler + sınıf -> [gövde mesh, pervane mesh, göbekler]

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
	if Aircraft.has(id):
		_aircraft(n, d, id, ac, tc)
		return n
	if Vehicles.has(id) or id.begins_with("tank_"):
		_vehicle(n, id, bc, tc)
		return n
	match id:
		"inf":
			_soldiers(n, [Vector3(-0.45, 0, 0.45), Vector3(0.45, 0, 0.45), Vector3(-0.45, 0, -0.45), Vector3(0.45, 0, -0.45)], bc, tc, false)
		"at":
			_soldiers(n, [Vector3(-0.4, 0, 0.0), Vector3(0.4, 0, 0.0)], bc, tc, true)
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

## Uçak / İHA modeli (aircraft.gd). Pervaneler "rotors" düğümünün altında; AirUnit onları döndürür.
static func _aircraft(n: Node3D, d: Dictionary, id: String, ac: Color, tc: Color) -> void:
	# Geran-2 Rusya'da siyaha boyalı uçar.
	if id == "shahed" and d.get("cc", "") == "ru":
		ac = Color(0.13, 0.13, 0.14)
	var cls: String = d.get("cls", "")
	var key := "%s|%s|%s|%s" % [id, ac.to_html(), tc.to_html(), cls]
	if not _air.has(key):
		var k := Kit.new()
		var pk := Kit.new()
		k.grounded = false
		pk.grounded = false
		Aircraft.slots(k, ac, tc)
		Aircraft.slots(pk, ac, tc)
		var made := Aircraft.design(id, k, pk, cls)
		_air[key] = [k.mesh(), pk.mesh() if not made.is_empty() else null, made]
	var c: Array = _air[key]
	var body := MeshInstance3D.new()
	body.mesh = c[0]
	n.add_child(body)
	var hubs: Array = c[2]
	if hubs.is_empty():
		return
	var rotors := Node3D.new()
	rotors.name = "rotors"
	n.add_child(rotors)
	for hb in hubs:
		var hub := Node3D.new()
		hub.position = hb[0]
		hub.rotation_degrees = hb[1]
		rotors.add_child(hub)
		var pm := MeshInstance3D.new()
		pm.mesh = c[1]
		pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		hub.add_child(pm)


## Ayrıntılı kara aracı (tanks.gd, vehicles.gd): gövde ve varsa kule iki mesh olarak eklenir.
## Kule mesh'i, yatak merkezindeki "turret" düğümünün altındadır; Unit onu hedefe döndürür.
## Toz rengi haritanın toprağından türetilir; mesh model, renk ve toz başına bir kez üretilip paylaşılır.
static func _vehicle(n: Node3D, id: String, bc: Color, tc: Color) -> void:
	var dust := _dust()
	var key := "%s|%s|%s|%s" % [id, bc.to_html(), tc.to_html(), dust.to_html()]
	if not _vehicles.has(key):
		var h := Kit.new()
		var t := Kit.new()
		h.dust = dust
		t.dust = dust
		Vehicles.slots(h, bc, tc)
		Vehicles.slots(t, bc, tc)
		var tz := Vehicles.design(id, h, t) if Vehicles.has(id) else Tanks.design(id, h, t)
		_vehicles[key] = [h.mesh(), null if t.is_empty() else t.mesh(), tz]
	var c: Array = _vehicles[key]
	var hull := MeshInstance3D.new()
	hull.name = "Hull"
	hull.mesh = c[0]
	n.add_child(hull)
	if c[1] == null:
		return
	# Unit, "turret" düğümünü bulup hedefe döndürür; düğüm kule yatağının merkezindedir.
	var t := _turret(n)
	t.position.z = c[2]
	var tur := MeshInstance3D.new()
	tur.mesh = c[1]
	t.add_child(tur)


## Piyade: her asker ayrı düğümdür (Unit adım, çömelme ve kayıp animasyonlarını bunlarla yapar), mesh ortaktır.
static func _soldiers(n: Node3D, spots: Array, bc: Color, tc: Color, launcher: bool) -> void:
	var key := "sol|%s|%s|%s|%s" % [launcher, bc.to_html(), tc.to_html(), _dust().to_html()]
	if not _vehicles.has(key):
		var k := Kit.new()
		k.dust = _dust()
		Vehicles.slots(k, bc, tc)
		Vehicles.soldier(k, launcher)
		_vehicles[key] = [k.mesh()]
	for o in spots:
		var m := MeshInstance3D.new()
		m.mesh = _vehicles[key][0]
		m.position = o
		n.add_child(m)


## Araçların üstündeki toz ve çamurun rengi: haritanın toprağından.
static func _dust() -> Color:
	var ground: Color = Defs.MAP.get("ground", Color(0.55, 0.5, 0.38))
	return ground.lerp(Color(0.66, 0.6, 0.48), 0.55)


## Hedefe dönen parçaların (kule, namlu) toplandığı düğüm. Unit bunu adıyla bulur.
static func _turret(n: Node3D) -> Node3D:
	var t := Node3D.new()
	t.name = "turret"
	n.add_child(t)
	return t


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
