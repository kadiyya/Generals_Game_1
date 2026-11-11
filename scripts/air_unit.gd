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
	position += Vector3(sin(yaw), 0, cos(yaw)) * speed * dt
	position.y = alt
	rotation.y = yaw
	model.rotation.z = lerpf(model.rotation.z, -tr * 0.2, minf(1.0, dt * 5.0))
