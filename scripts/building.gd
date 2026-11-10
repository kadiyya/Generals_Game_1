class_name Building
extends Entity
## Bina: inşa süresi, üretim kuyruğu ve (Hisar için) silah.

var built := false
var build_t := 0.0
var build_time := 1.0
var queue: Array[String] = []
var prod_t := 0.0
var pad = null


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	is_building = true
	build_time = float(d.get("time", 0.0))
	rotation.y = 0.0 if t == Defs.PLAYER else PI


func start(instant: bool) -> void:
	if instant or build_time <= 0.0:
		built = true
	else:
		hp = max_hp * 0.2
		model.scale.y = 0.15


func aim_pos() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


func muzzle_pos() -> Vector3:
	return global_position + Vector3(0, 2.2, 0)


func powered() -> bool:
	var ts = Game.I.teams[team]
	return ts.power_used <= ts.power_prod


func prod_fraction() -> float:
	if queue.is_empty():
		return 0.0
	return clampf(prod_t / float(Defs.UNITS[queue[0]].time), 0.0, 1.0)


func _process(dt: float) -> void:
	if not alive:
		return
	if not built:
		build_t += dt
		var f := clampf(build_t / build_time, 0.0, 1.0)
		model.scale.y = lerpf(0.15, 1.0, f)
		hp = minf(max_hp, hp + max_hp * 0.8 * dt / build_time)
		if f >= 1.0:
			built = true
			Game.I.on_building_done(self)
		return
	var needs_power: bool = int(d.get("power", 0)) < 0
	var ok := not needs_power or powered()
	if not queue.is_empty():
		var ts = Game.I.teams[team]
		var need: float = float(Defs.UNITS[queue[0]].time)
		if prod_t < need:
			prod_t += dt * (1.0 if ok else 0.4)
		elif ts.pop < Defs.POP_CAP:
			_spawn(queue.pop_front())
			prod_t = 0.0
	if has_weapon() and ok:
		cd_timer -= dt
		scan_timer -= dt
		valid_target()
		if target == null and scan_timer <= 0.0:
			scan_timer = 0.3
			target = find_target(float(d.range))
		if target != null:
			var dist: float = flat(position, target.position) - target.radius
			if dist > float(d.range):
				target = null
			elif cd_timer <= 0.0:
				fire(target)


func _spawn(id: String) -> void:
	var g := Game.I
	var dir := Vector3(-signf(position.x), 0, 0)
	if dir.x == 0.0:
		dir = Vector3(1, 0, 0)
	var u = g.spawn_unit(id, team, position + dir * (radius + 1.5))
	var rp := position + dir * (radius + 7.0) + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-3.5, 3.5))
	if u is Unit:
		u.go(rp, false)
	elif u is AirUnit:
		u.set_patrol(position + dir * 14.0)
	g.teams[team].pop += 1


func _on_damaged(_attacker) -> void:
	if team == Defs.PLAYER:
		Game.I.alert_base()
