class_name Game
extends Node3D
## Maç sahnesi: haritayı kurar, ekonomiyi yürütür, seçim ve emirleri yönetir.
## Hangi senaryonun ve tarafın oynanacağı Scenarios.chosen / Scenarios.side ile gelir.

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
	var pop_cap := Defs.POP_CAP
	var cranes := 1
	var hq: Building = null
	var mods := {}            # doktrin ve araştırmalardan gelen çarpanlar
	var researched: Array = []

signal selection_changed

const SPEEDS := [1.0, 0.5, 0.0]
const SPEED_NAMES := ["Normal", "Yavaş", "Duraklatıldı"]
const MISSILE_MULT := {inf = 1.0, light = 1.0, heavy = 0.8, bld = 1.3}

var teams: Array = []
var entities: Array = []
var points: Array = []
var selection: Array = []
var menu := ""                   # "build" ise inşa menüsü açık
var placing := ""                # yerleştirilen bina türü
var targeting: Building = null   # füze hedefi seçiliyor
var targeting_i := 0
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
	Scenarios.setup()
	teams = [TeamState.new(), TeamState.new()]
	for t in 2:
		apply_mods(t, Scenarios.doctrine(t).mods)
	_build_world()
	terrain = Terrain.new()
	add_child(terrain)
	fog = Fog.new()
	add_child(fog)
	cam = CameraRig.new()
	add_child(cam)
	for t in 2:
		_setup_base(t, Defs.MAP.bases[t])
	for p in Defs.MAP.points:
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
	var hp: Vector3 = teams[Defs.PLAYER].hq.position
	cam.focus = hp + Vector3(-signf(hp.x) * 10.0, 0, 0)
	recalc()
	fog.recompute()
	hud.toast("%s — %s. İnşa düğmesiyle Kışla kur, piyadeyle ikmal noktalarını al." % [
		Scenarios.country(Defs.PLAYER).name, Scenarios.doctrine(Defs.PLAYER).name], 10.0)
	var args := OS.get_cmdline_user_args()
	if args.has("--autotest"):
		add_child(load("res://tools/autotest.gd").new())
	elif args.has("--inputtest"):
		add_child(load("res://tools/inputtest.gd").new())
	elif args.has("--gallery"):
		add_child(load("res://tools/gallery.gd").new())


func set_speed(i: int) -> void:
	speed_i = i % SPEEDS.size()
	Engine.time_scale = SPEEDS[speed_i]


# ---------------------------------------------------------------- çarpanlar

func mod(team: int, key: String) -> float:
	return float(teams[team].mods.get(key, 1.0))


func apply_mods(team: int, mods: Dictionary) -> void:
	var ts: TeamState = teams[team]
	for k in mods:
		if k == "pop_cap":
			ts.pop_cap += int(mods[k])
			continue
		ts.mods[k] = float(ts.mods.get(k, 1.0)) * float(mods[k])
		if k.begins_with("hp_"):
			# Sahadaki birimlere de uygula.
			for e in entities:
				if e.team == team and e.cls == k.substr(3):
					e.max_hp *= float(mods[k])
					e.hp *= float(mods[k])


func unit_of(team: int, cls: String) -> String:
	var cc: String = Defs.COUNTRY[team]
	for id in Defs.UNITS:
		var ud: Dictionary = Defs.UNITS[id]
		if ud.cc == cc and ud.cls == cls:
			return id
	return ""


