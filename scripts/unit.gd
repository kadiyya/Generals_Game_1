class_name Unit
extends Entity
## Kara birimi. Emirler: idle, move (ateş etmeden git), amove (saldırarak ilerle), attack.

var order := "idle"
var dest := Vector3.ZERO
var speed := 4.0
var near_t := 0.0


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	speed = float(d.speed)
	rotation.y = PI * 0.5 if t == Defs.PLAYER else -PI * 0.5


func go(p: Vector3, attack_move: bool) -> void:
	dest = Vector3(p.x, 0, p.z)
	order = "amove" if attack_move else "move"
	target = null
	near_t = 0.0


func attack(e) -> void:
	target = e
	order = "attack"


func stop() -> void:
	order = "idle"
	target = null


func weapon_range() -> float:
	return float(d.get("range", 0.0))


func _process(dt: float) -> void:
	if not alive:
		return
	cd_timer -= dt
	scan_timer -= dt
	valid_target()
	match order:
		"move":
			if _step(dest, dt):
				order = "idle"
		"attack":
			if target == null:
				order = "idle"
			else:
				_engage(dt, true)
		"amove":
			_scan()
			if target != null:
				_engage(dt, true)
			elif _step(dest, dt):
				order = "idle"
		_:
			_scan()
			if target != null:
				_engage(dt, not d.get("no_chase", false))


func _scan() -> void:
	if target != null or scan_timer > 0.0 or not has_weapon():
		return
	scan_timer = 0.3
	var r := weapon_range()
	if not d.get("no_chase", false) or order == "amove":
		r = maxf(r, vision * 0.85)
	target = find_target(r, float(d.get("min_range", 0.0)))


func _engage(dt: float, chase: bool) -> void:
	var dist: float = flat(position, target.position) - target.radius
	if dist > weapon_range():
		if chase:
			_step(target.position, dt)
		else:
			target = null
	elif dist < float(d.get("min_range", 0.0)):
		target = null
	else:
		var to: Vector3 = target.position - position
		_face(Vector3(to.x, 0, to.z).normalized(), dt)
		if cd_timer <= 0.0:
			fire(target)


func _step(p: Vector3, dt: float) -> bool:
	var to := Vector3(p.x - position.x, 0, p.z - position.z)
	var dist := to.length()
	if dist < 0.7:
		return true
	if dist < 4.0:
		# Kalabalıkta hedef noktaya tam ulaşılamıyorsa bir süre sonra varmış say.
		near_t += dt
		if near_t > 1.5:
			near_t = 0.0
			return true
	else:
		near_t = 0.0
	var dir := to / dist
	position += dir * minf(speed * dt, dist)
	position.x = clampf(position.x, -Defs.MAP_W * 0.5 + 1.0, Defs.MAP_W * 0.5 - 1.0)
	position.z = clampf(position.z, -Defs.MAP_H * 0.5 + 1.0, Defs.MAP_H * 0.5 - 1.0)
	_face(dir, dt)
	return false


func _face(dir: Vector3, dt: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 8.0))


func _on_damaged(attacker) -> void:
	# Mangada can azaldıkça asker sayısı düşer.
	if armor == "inf":
		var n := model.get_child_count()
		var keep := int(ceil(clampf(hp / max_hp, 0.0, 1.0) * n))
		for i in n:
			model.get_child(i).visible = i < maxi(keep, 1)
	if order == "idle" and target == null and attacker != null and is_instance_valid(attacker) and attacker.alive and can_hit(attacker):
		target = attacker
