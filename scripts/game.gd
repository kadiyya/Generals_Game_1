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
	var ab_cd := 0.0          # doktrin yeteneği bekleme süresi
	var tanker_until := -1.0
	var obj_prog := 0.0       # görev: tutulan süre ya da yok edilen hedef sayısı
	var obj_note := 0         # duyurulan görev eşiği (%50, %80)

signal selection_changed

const MISSILE_MULT := {inf = 1.0, light = 1.0, heavy = 0.8, bld = 1.3}

var teams: Array = []
var entities: Array = []
var points: Array = []
var bridges: Array = []
var ais: Array = []
var selection: Array = []
var menu := ""                   # "build" ise inşa menüsü açık
var placing := ""                # yerleştirilen bina türü
var targeting: Building = null   # füze hedefi seçiliyor
var targeting_i := 0
var time := 0.0
var over := false
var winner := -1
var terrain: Terrain
var fog: Fog
var hud: Hud
var cam: CameraRig
var controls: Controls
var zone_ring: MeshInstance3D
var _recalc_t := 0.0
var _alert_t := -100.0
var dust_color := Color(0.6, 0.55, 0.42)
var houses: Array = []
var sfx: Sfx
const BUCKET := 16.0
var buckets := {}        # uzamsal ızgara: hücre -> o hücredeki varlıklar (her kare yeniden kurulur)
var mines: Array = []            # {team, pos, node}
var ab_targeting := false        # doktrin yeteneği için hedef seçiliyor
var rally_for: Building = null   # toplanma noktası seçiliyor
var patrol_pick := false         # devriye noktası seçiliyor
var bridge_pick := false         # yıkılacak köprü seçiliyor
var rally_flag: Node3D = null
var groups: Array = [[], [], []] # kayıtlı birlik grupları
var tutorial_on := false
var _save_t := 60.0
const SAVE_PATH := "user://kayit.json"
const SAVE_V := 2
var _tick_t := 0.0
var _zone_rings: Array = []
var deposits: Array = []
var _dep_t := 90.0
var _supply_t := 0.0
var _supply_src: Array = [[], []]   # [taraf] -> [[konum, yarıçap], ...]
var _oos_note := -100.0
var pings: Array = []               # küçük haritada yanıp sönen yerler: [konum, bitiş zamanı]
var _puff: SphereMesh = null


func _ready() -> void:
	I = self
	Engine.time_scale = 1.0
	get_tree().paused = false
	Scenarios.setup()
	teams = []
	for t in Defs.N:
		teams.append(TeamState.new())
		apply_mods(t, Scenarios.doctrine(t).mods)
	_build_world()
	terrain = Terrain.new()
	add_child(terrain)
	fog = Fog.new()
	add_child(fog)
	sfx = Sfx.new()
	add_child(sfx)
	cam = CameraRig.new()
	add_child(cam)
	for p in Defs.MAP.points:
		var sp := SupplyPoint.new()
		add_child(sp)
		sp.setup_point(Vector3(p[0], 0, p[1]), p[2], p[3], p[4], p[5])
		points.append(sp)
	for bd in terrain.bridge_data:
		var br := Bridge.new()
		add_child(br)
		br.setup_bridge(bd)
		bridges.append(br)
	var loading := not Scenarios.load_data.is_empty()
	if not loading:
		for t in Defs.N:
			_setup_base(t, Defs.MAP.team_bases[t])
		for i in Defs.DEPOSIT_FIRST:
			spawn_deposit(false)
	for h in terrain.house_data:
		var g := Garrison.new()
		add_child(g)
		g.setup(Vector3(h[0], 0, h[1]), h[2])
		houses.append(g)
	var marked := {}
	for t in [Defs.leader(0), Defs.leader(1)]:
		var o := Scenarios.objective(t)
		if o.get("type", "") == "hold" and not marked.has(o.point):
			marked[o.point] = true
			var r := Models.ring(SupplyPoint.RADIUS + 1.2, Color(1.0, 0.8, 0.2))
			r.position = points[o.point].position + Vector3(0, 0.1, 0)
			add_child(r)
	for t in range(1, Defs.N):
		var ai := EnemyAI.new()
		ai.T = t
		ais.append(ai)
		add_child(ai)
	if loading:
		_restore(Scenarios.load_data)
		Scenarios.load_data = {}
	zone_ring = Models.ring(Defs.BUILD_ZONE, Color(1.0, 0.85, 0.2))
	zone_ring.position = teams[Defs.PLAYER].hq.position + Vector3(0, 0.15, 0)
	zone_ring.visible = false
	add_child(zone_ring)
	hud = Hud.new()
	add_child(hud)
	controls = Controls.new()
	add_child(controls)
	if Scenarios.tutorial:
		tutorial_on = true
		add_child(load("res://scripts/tutorial.gd").new())
	var hp: Vector3 = teams[Defs.PLAYER].hq.position
	cam.focus = hp + Vector3(-signf(hp.x) * 10.0, 0, 0)
	recalc()
	fog.recompute()
	if not tutorial_on:
		hud.toast("%s — %s. İnşa düğmesiyle Kışla kur, piyadeyle ikmal noktalarını al." % [
		Scenarios.country(Defs.PLAYER).name, Scenarios.doctrine(Defs.PLAYER).name], 10.0)
	var args := OS.get_cmdline_user_args()
	if args.has("--autotest"):
		add_child(load("res://tools/autotest.gd").new())
	elif args.has("--inputtest"):
		add_child(load("res://tools/inputtest.gd").new())
	elif args.has("--gallery"):
		add_child(load("res://tools/gallery.gd").new())
	elif args.has("--animtest"):
		add_child(load("res://tools/animtest.gd").new())
	elif args.has("--mechtest"):
		add_child(load("res://tools/mechtest.gd").new())
	elif args.has("--loadtest"):
		add_child(load("res://tools/loadtest.gd").new())
	elif args.has("--tuttest"):
		add_child(load("res://tools/tuttest.gd").new())
	elif args.has("--uishot"):
		add_child(load("res://tools/uishot.gd").new())
	elif args.has("--maptest"):
		add_child(load("res://tools/maptest.gd").new())
	elif args.has("--mapshot"):
		add_child(load("res://tools/mapshot.gd").new())
	elif args.has("--duel"):
		add_child(load("res://tools/duel.gd").new())


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
	sun.shadow_enabled = Settings.get_v("shadows")
	sun.directional_shadow_max_distance = 110.0
	# Tek geçişli gölge: kuşbakışı kamerada bölmeli gölge gereksiz ve büyük haritada çok pahalı.
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	add_child(sun)

	dust_color = (Defs.MAP.ground as Color).lerp(Color(0.75, 0.7, 0.6), 0.55)


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
	_rebuild_buckets()
	time += dt
	for t in Defs.N:
		var ts: TeamState = teams[t]
		var inc := 0.0
		if ts.hq != null and is_instance_valid(ts.hq) and ts.hq.alive:
			inc += Defs.HQ_INCOME
		for p in points:
			if p.owner_team == t:
				inc += p.current_income()
		for e in entities:
			if e.is_building and e.team == t and e.built and e.kind == "maden":
				var mi: float = e.mine_income()
				inc += mi
				if mi > 0.0:
					e.deposit.reserve -= mi * dt
					if e.deposit.reserve <= 0.0:
						_msg(t, "Maden Ocağının yatağı tükendi. Yeni yataklar haritada belirecek.")
		if Defs.foe(Defs.PLAYER, t):
			inc *= float(Defs.DIFFS[Scenarios.difficulty].income)
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
	for t in Defs.N:
		teams[t].ab_cd = maxf(0.0, teams[t].ab_cd - dt)
	for sd in 2:
		_objective(Defs.leader(sd), dt)
	_recalc_t -= dt
	if _recalc_t <= 0.0:
		_recalc_t = 0.3
		recalc()
		_heal(0.3)
	_save_t -= dt
	if _save_t <= 0.0 and not tutorial_on and OS.get_cmdline_user_args().is_empty():
		_save_t = 60.0
		save_game()
	_update_rally_flag()
	_tick_t -= dt
	if _tick_t <= 0.0:
		_tick_t = 0.25
		_ew_tick(0.25)
		_mine_tick()
	_supply_t -= dt
	if _supply_t <= 0.0:
		_supply_t = 1.0
		_supply_tick()
	_dep_t -= dt
	if _dep_t <= 0.0:
		_dep_t = randf_range(Defs.DEPOSIT_EVERY.x, Defs.DEPOSIT_EVERY.y)
		spawn_deposit(true)
	_separate()


