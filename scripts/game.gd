class_name Game
extends Node3D
## Ana sahne: haritayı kurar, ekonomiyi yürütür, seçim ve emirleri yönetir.

static var I: Game

class TeamState:
	var money: float = Defs.START_MONEY
	var tier := 1
	var upgrading := false
	var upgrade_t := 0.0
	var income := 0.0
	var power_prod := 0
	var power_used := 0
	var pop := 0
	var cranes := 1
	var hq: Building = null

signal selection_changed

const SPEEDS := [1.0, 0.5, 0.0]
const SPEED_NAMES := ["Normal", "Yavaş", "Duraklatıldı"]

var teams: Array = []
var entities: Array = []
var points: Array = []
var selection: Array = []
var menu := ""            # "build" ise inşa menüsü açık
var placing := ""
var time := 0.0
var over := false
var winner := -1
var speed_i := 0
var terrain: Terrain
var fog: Fog
var hud: Hud
var cam: CameraRig
var controls: Controls
var zone_ring: MeshInstance3D
var _recalc_t := 0.0
var _alert_t := -100.0


func _ready() -> void:
	I = self
	Engine.time_scale = 1.0
	get_tree().paused = false
	teams = [TeamState.new(), TeamState.new()]
	_build_world()
	terrain = Terrain.new()
	add_child(terrain)
	fog = Fog.new()
	add_child(fog)
	cam = CameraRig.new()
	add_child(cam)
	_setup_base(Defs.PLAYER, Defs.BASES[Defs.PLAYER])
	_setup_base(Defs.ENEMY, Defs.BASES[Defs.ENEMY])
	for p in Defs.POINTS:
		var sp := SupplyPoint.new()
		add_child(sp)
		sp.setup(Vector3(p[0], 0, p[1]), p[2], p[3], p[4])
		points.append(sp)
	zone_ring = Models.ring(Defs.BUILD_ZONE, Color(1.0, 0.85, 0.2))
	zone_ring.position = teams[Defs.PLAYER].hq.position + Vector3(0, 0.15, 0)
	zone_ring.visible = false
	add_child(zone_ring)
	hud = Hud.new()
	add_child(hud)
	controls = Controls.new()
	add_child(controls)
	add_child(EnemyAI.new())
	cam.focus = teams[Defs.PLAYER].hq.position + Vector3(10, 0, 0)
	recalc()
	fog.recompute()
	hud.toast("İnşa düğmesiyle Kışla kur. Piyadelerle ikmal noktalarını ele geçir. Yetişemezsen Hız düğmesiyle duraklat.", 10.0)
	var args := OS.get_cmdline_user_args()
	if args.has("--autotest"):
		add_child(load("res://tools/autotest.gd").new())
	elif args.has("--inputtest"):
		add_child(load("res://tools/inputtest.gd").new())


func set_speed(i: int) -> void:
	speed_i = i % SPEEDS.size()
	Engine.time_scale = SPEEDS[speed_i]


# ---------------------------------------------------------------- dünya

func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.07, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.8, 0.86)
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

	var deco := Node3D.new()
	add_child(deco)
	var w := Defs.MAP_W
	var h := Defs.MAP_H
	Models.box(deco, Vector3(w + 80, 0.2, h + 80), Vector3(0, -0.2, 0), Color(0.2, 0.25, 0.17))
	Models.box(deco, Vector3(w, 0.2, h), Vector3(0, -0.1, 0), Color(0.38, 0.44, 0.28))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var r := rng.randf_range(4.0, 10.0)
		var c := Color(0.33, 0.4, 0.25) if i % 2 == 0 else Color(0.43, 0.46, 0.3)
		var m := Models.cyl(deco, r, r, 0.03, Vector3(rng.randf_range(-w * 0.47, w * 0.47), -0.005, rng.randf_range(-h * 0.47, h * 0.38)), c, Vector3.ZERO, 10)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for i in 80:
		# ağaçlar: kuzey, doğu ve batı kenarlarının dışında (güney deniz)
		var x := rng.randf_range(-w * 0.5 - 25, w * 0.5 + 25)
		var z := -(h * 0.5 + rng.randf_range(2.0, 25.0))
		if i % 3 == 0:
			z = rng.randf_range(-h * 0.5, h * 0.4)
			x = (w * 0.5 + rng.randf_range(2.0, 25.0)) * (1.0 if i % 2 == 0 else -1.0)
		var th := rng.randf_range(2.5, 4.5)
		Models.cyl(deco, 0.15, 0.2, 1.0, Vector3(x, 0.5, z), Models.WOOD)
		Models.cyl(deco, 0.0, th * 0.4, th, Vector3(x, 1.0 + th * 0.5, z), Color(0.16, 0.33, 0.18), Vector3.ZERO, 6)


