class_name AirUnit
extends Entity
## İHA. Bir bölgeye atanır, orada döner. Silahlıysa gördüğü yer hedefini kendisi vurur,
## mühimmatı bitince İHA istasyonuna dönüp silahlanır.

const ORBIT := 6.0
const TURN := 2.6
const LEASH := 24.0

var patrol := Vector3.ZERO
var speed := 8.0
var yaw := 0.0
var ammo := 0
var state := "patrol"   # patrol / rearm
var rearm_t := 0.0


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	speed = float(d.speed)
	ammo = int(d.get("ammo", 0))
	yaw = PI * 0.5 if t == Defs.PLAYER else -PI * 0.5
	position.y = Defs.AIR_HEIGHT
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


func _process(dt: float) -> void:
	if not alive:
		return
	cd_timer -= dt
	scan_timer -= dt
	valid_target()
	if has_weapon() and state == "patrol" and ammo <= 0:
		state = "rearm"
		rearm_t = 0.0
		target = null
	if state == "rearm":
		_rearm(dt)
		return
	if has_weapon() and ammo > 0:
		if target == null and scan_timer <= 0.0:
			scan_timer = 0.4
			var t = find_target(vision)
			if t != null and flat(t.global_position, patrol) <= LEASH:
				target = t
		if target != null:
			var dist: float = flat(global_position, target.global_position) - target.radius
			_fly(target.global_position, dt)
			if dist <= float(d.range) and cd_timer <= 0.0:
				fire(target)
				ammo -= 1
				target = null
			return
	_orbit(patrol, dt)


func _rearm(dt: float) -> void:
	var home = Game.I.nearest_building(team, "iha", global_position)
	if home == null:
		_orbit(patrol, dt)
		return
	_orbit(home.global_position, dt)
	if flat(global_position, home.global_position) < ORBIT + 3.0:
		rearm_t += dt
		if rearm_t >= float(d.get("rearm", 8.0)):
			ammo = int(d.get("ammo", 0))
			state = "patrol"


func _orbit(center: Vector3, dt: float) -> void:
	var off := Vector3(global_position.x - center.x, 0, global_position.z - center.z)
	if off.length() > ORBIT * 1.6:
		_fly(center, dt)
	else:
		var ang := atan2(off.z, off.x) + 0.7
		_fly(center + Vector3(cos(ang), 0, sin(ang)) * ORBIT, dt)


func _fly(goal: Vector3, dt: float) -> void:
	var to := Vector3(goal.x - position.x, 0, goal.z - position.z)
	var turn := 0.0
	if to.length() > 0.05:
		var want := atan2(to.x, to.z)
		var before := yaw
		yaw = rotate_toward(yaw, want, TURN * dt)
		turn = angle_difference(before, yaw) / maxf(dt, 0.001)
	position += Vector3(sin(yaw), 0, cos(yaw)) * speed * dt
	position.y = Defs.AIR_HEIGHT
	rotation.y = yaw
	model.rotation.z = lerpf(model.rotation.z, -turn * 0.18, minf(1.0, dt * 5.0))
