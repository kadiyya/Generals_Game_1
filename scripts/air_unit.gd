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
var tank_t := 0.0
var phase_t := 0.0
var rw_start := Vector3.ZERO    # pist başı (iniş / kalkış)
var rw_dir := Vector3.FORWARD


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
	jammed_t -= dt
	if tanker() and d.has("ammo"):
		# Havada yakıt ikmali: mühimmat havada yenilenir, üsse dönmez.
		tank_t += dt
		if tank_t >= 5.0:
			tank_t = 0.0
			ammo = mini(int(d.ammo), ammo + 1)
			if state in ["rearm", "landing"]:
				state = "patrol"
	if rotors != null and visible:
		for r in rotors.get_children():
			r.rotate_object_local(Vector3.UP, dt * 38.0)
	if life > 0.0:
		life -= dt
		if life <= 0.0:
			die()
			return
	if state == "takeoff":
		_takeoff(dt)
		return
	valid_target()
	if is_kamikaze():
		_kamikaze(dt)
		return
	if has_weapon() and d.has("ammo") and state == "patrol" and ammo <= 0:
		state = "rearm"
		rearm_t = 0.0
		target = null
	if state in ["rearm", "landing", "rollout", "parked"]:
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


func tanker() -> bool:
	return cls in Defs.PLANE_CLASSES and Game.I.teams[team].tanker_until > Game.I.time


func _acquire() -> void:
	if jammed_t > 0.0:
		target = null
		return
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


## Hava alanının pistinden kalkış: pistte hızlanır, sonra tırmanır.
func start_takeoff(start: Vector3, dir: Vector3) -> void:
	state = "takeoff"
	phase_t = 0.0
	rw_start = start
	rw_dir = dir
	position = Vector3(start.x, 0.35, start.z)
	yaw = atan2(dir.x, dir.z)
	rotation.y = yaw
	if cls in Defs.PLANE_CLASSES:
		Game.I.sfx.play("jet", global_position)


func _takeoff(dt: float) -> void:
	phase_t += dt
	var v := speed * clampf(phase_t / 2.5, 0.2, 1.0)
	position += Vector3(sin(yaw), 0, cos(yaw)) * v * dt
	var climb := smoothstep(1.6, 4.2, phase_t)
	position.y = lerpf(0.35, alt, climb)
	model.rotation.x = -0.22 * climb * (1.0 - climb) * 4.0
	if phase_t >= 4.2:
		state = "patrol"
		model.rotation.x = 0.0


## Pist: hava alanı modelinde x = 2.6'da, z boyunca uzanır.
static func runway(home) -> Array:
	var a: Vector3 = home.global_transform * Vector3(2.6, 0, -5.0)
	var b: Vector3 = home.global_transform * Vector3(2.6, 0, 5.0)
	return [a, (b - a).normalized()]


func _rearm(dt: float) -> void:
	var home = Game.I.nearest_building(team, d.get("home", "havaalani"), global_position)
	if home == null:
		# Üs yok: havada bekler (ya da yakıt ikmaliyle yeniden silahlanır).
		state = "rearm"
		_orbit(patrol, dt)
		return
	if home.kind == "havaalani":
		_land(home, dt)
		return
	_orbit(home.global_position, dt)
	if flat(global_position, home.global_position) < orbit + 4.0:
		rearm_t += dt
		if rearm_t >= float(d.get("rearm", 8.0)) * Game.I.mod(team, "rearm"):
			ammo = int(d.get("ammo", 0))
			state = "patrol"


## Pistte iniş, park ve yeniden kalkış: yaklaşma noktasına uçar, alçalarak piste konar, durur,
## silahlanır ve aynı pistten tekrar kalkar.
func _land(home, dt: float) -> void:
	var rw := runway(home)
	var start: Vector3 = rw[0]
	var dir: Vector3 = rw[1]
	match state:
		"rearm":
			var appr := start - dir * 24.0
			_fly(appr, dt)
			if flat(global_position, appr) < 6.0:
				state = "landing"
		"landing":
			var dist := flat(global_position, start)
			var y := lerpf(0.35, alt, clampf(dist / 24.0, 0.0, 1.0))
			_fly(start, dt, y, speed * clampf(0.45 + dist / 40.0, 0.45, 1.0))
			if dist < 2.0:
				state = "rollout"
				phase_t = 0.0
				yaw = atan2(dir.x, dir.z)
		"rollout":
			phase_t += dt
			var v := speed * 0.45 * maxf(0.0, 1.0 - phase_t / 1.6)
			position += dir * v * dt
			position.y = 0.35
			rotation.y = yaw
			model.rotation.z = 0.0
			if phase_t >= 1.6:
				state = "parked"
				rearm_t = 0.0
		"parked":
			rearm_t += dt
			if rearm_t >= float(d.get("rearm", 8.0)) * Game.I.mod(team, "rearm"):
				ammo = int(d.get("ammo", 0))
				start_takeoff(start, dir)


func _orbit(center: Vector3, dt: float) -> void:
	var off := Vector3(global_position.x - center.x, 0, global_position.z - center.z)
	if off.length() > orbit * 1.6:
		_fly(center, dt)
	else:
		var ang := atan2(off.z, off.x) + 0.7
		_fly(center + Vector3(cos(ang), 0, sin(ang)) * orbit, dt)


func _fly(goal: Vector3, dt: float, y := -1.0, spd := -1.0) -> void:
	var to := Vector3(goal.x - position.x, 0, goal.z - position.z)
	var tr := 0.0
	if to.length() > 0.05:
		var want := atan2(to.x, to.z)
		var before := yaw
		yaw = rotate_toward(yaw, want, turn * dt)
		tr = angle_difference(before, yaw) / maxf(dt, 0.001)
	var sp := (spd if spd > 0.0 else speed) * (1.2 if tanker() else 1.0)
	position += Vector3(sin(yaw), 0, cos(yaw)) * sp * dt
	position.y = y if y >= 0.0 else lerpf(position.y, alt, minf(1.0, dt * 2.0))
	rotation.y = yaw
	model.rotation.z = lerpf(model.rotation.z, -tr * 0.2, minf(1.0, dt * 5.0))
	if d.get("small", false):
		bob_t += dt * 5.0
		model.position.y = sin(bob_t) * 0.18
		model.rotation.x = sin(bob_t * 0.7) * 0.08