func recalc() -> void:
	var building: Array = []
	building.resize(Defs.N)
	building.fill(0)
	for t in Defs.N:
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
			elif e.d.get("field", false):
				e.crane_active = true
			else:
				# Her vinç aynı anda bir inşaat yürütür; fazlası sırada bekler.
				e.crane_active = building[e.team] < ts.cranes
				building[e.team] += 1
		else:
			ts.pop += int(e.d.get("pop", 1))


## Karargâhın ve ileri üslerin yanındaki birlikler onarılır.
func _heal(dt: float) -> void:
	var bases: Array = []
	for e in entities:
		if e.is_building and e.alive and e.built and (e.kind == "hq" or e.kind == "ileri"):
			bases.append(e)
	for e in entities:
		if e.is_building or not e.alive or e.hp >= e.max_hp:
			continue
		for b in bases:
			if b.team == e.team and Entity.flat(e.global_position, b.position) <= Defs.HEAL_RADIUS:
				e.hp = minf(e.max_hp, e.hp + e.max_hp * Defs.HEAL_RATE * dt)
				if e is Unit:
					e.update_figures()
				break


# ---------------------------------------------------------------- lojistik ve kaynak yatakları

## İkmal kaynaklarını tarafa göre toplar ve her kara birliğinin ikmal hattında olup olmadığını işaretler.
func _supply_tick() -> void:
	_supply_src = [[], []]
	for e in entities:
		if e.is_building and e.alive:
			if e.kind == "hq":
				_supply_src[Defs.SIDE[e.team]].append([e.position, Defs.SUPPLY_HQ])
			elif e.kind == "ileri" and e.built:
				_supply_src[Defs.SIDE[e.team]].append([e.position, Defs.SUPPLY_FOB])
	for p in points:
		if p.owner_team >= 0 and p.integrity() > 0.3:
			_supply_src[Defs.SIDE[p.owner_team]].append([p.position, SupplyPoint.SUPPLY_R])
	var oos := 0
	for e in entities:
		if e is Unit and e.alive:
			e.supplied = supplied(e.team, e.global_position)
			if not e.supplied and e.team == Defs.PLAYER:
				oos += 1
	if oos > 0 and time - _oos_note > 90.0:
		_oos_note = time
		hud.toast("%d birliğin ikmal hattının dışında: %%30 az hasar verir, yavaşlar ve onarılmaz. İleri Harekât Üssü kur ya da nokta al." % oos, 7.0)


func supplied(team: int, pos: Vector3) -> bool:
	for s in _supply_src[Defs.SIDE[team]]:
		if Entity.flat(pos, s[0]) <= s[1]:
			return true
	return false


func supply_sources(side: int) -> Array:
	return _supply_src[side]


## Kara biriminin bir yatağın üstünde Maden Ocağı kurabileceği, rastgele boş bir düz arazi yeri.
func spawn_deposit(announce: bool) -> Deposit:
	var live := 0
	for dp in deposits:
		if is_instance_valid(dp) and not dp.depleted():
			live += 1
	if live >= Defs.DEPOSIT_MAX:
		return null
	for tries in 200:
		var p := Vector3(randf_range(-Defs.MAP_W * 0.44, Defs.MAP_W * 0.44), 0, randf_range(-Defs.MAP_H * 0.42, Defs.MAP_H * 0.42))
		var ok := true
		for off in [Vector3.ZERO, Vector3(5, 0, 0), Vector3(-5, 0, 0), Vector3(0, 0, 5), Vector3(0, 0, -5)]:
			if terrain.kind_at(p + off) != Terrain.LAND or terrain.solid(p + off):
				ok = false
		if not ok:
			continue
		for t in Defs.N:
			if Entity.flat(p, Defs.MAP.team_bases[t]) < 75.0:
				ok = false
		for pt in points:
			if Entity.flat(p, pt.position) < 22.0:
				ok = false
		for dp in deposits:
			if Entity.flat(p, dp.position) < 55.0:
				ok = false
		for e in entities:
			if e.is_building and Entity.flat(p, e.position) < 12.0:
				ok = false
		if not ok:
			continue
		var d := Deposit.new()
		add_child(d)
		d.setup(p, snappedf(randf_range(Defs.DEPOSIT_RICH.x, Defs.DEPOSIT_RICH.y), 0.5), snappedf(randf_range(Defs.DEPOSIT_RESERVE.x, Defs.DEPOSIT_RESERVE.y), 100.0))
		terrain.block_circle(p, 1.6, true)
		deposits.append(d)
		if announce:
			pings.append([p, time + 12.0])
			sfx.play("alert")
			hud.toast("Yeni kaynak yatağı belirdi (+$%.1f/sn)! Küçük haritada yanıp sönüyor. İlk Maden Ocağını kuran alır." % d.rich, 7.0)
		return d
	return null


