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
	if Buildings.has(id):
		_structure(n, id, bc, tc)
		return n
	if Vehicles.has(id) or id.begins_with("tank_"):
		_vehicle(n, id, bc, tc)
		return n
	match id:
		"inf":
			_soldiers(n, [Vector3(-0.45, 0, 0.45), Vector3(0.45, 0, 0.45), Vector3(-0.45, 0, -0.45), Vector3(0.45, 0, -0.45)], bc, tc, false)
		"at":
			_soldiers(n, [Vector3(-0.4, 0, 0.0), Vector3(0.4, 0, 0.0)], bc, tc, true)
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


## Bina, vinç ya da ikmal noktası (buildings.gd): tek mesh, renk ve toz başına bir kez üretilir.
static func _structure(n: Node3D, id: String, bc: Color, tc: Color) -> void:
	var key := "bld|%s|%s|%s|%s" % [id, bc.to_html(), tc.to_html(), _dust().to_html()]
	if not _vehicles.has(key):
		var k := Kit.new()
		k.dust = _dust()
		Buildings.slots(k, bc, tc)
		Buildings.design(id, k)
		_vehicles[key] = [k.mesh()]
	var m := MeshInstance3D.new()
	m.mesh = _vehicles[key][0]
	n.add_child(m)


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
	_structure(n, "crane", CONCRETE, Color.WHITE)
	return n


static func supply_point(oil: bool) -> Node3D:
	var n := Node3D.new()
	_structure(n, "supply_oil" if oil else "supply_crates", Color(0.33, 0.4, 0.27), Color.WHITE)
	return n