func _setup_base(team: int, pos: Vector3) -> void:
	var hq := spawn_building("hq", team, pos, true)
	teams[team].hq = hq
	var dir := -signf(pos.x)
	for i in 2:
		spawn_unit("manga", team, pos + Vector3(dir * 12.0, 0, -3.0 + i * 6.0))


func spawn_unit(id: String, team: int, pos: Vector3) -> Entity:
	var def: Dictionary = Defs.UNITS[id]
	var u: Entity
	if def.get("air", false):
		u = AirUnit.new()
	else:
		u = Unit.new()
	add_child(u)
	u.position = Vector3(pos.x, 0, pos.z)
	u.setup(id, team, def)
	entities.append(u)
	return u


func spawn_building(id: String, team: int, pos: Vector3, instant := false) -> Building:
	var b := Building.new()
	add_child(b)
	b.position = Vector3(pos.x, 0, pos.z)
	b.setup(id, team, Defs.BUILDINGS[id])
	b.start(instant)
	entities.append(b)
	terrain.block_circle(b.position, b.radius * 0.85, true)
	recalc()
	return b


# ---------------------------------------------------------------- döngü

func _process(dt: float) -> void:
	if over:
		return
	time += dt
	for t in 2:
		var ts: TeamState = teams[t]
		var inc := 0.0
		if ts.hq != null and is_instance_valid(ts.hq) and ts.hq.alive:
			inc += Defs.HQ_INCOME
		for p in points:
			if p.owner_team == t:
				inc += p.income
		if t == Defs.ENEMY:
			inc *= Defs.AI_INCOME_MULT
		ts.income = inc
		ts.money += inc * dt
		if ts.upgrading:
			ts.upgrade_t += dt
			if ts.upgrade_t >= Defs.TIER2_TIME:
				ts.upgrading = false
				ts.tier = 2
				_msg(t, "Kademe 2 hazır: İHA İstasyonu, Hisar ve Fırtına açıldı.")
				if t == Defs.PLAYER:
					hud.rebuild()
	_recalc_t -= dt
	if _recalc_t <= 0.0:
		_recalc_t = 0.3
		recalc()
		_heal(0.3)
	_separate()


func recalc() -> void:
	var building := [0, 0]
	for t in 2:
		teams[t].power_prod = 0
		teams[t].power_used = 0
		teams[t].pop = 0
	for e in entities:
		if not e.alive:
			continue
		var ts: TeamState = teams[e.team]
		if e.is_building:
			if e.built:
				var p: int = int(e.d.get("power", 0))
				if p > 0:
					ts.power_prod += p
				else:
					ts.power_used -= p
			else:
				# Her vinç aynı anda bir inşaat yürütür; fazlası sırada bekler.
				e.crane_active = building[e.team] < ts.cranes
				building[e.team] += 1
		else:
			ts.pop += 1


func _heal(dt: float) -> void:
	for e in entities:
		if e.is_building or not e.alive or e.hp >= e.max_hp:
			continue
		var hq: Building = teams[e.team].hq
		if hq != null and is_instance_valid(hq) and hq.alive and Entity.flat(e.global_position, hq.position) <= Defs.HEAL_RADIUS:
			e.hp = minf(e.max_hp, e.hp + e.max_hp * Defs.HEAL_RATE * dt)
			if e is Unit:
				e.update_figures()