func deposit_at(pos: Vector3):
	for dp in deposits:
		if is_instance_valid(dp) and Entity.flat(pos, dp.position) <= Deposit.SNAP:
			return dp
	return null


## Uzamsal ızgara: hedef arama, itişme, alan hasarı ve EH yalnızca yakın hücrelere bakar.
func _rebuild_buckets() -> void:
	buckets.clear()
	for e in entities:
		if not e.alive:
			continue
		var k := Vector2i(floori(e.global_position.x / BUCKET), floori(e.global_position.z / BUCKET))
		if buckets.has(k):
			buckets[k].append(e)
		else:
			buckets[k] = [e]


## pos çevresinde r yarıçapına giren hücrelerdeki varlıklar (kesin mesafe kontrolü çağırana kalır).
func nearby(pos: Vector3, r: float) -> Array:
	var out: Array = []
	var x0 := floori((pos.x - r) / BUCKET)
	var x1 := floori((pos.x + r) / BUCKET)
	var z0 := floori((pos.z - r) / BUCKET)
	var z1 := floori((pos.z + r) / BUCKET)
	for x in range(x0, x1 + 1):
		for z in range(z0, z1 + 1):
			var k := Vector2i(x, z)
			if buckets.has(k):
				out.append_array(buckets[k])
	return out


func _separate() -> void:
	var ground: Array = []
	for e in entities:
		if e.alive and not e.is_building and not e.is_air:
			ground.append(e)
	var n := ground.size()
	var prev: Array = []
	for u in ground:
		prev.append(u.position)
	for i in n:
		var a: Entity = ground[i]
		for bn in nearby(a.position, 8.0):
			var b: Entity = bn
			if b == a or b.is_air or not b.alive or b.is_building or b.get_instance_id() < a.get_instance_id():
				continue
			var dx := a.position.x - b.position.x
			var dz := a.position.z - b.position.z
			var min_d := (a.radius + b.radius) * 0.85
			var d2 := dx * dx + dz * dz
			if d2 < min_d * min_d:
				var dd := sqrt(d2)
				if dd < 0.01:
					dx = randf_range(-0.1, 0.1)
					dz = 0.1
					dd = 0.15
				var push := (min_d - dd) * 0.5 / dd
				a.position += Vector3(dx, 0, dz) * push
				b.position -= Vector3(dx, 0, dz) * push
		for bb in nearby(a.position, 10.0):
			if not bb.is_building or not bb.alive:
				continue
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
			_hq_lost(e.team)
		for sd in 2:
			if sd == Defs.SIDE[e.team]:
				continue
			var lt := Defs.leader(sd)
			var o := Scenarios.objective(lt)
			if o.get("type", "") == "destroy" and e.kind in o.kinds and e.built:
				teams[lt].obj_prog += 1.0
				_objective(lt, 0.0)
	recalc()


func on_building_done(b: Building) -> void:
	recalc()
	_msg(b.team, "%s hazır." % b.d.name)
	if b.team == Defs.PLAYER:
		hud.rebuild()


func on_point_captured(p: SupplyPoint) -> void:
	if p.owner_team == Defs.PLAYER:
		sfx.play("capture")
		hud.toast("%s ele geçirildi (+$%d/sn)." % ["Petrol tesisi" if p.is_oil else "İkmal noktası", int(p.income)])
	elif fog.sees(Defs.PLAYER, p.position):
		hud.toast("Düşman bir nokta ele geçirdi.")


func on_missile_intercepted(src_team: int) -> void:
	hud.toast("Füzen hava savunma tarafından önlendi." if src_team == Defs.PLAYER else "Düşman füzesi önlendi!")


func alert_base() -> void:
	if time - _alert_t > 12.0:
		_alert_t = time
		sfx.play("alert")
		hud.toast("Üssün saldırı altında!")


## Bir takımın karargâhı yıkıldı: oyuncununki ise yenilgi; düşman tarafında karargâhı kalmazsa zafer.
func _hq_lost(t: int) -> void:
	if t == Defs.PLAYER:
		_end(1 - Defs.SIDE[Defs.PLAYER])
		return
	if Defs.friendly(t):
		hud.toast("Müttefik karargâhı yıkıldı!", 6.0)
		return
	for o in Defs.N:
		var h: Building = teams[o].hq
		if Defs.foe(Defs.PLAYER, o) and h != null and is_instance_valid(h) and h.alive:
			hud.toast("%s karargâhı yıkıldı! Bir düşman üssü daha var." % Defs.TEAM_NAMES[t], 6.0)
			return
	_end(Defs.SIDE[Defs.PLAYER])


## w: kazanan taraf.
func _end(w: int) -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	over = true
	winner = w
	hud.show_end(w == Defs.SIDE[Defs.PLAYER])


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

