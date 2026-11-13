class_name Unit
extends Entity
## Kara birimi. Emirler: idle, move (ateş etmeden git), amove (saldırarak ilerle), attack,
## dig (siper kaz), mine (mayın döşe), obstacle (engel kur), enter (eve gir).
## Engellerin çevresinden Terrain üzerinden yol bulur; tepede yükselir, yolda hızlanır, ormanda yavaşlar.

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
var turret: Node3D = null    # varsa gövdeden bağımsız döner
var turret_base := Vector3.ZERO   # kulenin dönme merkezi (geri tepme buradan ölçülür)
var recoil := 0.0
var anim_t := 0.0
var moving := false
var dust_t := 0.0
var _last_pos := Vector3.ZERO
var task_t := 0.0
var entrenched := false
var trench: Node3D = null
var garrison = null            # içinde bulunduğu ev (Garrison)
var enter_target = null
var retreating := false
var ew_ring: MeshInstance3D = null
var los_t := 0.0
var patrol_a := Vector3.ZERO
var patrol_b := Vector3.ZERO
var los_ok := true


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	speed = float(d.speed)
	rotation.y = PI * 0.5 if position.x < 0.0 else -PI * 0.5
	turret = model.get_node_or_null("turret")
	if turret != null:
		turret_base = turret.position
	_last_pos = position
	if d.has("ew"):
		ew_ring = Models.ring(float(d.ew), Color(0.35, 0.85, 1.0))
		ew_ring.scale.y = 0.08
		add_child(ew_ring)


func muzzle_pos() -> Vector3:
	var yaw := rotation.y + (turret.rotation.y if turret != null else 0.0)
	var reach: float = 0.6 if armor == "inf" else radius + 1.0
	var pivot := global_transform.basis * turret_base
	return global_position + pivot + Vector3(sin(yaw), 0, cos(yaw)) * reach + Vector3(0, 1.25 if armor != "inf" else 0.75, 0)


func _on_fired() -> void:
	recoil = 1.0


func wrange() -> float:
	return super.wrange() + (3.0 if garrison != null else 0.0)


func concealed() -> bool:
	return armor == "inf" and reveal_t <= 0.0 and garrison == null and Game.I.terrain.kind_at(global_position) == Terrain.FOREST


func damage_taken_mult() -> float:
	var m := super.damage_taken_mult()
	if garrison != null:
		m *= 0.4
	elif entrenched:
		m *= 0.5
	if retreating:
		m *= 0.7
	return m


## Görev emri: siper, mayın, engel. Birim durur ve görev süresi dolunca iş biter.
func do_task(kind: String) -> void:
	_leave()
	order = kind
	target = null
	task_t = 0.0


## Devriye: bulunduğu yerle p arasında saldırarak gidip gelir.
func patrol_to(p: Vector3) -> void:
	patrol_a = position
	go(p, true)
	patrol_b = dest
	order = "patrol"


func enter(house) -> void:
	_leave()
	enter_target = house
	go(house.position, false)
	enter_target = house
	order = "enter"


func _leave() -> void:
	if garrison != null:
		garrison.remove(self)
		garrison = null
		model.visible = true
		position = Game.I.terrain.nearest_free(position + Vector3(0, 0, 3.2))
	if entrenched:
		entrenched = false
		if trench != null:
			trench.queue_free()
			trench = null


func go(p: Vector3, attack_move: bool) -> void:
	_leave()
	retreating = false
	enter_target = null
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
	retreating = false


func weapon_range() -> float:
	return wrange()


func _process(dt: float) -> void:
	if not alive:
		return
	cd_timer -= dt
	scan_timer -= dt
	reveal_t -= dt
	valid_target()
	match order:
		"move":
			if _step(dest, dt):
				order = "idle"
				retreating = false
		"enter":
			var h = enter_target
			if h == null or not h.has_room(team):
				order = "idle"
			elif flat(position, h.position) < 4.5 or _step(dest, dt):
				if flat(position, h.position) < 6.0 and h.has_room(team):
					h.add(self)
					garrison = h
					model.visible = false
				order = "idle"
		"patrol":
			_scan()
			if target != null:
				_engage(dt, true)
			elif _step(dest, dt):
				dest = patrol_a if dest.distance_to(patrol_b) < 1.0 else patrol_b
				nav_goal = Vector3.INF
		"dig", "mine", "obstacle":
			task_t += dt
			var need := Defs.DIG_TIME if order == "dig" else (3.0 if order == "mine" else 5.0)
			if task_t >= need:
				_finish_task()
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
	_animate(dt)


func _scan() -> void:
	if target != null or scan_timer > 0.0 or not has_weapon():
		return
	scan_timer = 0.3
	var r := weapon_range()
	if not d.get("no_chase", false) or order == "amove":
		r = maxf(r, vision * 0.85)
	target = find_target(r, float(d.get("min_range", 0.0)))