func _separate() -> void:
	var ground: Array = []
	var blds: Array = []
	for e in entities:
		if not e.alive:
			continue
		if e.is_building:
			blds.append(e)
		elif not e.is_air:
			ground.append(e)
	var n := ground.size()
	var prev: Array = []
	for u in ground:
		prev.append(u.position)
	for i in n:
		var a: Entity = ground[i]
		for j in range(i + 1, n):
			var b: Entity = ground[j]
			var dx := a.position.x - b.position.x
			var dz := a.position.z - b.position.z
			var min_d := (a.radius + b.radius) * 0.85
			var d2 := dx * dx + dz * dz
			if d2 < min_d * min_d:
				var dd := sqrt(d2)
				if dd < 0.01:
					dx = 0.1 * (i - j)
					dz = 0.1
					dd = 0.15
				var push := (min_d - dd) * 0.5 / dd
				a.position += Vector3(dx, 0, dz) * push
				b.position -= Vector3(dx, 0, dz) * push
		for bb in blds:
			var b: Entity = bb
			var dx := a.position.x - b.position.x
			var dz := a.position.z - b.position.z
			var min_d: float = b.radius * 0.95 + a.radius
			var d2 := dx * dx + dz * dz
			if d2 < min_d * min_d and d2 > 0.0001:
				var dd := sqrt(d2)
				var over_d := min_d - dd
				a.position += Vector3(dx, 0, dz) / dd * over_d + Vector3(-dz, 0, dx) / dd * over_d * 0.5
	for i in n:
		if terrain.solid(ground[i].position) and not terrain.solid(prev[i]):
			ground[i].position = prev[i]


# ---------------------------------------------------------------- olaylar

func on_entity_died(e: Entity) -> void:
	entities.erase(e)
	if selection.has(e):
		selection.erase(e)
		selection_changed.emit()
	if e is Building:
		terrain.block_circle(e.position, e.radius * 0.85, false)
		if e.def_id == "hq":
			_end(1 - e.team)
	recalc()


func on_building_done(b: Building) -> void:
	recalc()
	_msg(b.team, "%s hazır." % b.d.name)
	if b.team == Defs.PLAYER and selection.has(b):
		hud.rebuild()


func on_point_captured(p: SupplyPoint) -> void:
	if p.owner_team == Defs.PLAYER:
		hud.toast("%s ele geçirildi (+$%d/sn)." % ["Petrol tesisi" if p.is_oil else "İkmal noktası", int(p.income)])
	elif fog.sees(Defs.PLAYER, p.position):
		hud.toast("Düşman bir nokta ele geçirdi.")


func alert_base() -> void:
	if time - _alert_t > 12.0:
		_alert_t = time
		hud.toast("Üssün saldırı altında!")


func _end(w: int) -> void:
	over = true
	winner = w
	hud.show_end(w == Defs.PLAYER)


func _msg(team: int, text: String) -> void:
	if team == Defs.PLAYER and hud != null:
		hud.toast(text)


# ---------------------------------------------------------------- ekonomi ve inşa

func queued_total(team: int) -> int:
	var n := 0
	for e in entities:
		if e.is_building and e.team == team:
			n += e.queue.size()
	return n


func queue_unit(b: Building, id: String) -> bool:
	var ud: Dictionary = Defs.UNITS[id]
	var ts: TeamState = teams[b.team]
	if not b.alive or not b.built:
		return false
	if ts.tier < int(ud.get("tier", 1)):
		_msg(b.team, "Kademe 2 gerekli.")
		return false
	if b.queue.size() >= Defs.MAX_QUEUE:
		_msg(b.team, "Kuyruk dolu.")
		return false
	if ts.pop + queued_total(b.team) >= Defs.POP_CAP:
		_msg(b.team, "Birlik sınırı doldu.")
		return false
	if ts.money < float(ud.cost):
		_msg(b.team, "Yetersiz para.")
		return false
	ts.money -= float(ud.cost)
	b.queue.append(id)
	return true


func start_tier_upgrade(team: int) -> bool:
	var ts: TeamState = teams[team]
	if ts.tier >= 2 or ts.upgrading:
		return false
	if ts.money < Defs.TIER2_COST:
		_msg(team, "Yetersiz para.")
		return false
	ts.money -= Defs.TIER2_COST
	ts.upgrading = true
	ts.upgrade_t = 0.0
	return true


