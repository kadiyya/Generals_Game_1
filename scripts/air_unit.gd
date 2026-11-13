class_name AirUnit
extends Entity
## Hava aracı: küçük İHA, büyük İHA ve uçak. Bir bölgeye atanır, orada döner.
## Silahlıysa gördüğü hedefi kendisi vurur; mühimmatı bitince üssüne dönüp silahlanır.
## Kamikaze olanlar hedefe dalıp patlar. Bazı küçük İHA'ların uçuş süresi sınırlıdır.

var patrol := Vector3.ZERO
var speed := 8.0
var turn := 2.6
var alt := 9.0
var orbit := 6.0
var leash := 24.0
var yaw := 0.0
var ammo := 0
var state := "patrol"   # patrol / rearm
var rearm_t := 0.0
var life := -1.0
var bob_t := randf() * 6.0
var rotors: Node3D = null   # varsa pervaneler döner
var parts: Array = []       # hareketli parçalar: [düğüm, eksen, ad, o anki açı]
var turn_rate := 0.0
var anim_t := randf() * 10.0


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	speed = float(d.speed)
	turn = float(d.get("turn", 2.6))
	alt = float(d.get("alt", 9.0))
	orbit = maxf(5.0, speed * 0.85) if not d.get("small", false) else 3.5
	leash = float(d.get("leash", 24.0))
	ammo = int(d.get("ammo", 0))
	life = float(d.get("life", -1.0))
	yaw = PI * 0.5 if position.x < 0.0 else -PI * 0.5
	position.y = alt
	patrol = position
	rotors = model.get_node_or_null("rotors")
	var pn := model.get_node_or_null("parts")
	if pn != null:
		for c in pn.get_children():
			parts.append([c, c.get_meta("axis", Vector3.UP), String(c.name), 0.0])
	ring.position.y = 0.0


func aim_pos() -> Vector3:
	return global_position


func muzzle_pos() -> Vector3:
	return global_position + Vector3(0, -0.3, 0)


func set_patrol(p: Vector3) -> void:
	patrol = Vector3(
		clampf(p.x, -Defs.MAP_W * 0.5, Defs.MAP_W * 0.5), 0,
		clampf(p.z, -Defs.MAP_H * 0.5, Defs.MAP_H * 0.5))
	target = null


func is_kamikaze() -> bool:
	return d.get("kamikaze", false)


func _process(dt: float) -> void:
	if not alive:
		return
	cd_timer -= dt
	scan_timer -= dt
	if visible:
		if rotors != null:
			for r in rotors.get_children():
				r.rotate_object_local(Vector3.UP, dt * 38.0)
		_animate(dt)
	if life > 0.0:
		life -= dt
		if life <= 0.0:
			die()
			return
	valid_target()
	if is_kamikaze():
		_kamikaze(dt)
		return
	if has_weapon() and d.has("ammo") and state == "patrol" and ammo <= 0:
		state = "rearm"
		rearm_t = 0.0
		target = null
	if state == "rearm":
		_rearm(dt)
		return
	if has_weapon():
		_acquire()
		if target != null:
			var dist: float = flat(global_position, target.global_position) - target.radius
			_fly(target.global_position, dt)
			if dist <= wrange() and cd_timer <= 0.0:
				fire(target)
				ammo -= 1
				target = null
			return
	_orbit(patrol, dt)


func _acquire() -> void:
	if target != null or scan_timer > 0.0:
		return
	scan_timer = 0.4
	var t = find_target(vision)
	if t != null and flat(t.global_position, patrol) <= leash:
		target = t


func _kamikaze(dt: float) -> void:
	_acquire()
	if target == null:
		_orbit(patrol, dt)
		return
	_fly(target.global_position, dt)
	if flat(global_position, target.global_position) <= target.radius + 1.2:
		var g := Game.I
		var base := damage_base()
		var sp: float = float(d.get("splash", 0.0))
		if sp > 0.0:
			g.splash_damage(target.global_position, sp, base, d.mult, team, "drone")
		else:
			target.take_damage(base * float(d.mult.get(target.armor, 0.0)), null, "drone")
		die()