func _engage(dt: float, chase: bool) -> void:
	# Siperdeki ve evdeki birlik mevziini bırakıp kovalamaz.
	chase = chase and garrison == null and not entrenched
	var dist: float = flat(position, target.position) - target.radius
	los_t -= dt
	if los_t <= 0.0:
		los_t = 0.5
		los_ok = target.is_air or not needs_los() or Game.I.terrain.los_clear(global_position, target.global_position)
	if not los_ok:
		# Arada engel var: görüş hattı açılana kadar yaklaş.
		if chase:
			_step(target.position, dt)
		else:
			target = null
	elif dist > weapon_range():
		if chase:
			_step(target.position, dt)
		else:
			target = null
	elif dist < float(d.get("min_range", 0.0)):
		target = null
	else:
		var to: Vector3 = target.position - position
		var dir := Vector3(to.x, 0, to.z).normalized()
		var aimed := true
		if turret != null:
			# Gövde yerinde kalır, kule hedefe döner; nişan alınmadan ateş edilmez.
			var want := atan2(dir.x, dir.z) - rotation.y
			turret.rotation.y = rotate_toward(turret.rotation.y, want, dt * 3.2)
			aimed = absf(angle_difference(turret.rotation.y, want)) < 0.12
		else:
			_face(dir, dt)
		if aimed and cd_timer <= 0.0:
			fire(target)


func _finish_task() -> void:
	var g := Game.I
	var fwd := Vector3(sin(rotation.y), 0, cos(rotation.y))
	match order:
		"dig":
			entrenched = true
			trench = Models.build({"model": "trench"}, team)
			add_child(trench)
		"mine":
			g.place_mine(team, position + fwd * 2.5)
		"obstacle":
			g.place_obstacle(team, position + fwd * 4.0)
	order = "idle"


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
	var ter := Game.I.terrain
	var sp := speed * ter.speed_mult(position, armor) * (1.25 if retreating else 1.0)
	position += dir * minf(sp * dt, l)
	position.y = lerpf(position.y, ter.height(position), minf(1.0, dt * 6.0))
	position.x = clampf(position.x, -Defs.MAP_W * 0.5 + 1.0, Defs.MAP_W * 0.5 - 1.0)
	position.z = clampf(position.z, -Defs.MAP_H * 0.5 + 1.0, Defs.MAP_H * 0.5 - 1.0)
	_face(dir, dt)
	return false


func _face(dir: Vector3, dt: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 8.0))


func _animate(dt: float) -> void:
	if dt <= 0.0:
		return
	var v := flat(position, _last_pos) / dt
	_last_pos = position
	moving = v > 0.3
	recoil = maxf(0.0, recoil - dt * 4.0)
	if ew_ring != null:
		ew_ring.visible = seen
		var pulse := 1.0 + 0.04 * sin(Game.I.time * 3.0)
		ew_ring.scale = Vector3(pulse, 0.08, pulse)
	if garrison != null:
		return
	if armor == "inf":
		# Yürürken adım atar ve öne eğilir; dururken ateş ediyorsa çömelir.
		if moving:
			anim_t += dt * 9.0
		var crouch := 0.78 if ((target != null or entrenched or order == "dig") and not moving) else 1.0
		for i in model.get_child_count():
			var f: Node3D = model.get_child(i)
			var hop := absf(sin(anim_t + i * 1.7)) * 0.13 if moving else 0.0
			f.position.y = lerpf(f.position.y, hop, minf(1.0, dt * 18.0))
			f.rotation.x = lerpf(f.rotation.x, (0.25 if moving else 0.0) - recoil * 0.2, minf(1.0, dt * 12.0))
			f.scale.y = lerpf(f.scale.y, crouch, minf(1.0, dt * 8.0))
		return
	# Araç: giderken hafif sallanır, ateş edince geri teper, arkasında toz kaldırır.
	anim_t += dt * v * 1.6
	model.position.y = sin(anim_t) * 0.035 if moving else 0.0
	var heavy: bool = d.get("proj", "") in ["shell", "arc"]
	var kick := recoil * (0.4 if heavy else 0.08)
	if turret != null:
		if target == null:
			turret.rotation.y = rotate_toward(turret.rotation.y, 0.0, dt * 1.6)
		turret.position = turret_base + Vector3(-sin(turret.rotation.y), 0, -cos(turret.rotation.y)) * kick
		model.rotation.x = lerpf(model.rotation.x, -kick * 0.12 * cos(turret.rotation.y), minf(1.0, dt * 14.0))
		model.rotation.z = lerpf(model.rotation.z, kick * 0.12 * sin(turret.rotation.y), minf(1.0, dt * 14.0))
	else:
		model.position.z = -kick
		model.rotation.x = lerpf(model.rotation.x, -kick * 0.15, minf(1.0, dt * 14.0))
	if moving and seen:
		dust_t -= dt
		if dust_t <= 0.0:
			dust_t = 0.3
			var back := Vector3(-sin(rotation.y), 0, -cos(rotation.y)) * radius
			Game.I.fx_puff(global_position + back + Vector3(randf_range(-0.5, 0.5), 0.3, 0), Game.I.dust_color, 1.0, 0.8, 0.5)


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