func buy_crane(team: int) -> bool:
	var ts: TeamState = teams[team]
	if ts.cranes >= Defs.MAX_CRANES:
		return false
	if ts.money < Defs.CRANE_COST:
		_msg(team, "Yetersiz para.")
		return false
	ts.money -= Defs.CRANE_COST
	ts.cranes += 1
	recalc()
	_msg(team, "Yeni vinç hazır: aynı anda %d inşaat." % ts.cranes)
	return true


func can_place(team: int, id: String, pos: Vector3) -> bool:
	var hq: Building = teams[team].hq
	if Entity.flat(pos, hq.position) > Defs.BUILD_ZONE:
		return false
	var r: float = float(Defs.BUILDINGS[id].radius)
	# Binanın oturacağı alan düz kara olmalı.
	for off in [Vector3.ZERO, Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
		var q: Vector3 = pos + off
		if absf(q.x) > Defs.MAP_W * 0.5 - 1.0 or absf(q.z) > Defs.MAP_H * 0.5 - 1.0 or not terrain.is_land(q):
			return false
	for e in entities:
		if e.is_building and Entity.flat(pos, e.position) < r + e.radius + 2.0:
			return false
	for p in points:
		if Entity.flat(pos, p.position) < r + SupplyPoint.RADIUS:
			return false
	return true


func place_building(team: int, id: String, pos: Vector3) -> bool:
	var bd: Dictionary = Defs.BUILDINGS[id]
	var ts: TeamState = teams[team]
	if ts.tier < int(bd.get("tier", 1)):
		_msg(team, "Kademe 2 gerekli.")
		return false
	if ts.money < float(bd.cost):
		_msg(team, "Yetersiz para.")
		return false
	if not can_place(team, id, pos):
		_msg(team, "Buraya kurulamaz. Sarı çemberin içinde, düz ve boş bir yer seç.")
		return false
	ts.money -= float(bd.cost)
	var b := spawn_building(id, team, pos)
	if team == Defs.PLAYER and not b.crane_active:
		hud.toast("Vinç meşgul: inşaat sıraya alındı. Karargâhtan vinç alabilirsin.")
	return true


func begin_placing(id: String) -> void:
	placing = id
	zone_ring.visible = true
	hud.toast("Yerleştirmek için sarı çemberin içinde bir yere dokun.", 5.0)
	hud.rebuild()


func cancel_placing() -> void:
	placing = ""
	zone_ring.visible = false
	hud.rebuild()


func try_place(world: Vector3) -> void:
	if place_building(Defs.PLAYER, placing, world):
		cancel_placing()


func nearest_building(team: int, id: String, pos: Vector3):
	var best = null
	var bd := 1e9
	for e in entities:
		if e.is_building and e.team == team and e.def_id == id and e.built and e.alive:
			var dd := Entity.flat(pos, e.position)
			if dd < bd:
				bd = dd
				best = e
	return best


# ---------------------------------------------------------------- seçim

func select(list: Array) -> void:
	for e in selection:
		if is_instance_valid(e):
			e.set_selected(false)
	selection = list.duplicate()
	menu = ""
	for e in selection:
		e.set_selected(true)
	selection_changed.emit()


func clear_selection() -> void:
	if selection.is_empty() and menu == "":
		return
	select([])


func open_build_menu() -> void:
	select([])
	menu = "build"
	selection_changed.emit()


func selected_units() -> Array:
	var out: Array = []
	for e in selection:
		if is_instance_valid(e) and e.alive and not e.is_building:
			out.append(e)
	return out


func select_category(cat: String) -> void:
	var list: Array = []
	for e in entities:
		if e.team == Defs.PLAYER and not e.is_building and e.alive:
			if cat == "" or e.d.cat == cat:
				list.append(e)
	select(list)


func select_same_on_screen(src: Entity) -> void:
	var rect := get_viewport().get_visible_rect()
	var list: Array = []
	for e in entities:
		if e.team == Defs.PLAYER and e.def_id == src.def_id and e.alive:
			if cam.camera.is_position_behind(e.global_position):
				continue
			if rect.has_point(cam.camera.unproject_position(e.global_position)):
				list.append(e)
	select(list)


func pick_entity(sp: Vector2):
	var best = null
	var best_s := 1.0
	for e in entities:
		if not e.alive or not e.seen:
			continue
		var wp: Vector3 = e.aim_pos()
		if cam.camera.is_position_behind(wp):
			continue
		var p := cam.camera.unproject_position(wp)
		var edge := cam.camera.unproject_position(wp + Vector3(e.radius, 0, 0))
		var pr := maxf(34.0, absf(edge.x - p.x) * 1.25)
		var s := p.distance_to(sp) / pr
		if not e.is_building:
			s *= 0.8
		if s < best_s:
			best_s = s
			best = e
	return best


# ---------------------------------------------------------------- emirler

func order_move(units: Array, pos: Vector3, attack_move: bool) -> void:
	var ground: Array = []
	for u in units:
		if u is AirUnit:
			u.set_patrol(pos)
		elif u is Unit:
			ground.append(u)
	var n := ground.size()
	if n > 0:
		var cols := int(ceil(sqrt(float(n))))
		var rows := int(ceil(float(n) / cols))
		for i in n:
			var off := Vector3((i % cols - (cols - 1) * 0.5) * 3.0, 0, (i / cols - (rows - 1) * 0.5) * 3.0)
			ground[i].go(pos + off, attack_move)
	if not units.is_empty() and units[0].team == Defs.PLAYER:
		fx_marker(pos, Color(0.3, 1.0, 0.4))


func order_attack(units: Array, e: Entity) -> void:
	for u in units:
		if u is AirUnit:
			u.set_patrol(e.global_position)
			if u.has_weapon() and u.can_hit(e):
				u.target = e
		elif u is Unit:
			if u.has_weapon() and u.can_hit(e):
				u.attack(e)
			else:
				u.go(e.global_position, true)
	if not units.is_empty() and units[0].team == Defs.PLAYER:
		fx_marker(e.global_position, Color(1.0, 0.3, 0.2))


func order_stop(units: Array) -> void:
	for u in units:
		if u is Unit:
			u.stop()
		elif u is AirUnit:
			u.set_patrol(u.global_position)


func order_retreat(units: Array) -> void:
	if units.is_empty():
		return
	var hq: Building = teams[units[0].team].hq
	var pos := hq.position + Vector3(-signf(hq.position.x) * 12.0, 0, 0)
	order_move(units, pos, false)


# ---------------------------------------------------------------- efektler

func fx_tracer(a: Vector3, b: Vector3) -> void:
	var len := a.distance_to(b)
	if len < 0.1:
		return
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, len)
	m.mesh = bm
	m.material_override = Models.glow(Color(1.0, 0.9, 0.4))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT
	m.look_at_from_position((a + b) * 0.5, b, up)
	var tw := create_tween()
	tw.tween_interval(0.07)
	tw.tween_callback(m.queue_free)


