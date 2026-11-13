class_name Bridge
extends Entity
## Köprü: yolun nehri kestiği yerde kendiliğinden kurulur. Kimseye ait değildir ama her taraf yıkabilir
## (topçu, füze, uçak ya da "Köprü Yık" emri). Yıkılınca nehir orada geçilmez olur, üstündeki araçlar suya düşer.
## Yıkık köprü, yanında yalnızca bir tarafın askerî birlikleri bulunduğu sürece onarılır (40 sn).
## Hasarlı ama ayakta olan köprü de aynı şekilde yavaşça onarılır.

const REPAIR_TIME := 40.0
const REPAIR_R := 16.0

var cells: Array = []
var a := Vector3.ZERO
var b := Vector3.ZERO
var w := 6.0
var down := false
var repair_t := 0.0
var repair_side := -1
var intact: Node3D
var broken: Node3D
var _tick := 0.0


func setup_bridge(data: Dictionary) -> void:
	team = Defs.NEUTRAL
	neutral_target = true
	is_building = true
	cls = "bridge"
	armor = "bld"
	a = Vector3(data.a.x, 0, data.a.y)
	b = Vector3(data.b.x, 0, data.b.y)
	w = float(data.w)
	cells = data.cells
	var length := a.distance_to(b)
	position = (a + b) * 0.5
	max_hp = 2200.0 + length * 60.0
	hp = max_hp
	radius = minf(length * 0.5, 7.0)
	vision = 0.0
	d = {name = "Köprü", cost = 400, hp = max_hp, armor = "bld", radius = radius}
	seen = true
	discovered = true
	model = Node3D.new()
	add_child(model)
	model.look_at_from_position(position, b, Vector3.UP)
	model.position = Vector3.ZERO
	intact = _deck(length, false)
	broken = _deck(length, true)
	broken.visible = false
	ring = Models.ring(radius + 0.4)
	ring.visible = false
	add_child(ring)


## Beton tabliye, korkuluklar ve ayaklar. Yıkık hâlde yalnızca iki uçtaki parçalar ve suya düşmüş orta kısım kalır.
func _deck(length: float, ruined: bool) -> Node3D:
	var n := Node3D.new()
	model.add_child(n)
	var conc := Tex.mat("panel", Color(0.55, 0.54, 0.5), 0.2, true)
	var dark := Models.mat(Color(0.2, 0.2, 0.2))
	var parts: Array = []
	if ruined:
		var stub := length * 0.22
		parts = [[-length * 0.5 + stub * 0.5, stub, 0.0], [length * 0.5 - stub * 0.5, stub, 0.0], [0.0, length * 0.4, -0.5]]
	else:
		parts = [[0.0, length, 0.0]]
	for i in parts.size():
		var p: Array = parts[i]
		var tilt := 0.0 if i < 2 or not ruined else 0.12
		var deck := Models.box(n, Vector3(w, 0.4, p[1]), Vector3(0, 0.5 + p[2], p[0]), Color.WHITE, Vector3(rad_to_deg(tilt), 0, 8.0 if ruined and i == 2 else 0.0))
		deck.material_override = conc
		if not ruined or i < 2:
			for sx in [-1.0, 1.0]:
				var rail := Models.box(n, Vector3(0.18, 0.5, p[1]), Vector3(sx * (w * 0.5 - 0.1), 0.95 + p[2], p[0]), Color.WHITE)
				rail.material_override = conc
	var piers := int(length / 9.0)
	for i in range(1, piers + 1):
		var z := -length * 0.5 + length * i / (piers + 1)
		if ruined and absf(z) < length * 0.2:
			continue
		var pier := Models.box(n, Vector3(w * 0.7, 1.4, 1.0), Vector3(0, -0.2, z), Color.WHITE)
		pier.material_override = conc
	if not ruined:
		var stripe := Models.box(n, Vector3(0.15, 0.02, length * 0.9), Vector3(0, 0.71, 0), Color(0.9, 0.85, 0.5))
		stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		for i in 6:
			var rb := Models.box(n, Vector3(randf_range(0.6, 1.4), 0.5, randf_range(0.6, 1.4)), Vector3(randf_range(-w * 0.4, w * 0.4), 0.0, randf_range(-length * 0.3, length * 0.3)), Color.WHITE, Vector3(0, randf() * 90.0, 20))
			rb.material_override = dark
	return n


## Köprünün ekseni ile p arasındaki yatay uzaklık (kenardan).
func dist_to(p: Vector3) -> float:
	return Bridge.seg_dist(p, a, b) - w * 0.5


static func seg_dist(p: Vector3, s0: Vector3, s1: Vector3) -> float:
	var ab := Vector2(s1.x - s0.x, s1.z - s0.z)
	var ap := Vector2(p.x - s0.x, p.z - s0.z)
	var t := clampf(ap.dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
	return (ap - ab * t).length()


func aim_pos() -> Vector3:
	return global_position + Vector3(0, 0.8, 0)


func has_weapon() -> bool:
	return false


func take_damage(amount: float, attacker = null, _tag := "") -> void:
	if down or amount <= 0.0:
		return
	hp -= amount
	if attacker != null and is_instance_valid(attacker) and attacker.alive:
		attacker.gain_xp(minf(amount, maxf(hp, 0.0)) * 0.3)
	if hp <= 0.0:
		collapse()


func collapse() -> void:
	var g := Game.I
	down = true
	alive = false
	hp = 0.0
	repair_t = 0.0
	intact.visible = false
	broken.visible = true
	for i in 4:
		g.fx_explosion(a.lerp(b, 0.2 + i * 0.2) + Vector3(0, 1.0, 0), 2.5)
	# Üstündeki kara birlikleri suya düşer.
	for e in g.entities.duplicate():
		if e.alive and not e.is_air and not e.is_building and dist_to(e.global_position) < 0.5:
			e.take_damage(e.max_hp * 10.0)
	g.terrain.set_bridge(cells, false)
	if g.selection.has(self):
		g.clear_selection()
	if g.fog.sees(Defs.PLAYER, global_position):
		g.hud.toast("Bir köprü yıkıldı!")


func restore(frac: float) -> void:
	down = false
	alive = true
	hp = max_hp * frac
	intact.visible = true
	broken.visible = false
	Game.I.terrain.set_bridge(cells, true)


func _process(dt: float) -> void:
	_tick -= dt
	if _tick > 0.0:
		return
	_tick = 1.0
	var g := Game.I
	if g == null or g.over:
		return
	if not down and hp >= max_hp:
		return
	# Hangi tarafın askerî birliği köprünün yanında?
	var sides := {}
	for e in g.nearby(global_position, REPAIR_R + radius + 4.0):
		if e.alive and not e.is_air and not e.is_building and e.has_weapon() and dist_to(e.global_position) < REPAIR_R:
			sides[Defs.SIDE[e.team]] = true
	if sides.size() != 1:
		return
	var s: int = sides.keys()[0]
	if down:
		if s != repair_side:
			repair_side = s
			repair_t = 0.0
		repair_t += 1.0
		if repair_t >= REPAIR_TIME:
			restore(0.4)
			if s == Defs.SIDE[Defs.PLAYER]:
				g.hud.toast("Köprü onarıldı.")
	else:
		hp = minf(max_hp, hp + max_hp * 0.01)