## Boş metin: buraya kurulabilir. Aksi hâlde nedeni.
## Binalar karargâhın çevresine; kışla, santral ve hava savunma ileri harekât üssünün çevresine de kurulur.
## Maden Ocağı yalnızca boş bir kaynak yatağına, İleri Harekât Üssü her yere kurulur; ikisi için de yakında
## kendi birliğin olmalı (karargâh bölgesinde gerekmez).
func place_reason(team: int, kind: String, pos: Vector3) -> String:
	var hq: Building = teams[team].hq
	if hq == null or not is_instance_valid(hq):
		return "Karargâh yok"
	var in_base := Entity.flat(pos, hq.position) <= Defs.BUILD_ZONE
	if kind == "maden":
		var dep = deposit_at(pos)
		if dep == null:
			return "Maden Ocağı yalnızca bir kaynak yatağına kurulur"
		if not dep.free_for(team) or dep.depleted():
			return "Bu yatak dolu ya da tükenmiş"
		pos = dep.position
		if not in_base and not presence(team, pos, Defs.PRESENCE_R):
			return "Yatağın yanında kendi birliğin olmalı"
	elif kind == "ileri":
		if not fog.sees(team, pos):
			return "Burası görülmüyor"
		if not in_base and not presence(team, pos, Defs.PRESENCE_R):
			return "Yakında kendi birliğin olmalı"
		for t in Defs.N:
			var fh: Building = teams[t].hq
			if Defs.foe(team, t) and fh != null and is_instance_valid(fh) and Entity.flat(pos, fh.position) < 70.0:
				return "Düşman karargâhına çok yakın"
	elif not in_base:
		var ok := false
		if kind in Defs.FOB_KINDS:
			for e in entities:
				if e.is_building and e.team == team and e.kind == "ileri" and e.built and Entity.flat(pos, e.position) <= Defs.FOB_ZONE:
					ok = true
					break
		if not ok:
			return "Sarı çemberin içinde bir yer seç" if kind not in Defs.FOB_KINDS else "Karargâhın ya da bir ileri üssün çemberi içinde bir yer seç"
	var r: float = float(Defs.BUILDINGS[Defs.bid(team, kind)].radius)
	# Binanın oturacağı alan düz kara olmalı.
	for off in [Vector3.ZERO, Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
		var q: Vector3 = pos + off
		if absf(q.x) > Defs.MAP_W * 0.5 - 1.0 or absf(q.z) > Defs.MAP_H * 0.5 - 1.0 or not terrain.is_land(q):
			return "Zemin düz ve boş değil"
	for e in entities:
		if e.is_building and Entity.flat(pos, e.position) < r + e.radius + 2.0:
			return "Başka bir binaya çok yakın"
	for p in points:
		if Entity.flat(pos, p.position) < r + SupplyPoint.RADIUS:
			return "İkmal noktasına çok yakın"
	return ""


func can_place(team: int, kind: String, pos: Vector3) -> bool:
	return place_reason(team, kind, pos) == ""


## Takımın pos çevresinde r içinde kara birliği var mı.
func presence(team: int, pos: Vector3, r: float) -> bool:
	for e in nearby(pos, r):
		if e.team == team and e.alive and not e.is_air and not e.is_building and Entity.flat(e.global_position, pos) <= r:
			return true
	return false


func place_building(team: int, kind: String, pos: Vector3) -> bool:
	var id := Defs.bid(team, kind)
	var bd: Dictionary = Defs.BUILDINGS[id]
	var ts: TeamState = teams[team]
	if ts.tier < int(bd.get("tier", 1)):
		_msg(team, "Kademe %d gerekli." % int(bd.tier))
		return false
	if ts.money < float(bd.cost):
		_msg(team, "Yetersiz para.")
		return false
	var why := place_reason(team, kind, pos)
	if why != "":
		_msg(team, why + ".")
		return false
	var dep = null
	if kind == "maden":
		dep = deposit_at(pos)
		pos = dep.position
	ts.money -= float(bd.cost)
	var b := spawn_building(id, team, pos)
	if dep != null:
		b.deposit = dep
		dep.mine = b
	if team == Defs.PLAYER and not b.crane_active:
		hud.toast("Vinç meşgul: inşaat sıraya alındı. İnşa menüsünden vinç alabilirsin.")
	return true


func begin_placing(kind: String) -> void:
	cancel_modes()
	placing = kind
	if kind == "maden":
		hud.toast("Bir kaynak yatağına dokun (sarı halkalar). Yanında kendi birliğin olmalı.", 6.0)
	elif kind == "ileri":
		hud.toast("Birliklerinin yanında görebildiğin bir yere dokun. İleri üs ikmal sağlar, yanına kışla, santral ve hava savunma kurulabilir.", 7.0)
	else:
		zone_ring.visible = true
		if kind in Defs.FOB_KINDS:
			for e in entities:
				if e.is_building and e.team == Defs.PLAYER and e.kind == "ileri" and e.built:
					var zr := Models.ring(Defs.FOB_ZONE, Color(1.0, 0.85, 0.2))
					zr.position = e.position + Vector3(0, 0.15, 0)
					add_child(zr)
					_zone_rings.append(zr)
		hud.toast("Yerleştirmek için sarı çemberin içinde bir yere dokun.", 5.0)
	hud.rebuild()


func cancel_placing() -> void:
	placing = ""
	zone_ring.visible = false
	for zr in _zone_rings:
		zr.queue_free()
	_zone_rings.clear()
	hud.rebuild()


func try_place(world: Vector3) -> void:
	if place_building(Defs.PLAYER, placing, world):
		cancel_placing()


## Bütün hedef seçme kiplerini kapatır.
func cancel_modes() -> void:
	if placing != "":
		cancel_placing()
	cancel_targeting()
	ab_targeting = false
	rally_for = null
	patrol_pick = false
	bridge_pick = false


# ---------------------------------------------------------------- toplanma noktası, devriye, gruplar

func begin_rally(b: Building) -> void:
	cancel_modes()
	rally_for = b
	hud.toast("Yeni birliklerin toplanacağı yere dokun.", 5.0)
	hud.rebuild()


func set_rally(world: Vector3) -> void:
	if rally_for != null and is_instance_valid(rally_for):
		rally_for.rally = Vector3(world.x, 0, world.z)
		fx_marker(world, Color(1.0, 0.85, 0.3))
		var b := rally_for
		rally_for = null
		select([b])


func begin_patrol() -> void:
	cancel_modes()
	patrol_pick = true
	hud.toast("Devriye noktasına dokun: birlikler bulundukları yerle o nokta arasında gidip gelir.", 5.0)
	hud.rebuild()


func set_patrol(world: Vector3) -> void:
	patrol_pick = false
	for u in selected_units():
		if u is Unit:
			u.patrol_to(world)
		elif u is AirUnit:
			u.set_patrol(world)
	fx_marker(world, Color(0.4, 0.8, 1.0))
	hud.rebuild()


## Köprü yıkma: seçili birlikler dokunulan köprüye ateş eder.
func begin_bridge_pick() -> void:
	cancel_modes()
	bridge_pick = true
	hud.toast("Yıkılacak köprüye dokun. Topçu, füze ve uçaklar da köprüleri yıkabilir.", 5.0)
	hud.rebuild()


func bridge_at(world: Vector3):
	var best = null
	var bd := 4.0
	for br in bridges:
		var dd: float = br.dist_to(world)
		if br.alive and dd < bd:
			bd = dd
			best = br
	return best


func try_bridge(world: Vector3) -> void:
	var br = bridge_at(world)
	if br == null:
		hud.toast("Orada sağlam bir köprü yok.")
		return
	bridge_pick = false
	var n := 0
	for u in selected_units():
		if u.has_weapon() and u.can_hit(br):
			n += 1
		order_attack([u], br)
	hud.toast("%d birlik köprüye ateş ediyor." % n if n > 0 else "Köprü görülmüyor ya da birlikler köprüye ateş edemiyor.")
	hud.rebuild()


func save_group(i: int) -> void:
	groups[i] = selected_units()
	hud.toast("Grup %d kaydedildi (%d birlik)." % [i + 1, groups[i].size()])


func select_group(i: int, center: bool) -> void:
	var live: Array = []
	for u in groups[i]:
		if is_instance_valid(u) and u.alive:
			live.append(u)
	groups[i] = live
	if live.is_empty():
		hud.toast("Grup %d boş. Kaydetmek için birlik seç ve düğmeye basılı tut." % (i + 1))
		return
	select(live)
	if center:
		var c := Vector3.ZERO
		for u in live:
			c += u.global_position
		cam.focus = c / live.size()


## Geri çekilme yeri: en yakın karargâh ya da ileri üs.
func rear_base(team: int, pos: Vector3):
	var best = null
	var bd := 1e9
	for e in entities:
		if e.is_building and e.team == team and e.alive and e.built and (e.kind == "hq" or e.kind == "ileri"):
			var dd := Entity.flat(pos, e.position)
			if dd < bd:
				bd = dd
				best = e
	return best


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
	if int(m.tier) >= 3:
		# Deneysel füze: pahalı ama çok etkili.
		m.exp = true
		m.cost = float(m.cost) * 1.3
		m.dmg = float(m.dmg) * 1.3
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
	s.trail = true
	if not m.get("hypersonic", false):
		for e in entities:
			if e.is_building and Defs.foe(b.team, e.team) and e.kind == "sam" and e.built and e.powered():
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
		sfx.play("alert")
	return true


func begin_targeting(b: Building, i: int) -> void:
	cancel_modes()
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
	var cands: Array = entities.duplicate()
	for p in points:
		if Defs.foe(Defs.PLAYER, p.team):
			cands.append(p)
	for e in cands:
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
	var base = rear_base(units[0].team, units[0].global_position)
	if base == null:
		return
	var pos: Vector3 = base.position + Vector3(-signf(base.position.x) * 10.0, 0, 0)
	order_move(units, pos, false)
	# Geri çekilen birlik daha hızlı gider ve %30 az hasar alır.
	for u in units:
		if u is Unit:
			u.retreating = true


## Piyade görevleri: siper kaz, mayın döşe, engel kur. Yalnızca piyade ve tanksavar timi yapabilir.
func order_task(units: Array, kind: String) -> int:
	var n := 0
	for u in units:
		if u is Unit and u.armor == "inf" and u.alive:
			if kind == "dig" and (u.entrenched or u.garrison != null):
				continue
			u.do_task(kind)
			n += 1
	return n


func order_enter(units: Array, house) -> void:
	for u in units:
		if u is Unit and u.armor == "inf" and house.has_room(u.team):
			u.enter(house)


func pick_house(world: Vector3):
	for h in houses:
		if Entity.flat(world, h.position) < h.radius + 1.2:
			return h
	return null


func team_mines(team: int) -> int:
	var n := 0
	for m in mines:
		if m.team == team:
			n += 1
	return n


func place_mine(team: int, pos: Vector3) -> bool:
	var ts: TeamState = teams[team]
	if team_mines(team) >= Defs.MAX_LANDMINES:
		_msg(team, "En çok %d mayın döşenebilir." % Defs.MAX_LANDMINES)
		return false
	if ts.money < Defs.MINE_COST:
		_msg(team, "Yetersiz para.")
		return false
	pos = terrain.nearest_free(pos)
	ts.money -= Defs.MINE_COST
	var node := Models.build({"model": "mine"}, team)
	node.position = pos
	node.visible = Defs.friendly(team)
	add_child(node)
	mines.append({team = team, pos = pos, node = node})
	_msg(team, "Mayın döşendi (%d/%d)." % [team_mines(team), Defs.MAX_LANDMINES])
	return true


func place_obstacle(team: int, pos: Vector3) -> bool:
	var id := Defs.bid(team, "engel")
	var bd: Dictionary = Defs.BUILDINGS[id]
	var ts: TeamState = teams[team]
	if ts.money < float(bd.cost):
		_msg(team, "Yetersiz para.")
		return false
	pos = terrain.nearest_free(pos)
	for e in entities:
		if e.is_building and Entity.flat(pos, e.position) < bd.radius + e.radius + 0.5:
			_msg(team, "Engel için yer yok.")
			return false
	ts.money -= float(bd.cost)
	spawn_building(id, team, pos)
	return true


## Tanksavar mayınları: düşman aracı üstünden geçerse patlar. Piyade tetiklemez.
func _mine_tick() -> void:
	for m in mines.duplicate():
		for e in nearby(m.pos, 4.0):
			if Defs.foe(m.team, e.team) and e.alive and not e.is_air and not e.is_building and e.armor != "inf":
				if Entity.flat(e.global_position, m.pos) <= e.radius + 0.8:
					fx_explosion(m.pos + Vector3(0, 0.5, 0), 2.4)
					fx_scorch(m.pos, 1.6)
					splash_damage(m.pos, 3.0, 420.0, {light = 1.0, heavy = 1.0, inf = 0.4}, m.team)
					m.node.queue_free()
					mines.erase(m)
					if e.team == Defs.PLAYER:
						hud.toast("Birliğin mayına çarptı!")
					break
		# Düşman mayını, yanına gelen birliğe görünür olur.
		if not Defs.friendly(m.team) and not m.node.visible:
			for e in entities:
				if Defs.friendly(e.team) and not e.is_air and not e.is_building and Entity.flat(e.global_position, m.pos) < 5.0:
					m.node.visible = true
					break


## Elektronik harp: EH aracının çevresindeki düşman küçük dronları hasar alıp düşer
## (fiber optik FPV hariç); büyük İHA'lar kilitlenemez.
func _ew_tick(dt: float) -> void:
	for e in entities:
		if not e.alive or e.is_building or not e.d.has("ew"):
			continue
		var r: float = e.d.ew
		for o in nearby(e.global_position, r):
			if not Defs.foe(e.team, o.team) or not o.is_air or not o.alive:
				continue
			if Entity.flat(e.global_position, o.global_position) > r:
				continue
			if o.d.get("small", false):
				if o.cls == "sdrone_fpv" and teams[o.team].researched.has("fiber"):
					continue
				o.take_damage(o.max_hp * 1.2 * dt, e)
				if o.seen and randf() < 0.5:
					fx_puff(o.global_position, Color(0.4, 0.9, 1.0), 0.6, 0.3, 0.0)
			else:
				o.jammed_t = 1.0
				o.target = null


# ---------------------------------------------------------------- görev hedefleri

func _objective(t: int, dt: float) -> void:
	var o := Scenarios.objective(t)
	if o.is_empty() or over:
		return
	var ts: TeamState = teams[t]
	var need := 1.0
	if o.type == "hold":
		need = float(o.secs)
		if Defs.ally(points[o.point].owner_team, t):
			ts.obj_prog += dt
	else:
		need = float(o.count)
	var f := ts.obj_prog / need
	var steps := [0.5, 0.8]
	if ts.obj_note < steps.size() and f >= steps[ts.obj_note]:
		ts.obj_note += 1
		hud.toast(("Görev: %%%d tamamlandı." if Defs.friendly(t) else "Uyarı: düşman görevinin %%%d'ini tamamladı!") % int(f * 100.0), 6.0)
	if f >= 1.0:
		_end(Defs.SIDE[t])


func objective_fraction(t: int) -> float:
	var o := Scenarios.objective(t)
	if o.is_empty():
		return 0.0
	var need := float(o.secs) if o.type == "hold" else float(o.count)
	return clampf(teams[t].obj_prog / need, 0.0, 1.0)


# ---------------------------------------------------------------- doktrin yeteneği

func ability(team: int) -> Dictionary:
	return Scenarios.doctrine(team).get("ability", {})


## Boş metin: kullanılabilir. Aksi hâlde nedeni.
func ability_ready(team: int) -> String:
	var a := ability(team)
	var ts: TeamState = teams[team]
	if a.is_empty():
		return "Yok"
	if ts.tier < int(a.tier):
		return "Kademe %d" % int(a.tier)
	if ts.ab_cd > 0.0:
		return "%d sn" % int(ceil(ts.ab_cd))
	if ts.money < float(a.cost):
		return "Yetersiz para"
	return ""


func begin_ability() -> void:
	var a := ability(Defs.PLAYER)
	var why := ability_ready(Defs.PLAYER)
	if why != "":
		hud.toast("%s: %s." % [a.get("name", "Yetenek"), why])
		return
	if not a.target:
		use_ability(Defs.PLAYER, Vector3.INF)
		return
	cancel_modes()
	ab_targeting = true
	hud.toast("%s: hedef için görebildiğin bir yere dokun." % a.name, 5.0)
	hud.rebuild()


func cancel_ability() -> void:
	if ab_targeting:
		ab_targeting = false
		hud.rebuild()


func try_ability(world: Vector3) -> void:
	if use_ability(Defs.PLAYER, world):
		cancel_ability()


func use_ability(team: int, pos: Vector3) -> bool:
	var a := ability(team)
	var why := ability_ready(team)
	if why != "":
		return false
	if a.target and not fog.sees(team, pos):
		_msg(team, "Hedef görülmüyor. Önce keşif yap.")
		return false
	var ts: TeamState = teams[team]
	match a.id:
		"suru":
			var id := unit_of(team, "sdrone_fpv")
			if id == "":
				id = unit_of(team, "loiter")
			var from := _nearest_own(team, pos)
			for i in 8:
				var u = spawn_unit(id, team, from + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3)))
				u.set_patrol(pos + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)))
		"ikmal":
			ts.tanker_until = time + 60.0
		"baraj":
			for i in 14:
				get_tree().create_timer(0.5 * i, false).timeout.connect(
					_sky_shell.bind(team, pos + Vector3(randf_range(-9, 9), 0, randf_range(-9, 9))))
		"salvo":
			var src = nearest_building(team, "fuze", pos)
			var start: Vector3 = (src.muzzle_pos() if src != null else ts.hq.position + Vector3(0, 6, 0))
			var m := missile_info(team, 0)
			var sams: Array = []
			for e in entities:
				if e.is_building and Defs.foe(team, e.team) and e.kind == "sam" and e.built and e.powered() and Entity.flat(e.position, pos) <= e.wrange():
					sams.append(e)
			for i in 4:
				# Her batarya en çok bir füzeyi önleyebilir: doyurma saldırısı.
				var stop := i < sams.size() and randf() < Defs.INTERCEPT_CHANCE + 0.3
				_missile_shot(team, start, pos + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), float(m.dmg) * 0.8, float(m.splash), stop, src)
		"seferberlik":
			var id := unit_of(team, "inf")
			var hq: Building = ts.hq
			var n := 0
			for i in 4:
				if ts.pop + 1 > ts.pop_cap:
					break
				spawn_unit(id, team, terrain.nearest_free(hq.position + Vector3(-signf(hq.position.x) * 9.0, 0, -6.0 + i * 4.0)))
				ts.pop += 1
				n += 1
			if n == 0:
				_msg(team, "Birlik sınırı dolu.")
				return false
	ts.money -= float(a.cost)
	ts.ab_cd = float(a.cd)
	if team == Defs.PLAYER:
		hud.toast("%s başladı." % a.name)
	elif fog.sees(Defs.PLAYER, pos) or not a.target:
		hud.toast("Düşman %s kullandı!" % a.name)
	return true