func unit_cost(team: int, id: String) -> int:
	var ud: Dictionary = Defs.UNITS[id]
	return int(round(float(ud.cost) * mod(team, "cost_" + ud.cls)))


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
	var ground: Color = Defs.MAP.ground
	Models.box(deco, Vector3(w + 80, 0.2, h + 80), Vector3(0, -0.2, 0), ground.darkened(0.45))
	Models.box(deco, Vector3(w, 0.2, h), Vector3(0, -0.1, 0), ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var r := rng.randf_range(4.0, 10.0)
		var c: Color = Defs.MAP.patch if i % 2 == 0 else ground.darkened(0.1)
		var m := Models.cyl(deco, r, r, 0.03, Vector3(rng.randf_range(-w * 0.47, w * 0.47), -0.005, rng.randf_range(-h * 0.45, h * 0.45)), c, Vector3.ZERO, 10)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _setup_base(team: int, pos: Vector3) -> void:
	var hq := spawn_building(Defs.bid(team, "hq"), team, pos, true)
	teams[team].hq = hq
	var dir := -signf(pos.x)
	for i in 2:
		spawn_unit(unit_of(team, "inf"), team, pos + Vector3(dir * 12.0, 0, -3.0 + i * 6.0))


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
		for e in entities:
			if e.is_building and e.team == t and e.built and e.d.has("income"):
				inc += float(e.d.income)
		if t == Defs.ENEMY:
			inc *= Defs.AI_INCOME_MULT
		ts.income = inc
		ts.money += inc * dt
		if ts.upgrading:
			ts.upgrade_t += dt
			if ts.upgrade_t >= Defs.TIER_TIME[ts.tier]:
				ts.upgrading = false
				ts.tier += 1
				_msg(t, "Kademe %d hazır: yeni birim ve binalar açıldı." % ts.tier)
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
			ts.pop += int(e.d.get("pop", 1))


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
		if targeting == e:
			cancel_targeting()
		if e.kind == "hq":
			_end(1 - e.team)
	recalc()


func on_building_done(b: Building) -> void:
	recalc()
	_msg(b.team, "%s hazır." % b.d.name)
	if b.team == Defs.PLAYER:
		hud.rebuild()


func on_point_captured(p: SupplyPoint) -> void:
	if p.owner_team == Defs.PLAYER:
		hud.toast("%s ele geçirildi (+$%d/sn)." % ["Petrol tesisi" if p.is_oil else "İkmal noktası", int(p.income)])
	elif fog.sees(Defs.PLAYER, p.position):
		hud.toast("Düşman bir nokta ele geçirdi.")


func on_missile_intercepted(src_team: int) -> void:
	hud.toast("Füzen hava savunma tarafından önlendi." if src_team == Defs.PLAYER else "Düşman füzesi önlendi!")


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


# ---------------------------------------------------------------- üretim

func queued_pop(team: int) -> int:
	var n := 0
	for e in entities:
		if e.is_building and e.team == team:
			for id in e.queue:
				n += int(Defs.UNITS[id].get("pop", 1)) * int(Defs.UNITS[id].get("count", 1))
	return n


func count_kind(team: int, kind: String, built_only := true) -> int:
	var n := 0
	for e in entities:
		if e.is_building and e.team == team and e.kind == kind and e.alive and (e.built or not built_only):
			n += 1
	return n


func plane_count(team: int) -> int:
	var n := 0
	for e in entities:
		if e.team != team:
			continue
		if e.is_building:
			for id in e.queue:
				if Defs.UNITS[id].cls in Defs.PLANE_CLASSES:
					n += 1
		elif e.cls in Defs.PLANE_CLASSES:
			n += 1
	return n


func queue_unit(b: Building, id: String) -> bool:
	var ud: Dictionary = Defs.UNITS[id]
	var ts: TeamState = teams[b.team]
	var cost := unit_cost(b.team, id)
	if not b.alive or not b.built:
		return false
	if ts.tier < int(ud.get("tier", 1)):
		_msg(b.team, "Kademe %d gerekli." % int(ud.tier))
		return false
	if b.queue.size() >= Defs.MAX_QUEUE:
		_msg(b.team, "Kuyruk dolu.")
		return false
	if ud.cls in Defs.PLANE_CLASSES and plane_count(b.team) >= Defs.PLANES_PER_AIRFIELD * count_kind(b.team, "havaalani"):
		_msg(b.team, "Pistler dolu: uçak için yeni bir Hava Alanı kur.")
		return false
	if ts.pop + queued_pop(b.team) + int(ud.get("pop", 1)) > ts.pop_cap:
		_msg(b.team, "Birlik sınırı doldu.")
		return false
	if ts.money < cost:
		_msg(b.team, "Yetersiz para.")
		return false
	ts.money -= cost
	b.queue.append(id)
	return true


func can_upgrade(team: int) -> String:
	## Boş metin: yükseltilebilir. Aksi hâlde neden yükseltilemediği.
	var ts: TeamState = teams[team]
	if ts.tier >= Defs.MAX_TIER:
		return "Azami kademe"
	if ts.upgrading:
		return "Yükseltiliyor"
	if ts.tier == 2 and count_kind(team, "teknoloji") == 0:
		return "Teknoloji Merkezi gerekli"
	if ts.money < Defs.TIER_COST[ts.tier]:
		return "Yetersiz para"
	return ""


func start_tier_upgrade(team: int) -> bool:
	var why := can_upgrade(team)
	if why != "":
		_msg(team, why + ".")
		return false
	var ts: TeamState = teams[team]
	ts.money -= Defs.TIER_COST[ts.tier]
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


# ---------------------------------------------------------------- inşa

func can_place(team: int, kind: String, pos: Vector3) -> bool:
	var hq: Building = teams[team].hq
	if Entity.flat(pos, hq.position) > Defs.BUILD_ZONE:
		return false
	var r: float = float(Defs.BUILDINGS[Defs.bid(team, kind)].radius)
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


func place_building(team: int, kind: String, pos: Vector3) -> bool:
	var id := Defs.bid(team, kind)
	var bd: Dictionary = Defs.BUILDINGS[id]
	var ts: TeamState = teams[team]
	if ts.tier < int(bd.get("tier", 1)):
		_msg(team, "Kademe %d gerekli." % int(bd.tier))
		return false
	if kind == "maden" and count_kind(team, "maden", false) >= Defs.MAX_MINES:
		_msg(team, "En çok %d Maden Ocağı kurulabilir." % Defs.MAX_MINES)
		return false
	if ts.money < float(bd.cost):
		_msg(team, "Yetersiz para.")
		return false
	if not can_place(team, kind, pos):
		_msg(team, "Buraya kurulamaz. Sarı çemberin içinde, düz ve boş bir yer seç.")
		return false
	ts.money -= float(bd.cost)
	var b := spawn_building(id, team, pos)
	if team == Defs.PLAYER and not b.crane_active:
		hud.toast("Vinç meşgul: inşaat sıraya alındı. İnşa menüsünden vinç alabilirsin.")
	return true


func begin_placing(kind: String) -> void:
	cancel_targeting()
	placing = kind
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


func nearest_building(team: int, kind: String, pos: Vector3):
	var best = null
	var bd := 1e9
	for e in entities:
		if e.is_building and e.team == team and e.kind == kind and e.built and e.alive:
			var dd := Entity.flat(pos, e.position)
			if dd < bd:
				bd = dd
				best = e
	return best


# ---------------------------------------------------------------- araştırma

func can_research(team: int, rid: String) -> bool:
	if teams[team].researched.has(rid):
		return false
	for e in entities:
		if e.is_building and e.team == team and e.research_id == rid:
			return false
	return true


func start_research(b: Building, r: Dictionary) -> bool:
	var ts: TeamState = teams[b.team]
	if not b.built or b.research_id != "" or not can_research(b.team, r.id):
		return false
	if ts.money < float(r.cost):
		_msg(b.team, "Yetersiz para.")
		return false
	ts.money -= float(r.cost)
	b.research_id = r.id
	b.research_t = 0.0
	return true


func finish_research(b: Building) -> void:
	var r := b.research_def()
	b.research_id = ""
	b.research_t = 0.0
	teams[b.team].researched.append(r.id)
	apply_mods(b.team, r.mods)
	_msg(b.team, "Araştırma tamamlandı: %s." % r.name)
	if b.team == Defs.PLAYER:
		hud.rebuild()


# ---------------------------------------------------------------- füzeler

func missile_info(team: int, i: int) -> Dictionary:
	var m: Dictionary = Scenarios.country(team).missiles[i].duplicate()
	m.cost = int(round(float(m.cost) * mod(team, "missile_cost")))
	m.cd = float(m.cd) * mod(team, "missile_cd")
	return m


func launch_missile(b: Building, i: int, pos: Vector3) -> bool:
	var ts: TeamState = teams[b.team]
	var m := missile_info(b.team, i)
	if not b.built or not b.alive:
		return false
	if ts.tier < int(m.tier):
		_msg(b.team, "Kademe %d gerekli." % int(m.tier))
		return false
	if b.missile_ready[i] > 0.0:
		_msg(b.team, "Füze henüz hazır değil.")
		return false
	if not b.powered():
		_msg(b.team, "Enerji yetersiz.")
		return false
	if not fog.sees(b.team, pos):
		_msg(b.team, "Hedef görülmüyor. Önce keşif yap.")
		return false
	if ts.money < float(m.cost):
		_msg(b.team, "Yetersiz para.")
		return false
	ts.money -= float(m.cost)
	b.missile_ready[i] = m.cd
	var s := Shot.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.35
	cm.height = 2.4
	cm.radial_segments = 6
	s.mesh = cm
	s.material_override = Models.glow(Color(1.0, 0.9, 0.7))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.src = b
	s.src_team = b.team
	s.start = b.muzzle_pos()
	s.end = Vector3(pos.x, 0.3, pos.z)
	s.speed = 38.0
	s.arc = 38.0
	s.base = float(m.dmg)
	s.mult = MISSILE_MULT
	s.splash = float(m.splash)
	s.boom = 6.0
	if not m.get("hypersonic", false):
		for e in entities:
			if e.is_building and e.team != b.team and e.kind == "sam" and e.built and e.powered():
				if Entity.flat(e.position, pos) <= e.wrange() and randf() < Defs.INTERCEPT_CHANCE:
					s.intercept_at = randf_range(0.6, 0.85)
					fx_tracer(e.muzzle_pos(), e.muzzle_pos() + Vector3(0, 30, 0), Color(1, 1, 1), 0.15, 0.4)
					break
	add_child(s)
	s.launch()
	if b.team == Defs.PLAYER:
		hud.toast("%s fırlatıldı." % m.name)
	else:
		hud.toast("Düşman füzesi geliyor: %s!" % m.name)
	return true


func begin_targeting(b: Building, i: int) -> void:
	if placing != "":
		cancel_placing()
	targeting = b
	targeting_i = i
	hud.toast("Hedef için haritada görebildiğin bir yere dokun.", 5.0)
	hud.rebuild()


func cancel_targeting() -> void:
	if targeting == null:
		return
	targeting = null
	hud.rebuild()


func try_launch(world: Vector3) -> void:
	if targeting != null and is_instance_valid(targeting) and launch_missile(targeting, targeting_i, world):
		cancel_targeting()


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


# ---------------------------------------------------------------- hasar ve efektler

func splash_damage(pos: Vector3, r: float, base: float, mult: Dictionary, src_team: int, tag := "", attacker = null) -> void:
	for e in entities.duplicate():
		if e.alive and e.team != src_team and not e.is_air:
			if Entity.flat(e.global_position, pos) - e.radius <= r:
				e.take_damage(base * float(mult.get(e.armor, 0.0)), attacker, tag)


func fx_tracer(a: Vector3, b: Vector3, col: Color, width := 0.07, secs := 0.07) -> void:
	var length := a.distance_to(b)
	if length < 0.1:
		return
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, length)
	m.mesh = bm
	m.material_override = Models.glow(col)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	var up := Vector3.UP if absf((b - a).normalized().y) < 0.98 else Vector3.RIGHT
	m.look_at_from_position((a + b) * 0.5, b, up)
	var tw := create_tween()
	tw.tween_interval(secs)
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
	s.tag = src.d.get("tag", "")
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