func _rearm(dt: float) -> void:
	var home = Game.I.nearest_building(team, d.get("home", "havaalani"), global_position)
	if home == null:
		_orbit(patrol, dt)
		return
	_orbit(home.global_position, dt)
	if flat(global_position, home.global_position) < orbit + 4.0:
		rearm_t += dt
		if rearm_t >= float(d.get("rearm", 8.0)) * Game.I.mod(team, "rearm"):
			ammo = int(d.get("ammo", 0))
			state = "patrol"


func _orbit(center: Vector3, dt: float) -> void:
	var off := Vector3(global_position.x - center.x, 0, global_position.z - center.z)
	if off.length() > orbit * 1.6:
		_fly(center, dt)
	else:
		var ang := atan2(off.z, off.x) + 0.7
		_fly(center + Vector3(cos(ang), 0, sin(ang)) * orbit, dt)


func _fly(goal: Vector3, dt: float) -> void:
	var to := Vector3(goal.x - position.x, 0, goal.z - position.z)
	var tr := 0.0
	if to.length() > 0.05:
		var want := atan2(to.x, to.z)
		var before := yaw
		yaw = rotate_toward(yaw, want, turn * dt)
		tr = angle_difference(before, yaw) / maxf(dt, 0.001)
	turn_rate = tr
	position += Vector3(sin(yaw), 0, cos(yaw)) * speed * dt
	position.y = alt
	rotation.y = yaw
	model.rotation.z = lerpf(model.rotation.z, -tr * 0.2, minf(1.0, dt * 5.0))
	if d.get("small", false):
		bob_t += dt * 5.0
		model.position.y = sin(bob_t) * 0.18
		model.rotation.x = sin(bob_t * 0.7) * 0.08 + (0.14 if rotors != null and rotors.get_child_count() >= 4 else 0.0)


## Küçük hareketler: yatışta kanatçıklar zıt, irtifa dümenleri ve kanardlar yukarı, dikey dümen dönüş yönüne sapar;
## art yakıcı titrer (hedefe dalarken büyür), çakar ışık yanıp söner, kamera hedefe döner (yoksa tarar),
## kanat altı yükler cephane kadar görünür.
func _animate(dt: float) -> void:
	anim_t += dt
	var bank := model.rotation.z
	var pull := clampf(absf(turn_rate) * 0.35, 0.0, 0.45) + sin(anim_t * 0.9) * 0.04
	var k := minf(1.0, dt * 6.0)
	for p in parts:
		var node: Node3D = p[0]
		var nm: String = p[2]
		var side := 1.0 if nm.ends_with("_l") else -1.0
		var want := 0.0
		if nm.begins_with("burn"):
			node.scale = Vector3.ONE * (0.8 + randf() * 0.35 + (0.3 if target != null else 0.0))
			continue
		if nm == "strobe":
			node.visible = fmod(anim_t, 1.3) < 0.1
			continue
		if nm.begins_with("store"):
			node.visible = not d.has("ammo") or int(nm.substr(5)) < ammo
			continue
		if nm == "eo":
			if target != null and is_instance_valid(target):
				var to: Vector3 = target.global_position - global_position
				want = angle_difference(rotation.y, atan2(to.x, to.z))
			else:
				want = sin(anim_t * 0.35) * 1.4
			p[3] = rotate_toward(p[3], want, dt * 2.5)
			node.basis = Basis(p[1], p[3])
			continue
		if nm.begins_with("ail"):
			want = clampf(bank * 1.8, -0.45, 0.45) * side + sin(anim_t * 2.3 + side) * 0.03
		elif nm.begins_with("stab") or nm.begins_with("can"):
			want = -pull + clampf(bank, -0.3, 0.3) * 0.35 * side
		elif nm.begins_with("rud"):
			want = clampf(turn_rate * 0.3, -0.35, 0.35) + sin(anim_t * 1.7) * 0.03
		p[3] = lerpf(p[3], want, k)
		node.basis = Basis(p[1], p[3])