func _nearest_own(team: int, pos: Vector3) -> Vector3:
	var best: Vector3 = teams[team].hq.position
	var bd := Entity.flat(best, pos)
	for e in entities:
		if e.team == team and e.alive and not e.is_air:
			var dd := Entity.flat(e.global_position, pos)
			if dd < bd:
				bd = dd
				best = e.global_position
	return best


func _sky_shell(team: int, pos: Vector3) -> void:
	if over:
		return
	var s := Shot.new()
	s.mesh = _puff_mesh()
	s.material_override = Models.glow(Color(1.0, 0.75, 0.3))
	s.scale = Vector3.ONE * 0.5
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.src_team = team
	var hq: Building = teams[team].hq
	var hx: float = hq.position.x if hq != null and is_instance_valid(hq) else 0.0
	s.start = pos + Vector3(-signf(pos.x - hx) * 20.0, 40.0, 0)
	s.end = Vector3(pos.x, 0.3, pos.z)
	s.speed = 55.0
	s.base = 100.0
	s.mult = {inf = 1.0, light = 1.0, heavy = 0.6, bld = 1.3}
	s.splash = 4.5
	s.boom = 2.0
	add_child(s)
	s.launch()


func _missile_shot(team: int, start: Vector3, pos: Vector3, dmg: float, splash: float, intercepted: bool, src = null) -> void:
	var s := Shot.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.35
	cm.height = 2.4
	cm.radial_segments = 6
	s.mesh = cm
	s.material_override = Models.glow(Color(1.0, 0.9, 0.7))
	s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	s.src = src
	s.src_team = team
	s.start = start
	s.end = Vector3(pos.x, 0.3, pos.z)
	s.speed = 38.0
	s.arc = 38.0
	s.base = dmg
	s.mult = MISSILE_MULT
	s.splash = splash
	s.boom = 6.0
	s.trail = true
	if intercepted:
		s.intercept_at = randf_range(0.6, 0.85)
	add_child(s)
	s.launch()


