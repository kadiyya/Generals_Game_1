extends Node
## Geliştirme aracı: oyuncu yerine oynayan basit bir bot. Her binayı kurar, her birimi üretir,
## araştırma yapar, füze atar ve saldırır; böylece bütün kod yolları çalışır.
## Kullanım: godot --headless --path . --fixed-fps 30 -- --autotest [--scn=N] [--side=N] [--end=SANİYE] [--idle]
## Ekran görüntüsü için --headless olmadan --shots=KLASÖR ekle.

const WANT_B := [["kisla", 1], ["santral", 2], ["fabrika", 1], ["maden", 2], ["havaalani", 1],
	["teknoloji", 1], ["sam", 1], ["santral", 4], ["fuze", 1], ["havaalani", 2]]
const SHOTS := [[2.0, "01_baslangic"], [70.0, "02_us"], [200.0, "03_hava_alani"], [330.0, "04_ordu"],
	[400.0, "05_ileri"], [470.0, "06_saldiri"], [520.0, "07_harita"]]

var out_dir := ""
var end_time := 560.0
var idle := false   # --idle: oyuncu hiçbir şey yapmaz; yapay zekânın temposunu ölçer
var busy := false
var log_t := 0.0
var act_t := 0.0
var shot_i := 0
var attacked := false
var made := {}
var launched := 0
var used := {}       # denenen yeni mekanikler


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
		elif a == "--idle":
			idle = true
		elif a.begins_with("--end="):
			end_time = float(a.trim_prefix("--end="))
	if not idle:
		Game.I.teams[Defs.PLAYER].money = 60000.0
	print("SENARYO %s  taraf=%s  rakip=%s" % [Defs.SCN.name, Scenarios.country(0).name, Scenarios.country(1).name])


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	busy = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	busy = false


func _units(cat := "") -> Array:
	var out: Array = []
	for e in Game.I.entities:
		if e.team == Defs.PLAYER and not e.is_building and (cat == "" or e.d.cat == cat):
			out.append(e)
	return out


func _site(kind: String) -> Vector3:
	var g := Game.I
	var home: Vector3 = g.teams[0].hq.position
	for r in [16.0, 26.0, 35.0, 41.0]:
		for k in 12:
			var ang: float = k * TAU / 12.0 + r * 0.05
			var p: Vector3 = home + Vector3(cos(ang), 0, sin(ang)) * r
			if g.can_place(0, kind, p):
				return p
	return Vector3.INF


func _act() -> void:
	var g := Game.I
	var ts = g.teams[0]
	while ts.cranes < Defs.MAX_CRANES:
		g.buy_crane(0)
	for w in WANT_B:
		var bd: Dictionary = Defs.BUILDINGS[Defs.bid(0, w[0])]
		if g.count_kind(0, w[0], false) < w[1] and ts.tier >= int(bd.get("tier", 1)):
			var p := _site(w[0])
			if p != Vector3.INF:
				g.place_building(0, w[0], p)
	if g.can_upgrade(0) == "":
		g.start_tier_upgrade(0)
	for e in g.entities:
		if e.team != 0 or not e.is_building or not e.built:
			continue
		# her birimden birer tane (uçaklardan ikişer) üret
		for id in e.d.get("produces", []):
			var ud: Dictionary = Defs.UNITS[id]
			var want := 2 if ud.cat == "kara" else 1
			if int(made.get(id, 0)) < want and ts.tier >= int(ud.get("tier", 1)) and e.queue.size() < 3:
				if g.queue_unit(e, id):
					made[id] = int(made.get(id, 0)) + 1
		if e.kind == "teknoloji" and e.research_id == "":
			for r in Scenarios.RESEARCH:
				if g.can_research(0, r.id):
					g.start_research(e, r)
					break
		if e.kind == "fuze" and g.time > 300.0:
			for i in e.missile_ready.size():
				if e.missile_ready[i] <= 0.0 and ts.tier >= int(g.missile_info(0, i).tier):
					for t in g.entities:
						if t.team == 1 and t.is_building and g.fog.sees(0, t.position):
							if g.launch_missile(e, i, t.position):
								launched += 1
							break
	# yeni mekanikler: siper, mayın, engel, eve girme, doktrin yeteneği
	var inf: Array = []
	for u in _units("kara"):
		if u.armor == "inf" and u.order == "idle":
			inf.append(u)
	if g.time > 40.0 and not used.has("dig") and inf.size() >= 1:
		used["dig"] = g.order_task([inf[0]], "dig")
	if g.time > 60.0 and not used.has("mine") and inf.size() >= 2:
		used["mine"] = g.order_task([inf[1]], "mine")
	if g.time > 80.0 and not used.has("engel") and inf.size() >= 2:
		used["engel"] = g.order_task([inf[1]], "obstacle")
	if g.time > 100.0 and not used.has("ev") and inf.size() >= 1:
		var best = null
		for h in g.houses:
			if h.has_room(0) and (best == null or Entity.flat(h.position, inf[0].position) < Entity.flat(best.position, inf[0].position)):
				best = h
		if best != null:
			g.order_enter([inf[0]], best)
			used["ev"] = 1
	if g.time > 250.0 and g.ability_ready(0) == "":
		var a := g.ability(0)
		var pos := Vector3.INF
		if a.target:
			for t in g.entities:
				if t.team == 1 and g.fog.sees(0, t.global_position):
					pos = t.global_position
					break
		if not a.target or pos != Vector3.INF:
			if g.use_ability(0, pos):
				used["yetenek"] = int(used.get("yetenek", 0)) + 1
	if g.time > 320.0 and not attacked:
		attacked = true
		g.select_category("")
	if g.time > 335.0:
		var hq1 = g.teams[1].hq
		if hq1 != null and is_instance_valid(hq1):
			var ground: Array = []
			for u in _units("kara") + _units("hs"):
				if u.order == "idle":
					ground.append(u)
			if not ground.is_empty():
				g.order_move(ground, hq1.position, true)
			for u in _units("hava"):
				u.set_patrol(hq1.position + Vector3(signf(g.teams[0].hq.position.x) * 26.0, 0, 0))


