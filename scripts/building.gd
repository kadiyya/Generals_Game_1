class_name Building
extends Entity
## Bina: inşa süresi, üretim kuyruğu, araştırma, füze bekleme süreleri ve (hava savunma için) silah.

var kind := ""
var built := false
var build_t := 0.0
var build_time := 1.0
var queue: Array[String] = []
var prod_t := 0.0
var crane_active := true
var crane: Node3D = null
var research_id := ""
var research_t := 0.0
var missile_ready: Array = []   # her füze tipi için kalan bekleme süresi


func setup(id: String, t: int, def: Dictionary) -> void:
	super.setup(id, t, def)
	is_building = true
	kind = d.kind
	build_time = float(d.get("time", 0.0))
	rotation.y = 0.0 if position.x < 0.0 else PI
	if kind == "fuze":
		for m in Scenarios.country(t).missiles:
			missile_ready.append(0.0)


func start(instant: bool) -> void:
	if instant or build_time <= 0.0:
		built = true
	elif d.get("field", false):
		# Piyadenin kurduğu alan yapısı: vinç gerekmez.
		hp = max_hp * 0.2
		model.scale.y = 0.15
	else:
		hp = max_hp * 0.2
		model.scale.y = 0.15
		crane = Models.crane()
		crane.position = Vector3(radius * 0.8, 0, -radius * 0.8)
		add_child(crane)


func aim_pos() -> Vector3:
	return global_position + Vector3(0, 1.5, 0)


func muzzle_pos() -> Vector3:
	return global_position + Vector3(0, 2.6, 0)


func powered() -> bool:
	var ts = Game.I.teams[team]
	return int(d.get("power", 0)) >= 0 or ts.power_used <= ts.power_prod


func prod_fraction() -> float:
	if queue.is_empty():
		return 0.0
	return clampf(prod_t / float(Defs.UNITS[queue[0]].time), 0.0, 1.0)


func research_def() -> Dictionary:
	for r in Scenarios.RESEARCH:
		if r.id == research_id:
			return r
	return {}


func _process(dt: float) -> void:
	if not alive:
		return
	if not built:
		if crane != null:
			crane.visible = crane_active
		if not crane_active:
			return
		build_t += dt
		var f := clampf(build_t / build_time, 0.0, 1.0)
		model.scale.y = lerpf(0.15, 1.0, f)
		hp = minf(max_hp, hp + max_hp * 0.8 * dt / build_time)
		if f >= 1.0:
			built = true
			if crane != null:
				crane.queue_free()
			crane = null
			Game.I.on_building_done(self)
		return
	var ok := powered()
	var rate := 1.0 if ok else 0.4
	if not queue.is_empty():
		var ts = Game.I.teams[team]
		var need: float = float(Defs.UNITS[queue[0]].time)
		if prod_t < need:
			prod_t += dt * rate
		elif ts.pop + int(Defs.UNITS[queue[0]].get("pop", 1)) <= ts.pop_cap:
			_spawn(queue.pop_front())
			prod_t = 0.0
	if research_id != "":
		research_t += dt * rate
		if research_t >= float(research_def().time):
			Game.I.finish_research(self)
	for i in missile_ready.size():
		if missile_ready[i] > 0.0:
			missile_ready[i] = maxf(0.0, missile_ready[i] - dt * rate)
	if has_weapon() and ok:
		cd_timer -= dt
		scan_timer -= dt
		valid_target()
		if target == null and scan_timer <= 0.0:
			scan_timer = 0.3
			target = find_target(wrange())
		if target != null:
			var dist: float = flat(position, target.global_position) - target.radius
			if dist > wrange():
				target = null
			elif cd_timer <= 0.0:
				fire(target)


func _spawn(id: String) -> void:
	var g := Game.I
	var ud: Dictionary = Defs.UNITS[id]
	var dir := Vector3(-signf(position.x), 0, 0)
	if dir.x == 0.0:
		dir = Vector3(1, 0, 0)
	for i in int(ud.get("count", 1)):
		var jit := Vector3(randf_range(-2.5, 2.5), 0, randf_range(-3.5, 3.5))
		var u = g.spawn_unit(id, team, g.terrain.nearest_free(position + dir * (radius + 2.5) + jit * 0.3))
		if u is Unit:
			u.go(position + dir * (radius + 8.0) + jit, false)
		elif u is AirUnit:
			u.set_patrol(position + dir * 14.0 + jit)
	g.recalc()


func _on_damaged(_attacker) -> void:
	if team == Defs.PLAYER:
		Game.I.alert_base()