# ---------------------------------------------------------------- hasar ve efektler

func splash_damage(pos: Vector3, r: float, base: float, mult: Dictionary, src_team: int, tag := "", attacker = null) -> void:
	for e in nearby(pos, r + 7.0):
		if e.alive and Defs.foe(src_team, e.team) and not e.is_air:
			if Entity.flat(e.global_position, pos) - e.radius <= r:
				e.take_damage(base * float(mult.get(e.armor, 0.0)), attacker, tag)
	# Köprüler ve ikmal noktaları da alan hasarından payını alır.
	for br in bridges:
		if br.alive and br.dist_to(pos) <= r:
			br.take_damage(base * float(mult.get("bld", 0.0)), attacker, tag)
	for p in points:
		if p.alive and Defs.foe(src_team, p.team) and Entity.flat(p.global_position, pos) - p.radius <= r:
			p.take_damage(base * float(mult.get("bld", 0.0)), attacker, tag)


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
	s.trail = homing
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
	sfx.play("boom_l" if size >= 3.0 else "boom_s", pos)
	var tw := create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * size * 2.0, 0.22)
	tw.tween_callback(m.queue_free)
	if size >= 1.5:
		fx_puff(pos, Color(0.28, 0.27, 0.26), size * 1.5, 1.1, 1.6)