func _process(dt: float) -> void:
	var g := Game.I
	if busy:
		return
	log_t -= dt
	if log_t <= 0.0:
		log_t = 60.0
		var c := [0, 0]
		for e in g.entities:
			c[e.team] += 1
		var own := [0, 0]
		for p in g.points:
			if p.owner_team >= 0:
				own[p.owner_team] += 1
		print("t=%d  varlik=%s  nokta=%s  para=[%d,%d]  kademe=[%d,%d]  fuze=%d" % [
			int(g.time), c, own, int(g.teams[0].money), int(g.teams[1].money),
			g.teams[0].tier, g.teams[1].tier, launched])
	if g.time > end_time or g.over:
		_shot("08_son")
		var kinds := {}
		for id in made:
			kinds[Defs.UNITS[id].cls] = true
		var ranks := [0, 0]
		var garr := [0, 0]
		var dug := [0, 0]
		for e in g.entities:
			ranks[e.team] = maxi(ranks[e.team], e.rank)
			if e is Unit:
				if e.garrison != null:
					garr[e.team] += 1
				if e.entrenched:
					dug[e.team] += 1
		print("AUTOTEST BITTI  t=%d  kazanan=%d  uretilen_tur=%d  sinif=%d  arastirma=%d  fuze=%d" % [
			int(g.time), g.winner, made.size(), kinds.size(), g.teams[0].researched.size(), launched])
		for c in g.get_children():
			if c is EnemyAI:
				print("YZ  zorluk=%s  dalga=%d  %s" % [Defs.DIFFS[Scenarios.difficulty].name, c.wave, c.stats])
		print("MEKANIK  denenen=%s  rutbe=%s  evde=%s  siperde=%s  mayin=[%d,%d]  gorev=[%d%%,%d%%]" % [
			used, ranks, garr, dug, g.team_mines(0), g.team_mines(1),
			int(g.objective_fraction(0) * 100.0), int(g.objective_fraction(1) * 100.0)])
		set_process(false)
		await get_tree().create_timer(0.2, true, false, true).timeout
		get_tree().quit()
		return
	if idle:
		return
	if shot_i < SHOTS.size() and g.time > SHOTS[shot_i][0]:
		var hq: Vector3 = g.teams[0].hq.position
		var dirx := -signf(hq.x)
		match shot_i:
			0, 1:
				g.cam.focus = hq + Vector3(dirx * 12.0, 0, 0)
				g.cam.dist = 62.0
				if shot_i == 1:
					g.open_build_menu()
			2:
				var af = g.nearest_building(0, "havaalani", hq)
				if af != null:
					g.cam.focus = af.position
					g.cam.dist = 44.0
					g.select([af])
			3:
				g.cam.focus = hq + Vector3(dirx * 22.0, 0, 0)
				g.cam.dist = 52.0
			4:
				g.cam.focus = Vector3(hq.x * 0.35, 0, hq.z)
				g.cam.dist = 62.0
			5:
				g.cam.focus = Vector3(-hq.x * 0.75, 0, g.teams[1].hq.position.z)
				g.cam.dist = 66.0
			6:
				g.cam.focus = Vector3.ZERO
				g.cam.dist = 130.0
		_shot(SHOTS[shot_i][1])
		shot_i += 1
		return
	act_t -= dt
	if act_t <= 0.0:
		act_t = 2.0
		_act()
