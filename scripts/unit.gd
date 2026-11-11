class_name Unit
extends Entity
## Kara birimi. Emirler: idle, move (ateş etmeden git), amove (saldırarak ilerle), attack.
## Engellerin çevresinden Terrain üzerinden yol bulur.

var order := "idle"
var dest := Vector3.ZERO
var speed := 4.0
var near_t := 0.0
var nav := PackedVector3Array()
var nav_i := 0
var nav_goal := Vector3.INF
var nav_wp := Vector3.ZERO
var nav_t := 0.0
var nav_ok := true


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	speed = float(d.speed)
	rotation.y = PI * 0.5 if position.x < 0.0 else -PI * 0.5


func go(p: Vector3, attack_move: bool) -> void:
	dest = Game.I.terrain.nearest_free(Vector3(p.x, 0, p.z))
	order = "amove" if attack_move else "move"
	target = null
	near_t = 0.0
	nav_goal = Vector3.INF


func attack(e) -> void:
	target = e
	order = "attack"


func stop() -> void:
	order = "idle"
	target = null


func weapon_range() -> float:
	return wrange()


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


func _waypoint(p: Vector3, dt: float) -> Vector3:
	nav_t -= dt
	if nav_t > 0.0 and nav_goal.distance_to(p) < 3.0 and flat(position, nav_wp) > 1.0:
		return nav_wp
	nav_t = 0.25
	var ter := Game.I.terrain
	if ter.line_clear(position, p):
		nav = PackedVector3Array()
		nav_goal = p
		nav_wp = p
		nav_ok = true
		return p
	if nav.is_empty() or nav_goal.distance_to(p) > 3.0:
		nav = ter.find_path(position, p)
		nav_i = 0
		nav_goal = p
		nav_ok = not nav.is_empty()
		if not nav_ok:
			nav_wp = position
			return position
	while nav_i < nav.size() - 1 and (flat(position, nav[nav_i]) < 1.6 or ter.line_clear(position, nav[nav_i + 1])):
		nav_i += 1
	nav_wp = nav[nav_i]
	return nav_wp


func _step(p: Vector3, dt: float) -> bool:
	var dist := flat(position, p)
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
	var wp := _waypoint(p, dt)
	if not nav_ok:
		return true
	var to := Vector3(wp.x - position.x, 0, wp.z - position.z)
	var l := to.length()
	if l < 0.05:
		nav_t = 0.0
		return false
	var dir := to / l
	position += dir * minf(speed * dt, l)
	position.x = clampf(position.x, -Defs.MAP_W * 0.5 + 1.0, Defs.MAP_W * 0.5 - 1.0)
	position.z = clampf(position.z, -Defs.MAP_H * 0.5 + 1.0, Defs.MAP_H * 0.5 - 1.0)
	_face(dir, dt)
	return false


func _face(dir: Vector3, dt: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 8.0))


func _on_damaged(attacker) -> void:
	update_figures()
	if order == "idle" and target == null and attacker != null and is_instance_valid(attacker) and attacker.alive and can_hit(attacker):
		target = attacker


func update_figures() -> void:
	# Mangada can azaldıkça asker sayısı düşer.
	if armor != "inf":
		return
	var n := model.get_child_count()
	var keep := int(ceil(clampf(hp / max_hp, 0.0, 1.0) * n))
	for i in n:
		model.get_child(i).visible = i < maxi(keep, 1)