## Duman / toz bulutu: büyür, yükselir, sonra küçülüp kaybolur. Efektler kapalıysa çizilmez.
func fx_puff(pos: Vector3, col: Color, size: float, secs: float, rise := 0.6) -> void:
	if not Settings.get_v("effects"):
		return
	var m := MeshInstance3D.new()
	m.mesh = _puff_mesh()
	m.material_override = Models.glow(col)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * size * 0.3
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(m, "scale", Vector3.ONE * size, secs * 0.6)
	tw.tween_property(m, "global_position", pos + Vector3(0, rise, 0), secs)
	tw.chain().tween_property(m, "scale", Vector3.ONE * 0.02, secs * 0.4)
	tw.chain().tween_callback(m.queue_free)


func _puff_mesh() -> SphereMesh:
	if _puff == null:
		_puff = SphereMesh.new()
		_puff.radius = 0.5
		_puff.height = 1.0
		_puff.radial_segments = 6
		_puff.rings = 3
	return _puff


## Namlu alevi ve ardından duman.
func fx_muzzle(pos: Vector3, proj: String) -> void:
	var size := 0.35
	match proj:
		"shell":
			size = 1.1
		"arc":
			size = 1.4
		"missile":
			size = 0.7
		"beam":
			return
	var m := MeshInstance3D.new()
	m.mesh = _puff_mesh()
	m.material_override = Models.glow(Color(1.0, 0.85, 0.35))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * size
	var tw := create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * size * 0.2, 0.08)
	tw.tween_callback(m.queue_free)
	if proj != "tracer":
		fx_puff(pos, Color(0.7, 0.7, 0.68), size * 1.3, 0.7, 0.8)


## Yerde kalan yanık izi ve yükselen duman.
func fx_scorch(pos: Vector3, r: float) -> void:
	var m := Models.cyl(self, r, r, 0.02, Vector3(pos.x, 0.06, pos.z), Color(0.1, 0.09, 0.08), Vector3.ZERO, 10)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx_puff(Vector3(pos.x, 0.6, pos.z), Color(0.2, 0.2, 0.2), r * 1.6, 1.6, 3.0)
	var tw := create_tween()
	tw.tween_interval(30.0)
	tw.tween_property(m, "scale", Vector3(0.05, 1.0, 0.05), 3.0)
	tw.tween_callback(m.queue_free)


## Vurulan hava aracı duman bırakarak yere düşer ve patlar.
func fx_crash(pos: Vector3, r: float) -> void:
	fx_explosion(pos, r * 1.2)
	var m := MeshInstance3D.new()
	m.mesh = _puff_mesh()
	m.material_override = Models.glow(Color(0.15, 0.15, 0.15))
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)
	m.global_position = pos
	m.scale = Vector3.ONE * r
	var ground := Vector3(pos.x + randf_range(-3.0, 3.0), 0.3, pos.z + randf_range(-3.0, 3.0))
	var secs := 0.35 + pos.y * 0.08
	var tw := create_tween()
	tw.tween_property(m, "global_position", ground, secs).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	tw.tween_callback(m.queue_free)
	tw.tween_callback(fx_explosion.bind(ground, r * 1.4))
	tw.tween_callback(fx_scorch.bind(ground, r))
	for i in 4:
		var f := (i + 1) / 5.0
		get_tree().create_timer(secs * f, false).timeout.connect(
			fx_puff.bind(pos.lerp(ground, f * f), Color(0.3, 0.3, 0.3), r * 0.9, 0.9, 0.3))


func fx_marker(pos: Vector3, c: Color) -> void:
	var m := Models.ring(1.6, c)
	add_child(m)
	m.global_position = Vector3(pos.x, 0.15, pos.z)
	var tw := create_tween()
	tw.tween_property(m, "scale", Vector3(0.1, 0.2, 0.1), 0.45)
	tw.tween_callback(m.queue_free)


func _update_rally_flag() -> void:
	var b = selection[0] if selection.size() == 1 else null
	var show: bool = b != null and b is Building and b.rally != Vector3.INF
	if show and rally_flag == null:
		rally_flag = Node3D.new()
		Models.cyl(rally_flag, 0.06, 0.06, 3.0, Vector3(0, 1.5, 0), Models.DARK)
		Models.box(rally_flag, Vector3(1.0, 0.6, 0.05), Vector3(0.5, 2.7, 0), Color(1.0, 0.85, 0.3))
		add_child(rally_flag)
	if rally_flag != null:
		rally_flag.visible = show
		if show:
			rally_flag.position = b.rally


# ---------------------------------------------------------------- kayıt ve devam

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		if not over and not tutorial_on and is_inside_tree() and not teams.is_empty():
			save_game()


static func _v(p: Vector3) -> Array:
	return [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)]


static func _p(a: Array) -> Vector3:
	return Vector3(a[0], a[1], a[2])