func fx_shot(src: Entity, target: Entity, base: float, speed: float, arc: float, homing: bool) -> void:
	var s := Shot.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	sm.radial_segments = 6
	sm.rings = 3
	s.mesh = sm
	s.material_override = Models.glow(Color(1.0, 0.75, 0.3) if not homing else Color(0.95, 0.95, 0.95))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.src = src
	s.src_team = src.team
	s.target = target
	s.start = src.muzzle_pos()
	s.end = target.aim_pos()
	s.speed = speed
	s.arc = arc
	s.homing = homing
	s.base = base
	s.mult = src.d.mult
	s.splash = float(src.d.get("splash", 0.0))
	add_child(s)
	s.launch()


func fx_explosion(pos: Vector3, size: float) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	m.mesh = sm
	m.material_override = Models.glow(Color(1.0, 0.6, 0.15))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * 0.3
	var tw := create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * size * 2.0, 0.22)
	tw.tween_callback(m.queue_free)


func fx_marker(pos: Vector3, c: Color) -> void:
	var m := Models.ring(1.6, c)
	add_child(m)
	m.global_position = Vector3(pos.x, 0.15, pos.z)
	var tw := create_tween()
	tw.tween_property(m, "scale", Vector3(0.1, 0.2, 0.1), 0.45)
	tw.tween_callback(m.queue_free)