## Maçın durumunu kaydeder: takımlar, birlikler, binalar, noktalar, mayınlar, görevler.
## Mermiler, hedefler ve sis kaydedilmez; yüklemede yeniden kurulur.
func save_game() -> void:
	var data := {
		v = SAVE_V, scn = Scenarios.chosen, side = Scenarios.side, diff = Scenarios.difficulty, mode = Scenarios.mode,
		time = time, waves = [], teams = [], ents = [], points = [], mines = [], bridges = [],
	}
	for ai in ais:
		data.waves.append(ai.wave)
	for br in bridges:
		data.bridges.append([snappedf(br.hp, 1.0), br.down])
	data.deposits = []
	for dp in deposits:
		if is_instance_valid(dp):
			data.deposits.append([snappedf(dp.position.x, 0.01), snappedf(dp.position.z, 0.01), dp.rich, snappedf(dp.reserve, 1.0)])
	data.dep_t = _dep_t
	for ts in teams:
		data.teams.append({
			money = ts.money, tier = ts.tier, upgrading = ts.upgrading, upgrade_t = ts.upgrade_t,
			cranes = ts.cranes, researched = ts.researched, ab_cd = ts.ab_cd, tanker = maxf(0.0, ts.tanker_until - time),
			obj = ts.obj_prog, obj_note = ts.obj_note,
		})
	for e in entities:
		if not e.alive:
			continue
		var r := {id = e.def_id, team = e.team, p = _v(e.global_position), ry = snappedf(e.rotation.y, 0.01),
			hp = snappedf(e.hp, 0.1), rank = e.rank, xp = snappedf(e.xp, 0.1)}
		if e is Building:
			r.b = true
			r.built = e.built
			r.build_t = e.build_t
			r.queue = e.queue
			r.prod_t = e.prod_t
			r.research = e.research_id
			r.research_t = e.research_t
			r.missiles = e.missile_ready
			if e.rally != Vector3.INF:
				r.rally = _v(e.rally)
		elif e is AirUnit:
			r.patrol = _v(e.patrol)
			r.ammo = e.ammo
			r.life = e.life
		else:
			r.entrenched = e.entrenched
			r.house = houses.find(e.garrison) if e.garrison != null else -1
		data.ents.append(r)
	for pt in points:
		data.points.append([pt.owner_team, snappedf(pt.hp, 1.0)])
	for m in mines:
		data.mines.append({team = m.team, p = _v(m.pos)})
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data))


static func saved_info() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary and int(d.get("v", 0)) == SAVE_V else {}


## Kaydı sahneye geri kurar (_ready içinde, harita kurulduktan sonra çağrılır).
func _restore(data: Dictionary) -> void:
	time = float(data.time)
	for t in Defs.N:
		var src: Dictionary = data.teams[t]
		var ts: TeamState = teams[t]
		ts.money = float(src.money)
		ts.tier = int(src.tier)
		ts.upgrading = bool(src.upgrading)
		ts.upgrade_t = float(src.upgrade_t)
		ts.cranes = int(src.cranes)
		ts.ab_cd = float(src.ab_cd)
		ts.tanker_until = time + float(src.tanker)
		ts.obj_prog = float(src.obj)
		ts.obj_note = int(src.obj_note)
		for rid in src.researched:
			for r in Scenarios.RESEARCH:
				if r.id == rid:
					ts.researched.append(rid)
					apply_mods(t, r.mods)
	for r in data.ents:
		var e: Entity
		var pos := _p(r.p)
		if r.get("b", false):
			e = spawn_building(r.id, int(r.team), pos, bool(r.built))
			e.build_t = float(r.build_t)
			for q in r.queue:
				e.queue.append(q)
			e.prod_t = float(r.prod_t)
			e.research_id = r.research
			e.research_t = float(r.research_t)
			for i in mini(e.missile_ready.size(), r.missiles.size()):
				e.missile_ready[i] = float(r.missiles[i])
			if r.has("rally"):
				e.rally = _p(r.rally)
			if e.kind == "hq":
				teams[int(r.team)].hq = e
		else:
			e = spawn_unit(r.id, int(r.team), pos)
			e.position.y = pos.y
			e.rotation.y = float(r.ry)
			if e is AirUnit:
				e.set_patrol(_p(r.patrol))
				e.ammo = int(r.ammo)
				e.life = float(r.life)
			else:
				if int(r.house) >= 0 and int(r.house) < houses.size():
					houses[int(r.house)].add(e)
					e.garrison = houses[int(r.house)]
					e.model.visible = false
				elif r.entrenched:
					e.entrenched = true
					e.trench = Models.build({"model": "trench"}, e.team)
					e.add_child(e.trench)
		e.rank = int(r.rank)
		e.xp = float(r.xp)
		e.hp = minf(float(r.hp), e.max_hp)
		if e is Unit:
			e.update_figures()
	for i in mini(points.size(), data.points.size()):
		points[i].claim(int(data.points[i][0]))
		points[i].hp = float(data.points[i][1])
	for i in mini(bridges.size(), data.bridges.size()):
		if data.bridges[i][1]:
			bridges[i].collapse()
		else:
			bridges[i].hp = float(data.bridges[i][0])
	for m in data.mines:
		var node := Models.build({"model": "mine"}, int(m.team))
		node.position = _p(m.p)
		node.visible = Defs.friendly(int(m.team))
		add_child(node)
		mines.append({team = int(m.team), pos = _p(m.p), node = node})
	for dd in data.get("deposits", []):
		var dp := Deposit.new()
		add_child(dp)
		dp.setup(Vector3(dd[0], 0, dd[1]), float(dd[2]), float(dd[3]))
		terrain.block_circle(dp.position, 1.6, true)
		deposits.append(dp)
	_dep_t = float(data.get("dep_t", 90.0))
	for e in entities:
		if e is Building and e.kind == "maden":
			var dp = deposit_at(e.position)
			if dp != null:
				e.deposit = dp
				dp.mine = e
	for i in mini(ais.size(), data.waves.size()):
		ais[i].wave = int(data.waves[i])
	recalc()


# ---------------------------------------------------------------- enkaz

var _burnt: StandardMaterial3D = null


func tint_tree(n: Node, m: Material) -> void:
	if n is GeometryInstance3D:
		n.material_override = m
	for c in n.get_children():
		tint_tree(c, m)


## Yok edilen araç yanmış enkaz olarak, bina moloz olarak bir süre yerinde kalır.
func leave_wreck(e: Entity) -> void:
	if _burnt == null:
		_burnt = StandardMaterial3D.new()
		_burnt.albedo_color = Color(0.11, 0.1, 0.09)
		_burnt.roughness = 1.0
	var m: Node3D = e.model
	var xf := m.global_transform
	e.remove_child(m)
	add_child(m)
	m.global_transform = xf
	tint_tree(m, _burnt)
	m.visible = e.seen
	var tw := create_tween()
	if e.is_building:
		m.scale.y *= 0.3
		tw.tween_interval(60.0)
	else:
		var turret: Node3D = m.get_node_or_null("turret")
		if turret != null:
			turret.rotation.y += randf_range(-0.8, 0.8)
			turret.rotation.z = randf_range(-0.2, 0.2)
		m.rotation.z += randf_range(-0.12, 0.12)
		tw.tween_interval(40.0)
		for i in 3:
			get_tree().create_timer(2.0 + i * 3.0, false).timeout.connect(
				func(): if is_instance_valid(m) and m.visible: fx_puff(m.global_position + Vector3(0, 1.0, 0), Color(0.15, 0.15, 0.15), 1.4, 2.5, 3.5))
	tw.tween_property(m, "position:y", m.position.y - 1.5, 4.0)
	tw.tween_callback(m.queue_free)
