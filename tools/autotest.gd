extends Node
## Geliştirme aracı: oyunu senaryoyla oynatır, ekran görüntüsü alır ve çıkar.
## Kullanım: godot --path . --fixed-fps 30 -- --autotest [--shots=KLASÖR] [--end=SANİYE]

var out_dir := ""
var end_time := 420.0
var step := 0
var log_t := 0.0
var busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
		elif a.begins_with("--end="):
			end_time = float(a.trim_prefix("--end="))
	Game.I.teams[Defs.PLAYER].supply = 9000.0


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	busy = true
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	busy = false


func _pad(i: int):
	var n := 0
	for p in Game.I.pads:
		if p.team == Defs.PLAYER:
			if n == i:
				return p
			n += 1
	return null


func _b(id: String):
	return Game.I.nearest_building(Defs.PLAYER, id, Vector3.ZERO)


func _units(id := "") -> Array:
	var out: Array = []
	for e in Game.I.entities:
		if e.team == Defs.PLAYER and not e.is_building and (id == "" or e.def_id == id):
			out.append(e)
	return out


func _process(dt: float) -> void:
	var g := Game.I
	if busy:
		return
	log_t -= dt
	if log_t <= 0.0:
		log_t = 30.0
		var c := [0, 0]
		for e in g.entities:
			c[e.team] += 1
		var own := [0, 0]
		for p in g.points:
			if p.owner_team >= 0:
				own[p.owner_team] += 1
		print("t=%d  varlik=%s  nokta=%s  ikmal=[%d,%d]  kademe=[%d,%d] dalga-bitti=%s" % [
			int(g.time), c, own, int(g.teams[0].supply), int(g.teams[1].supply),
			g.teams[0].tier, g.teams[1].tier, g.over])
	var t := g.time
	match step:
		0:
			if t > 1.0:
				_shot("01_baslangic")
				step += 1
		1:
			g.build_on_pad(_pad(0), "kisla")
			g.build_on_pad(_pad(1), "santral")
			g.build_on_pad(_pad(5), "fabrika")
			g.build_on_pad(_pad(2), "santral")
			var m := _units("manga")
			g.order_move([m[0]], Vector3(-30, 0, -26), true)
			g.order_move([m[1]], Vector3(-30, 0, 26), true)
			g.select_pad(_pad(3))
			step += 1
		2:
			if t > 3.0:
				_shot("02_yuva_menusu")
				step += 1
		3:
			if t > 18.0:
				var k = _b("kisla")
				var f = _b("fabrika")
				for id in ["manga", "manga", "tanksavar", "tanksavar"]:
					g.queue_unit(k, id)
				for id in ["tank", "tank", "tank", "korkut"]:
					g.queue_unit(f, id)
				g.start_tier_upgrade(Defs.PLAYER)
				g.select([f])
				step += 1
		4:
			if t > 24.0:
				_shot("03_fabrika")
				step += 1
		5:
			if t > 48.0:
				g.build_on_pad(_pad(3), "iha")
				g.place_free(Defs.PLAYER, "hisar", g.teams[0].hq.position + Vector3(20, 0, 8))
				g.queue_unit(_b("fabrika"), "obus")
				g.queue_unit(_b("fabrika"), "obus")
				g.select([g.teams[0].hq])
				g.begin_placing("hisar")
				step += 1
		6:
			if t > 50.0:
				_shot("04_hisar_yerlestirme")
				g.cancel_placing()
				step += 1
		7:
			if t > 68.0:
				var s = _b("iha")
				if s != null:
					for id in ["kesif", "tb2", "tb2"]:
						g.queue_unit(s, id)
					step += 1
		8:
			if t > 112.0:
				g.select_category("")
				g.cam.focus = Vector3(-36, 0, 0)
				g.cam.dist = 40.0
				step += 1
		9:
			if t > 113.0:
				_shot("05_ordu")
				var ground: Array = []
				for u in _units():
					if u is AirUnit:
						u.set_patrol(Vector3(26, 0, 0) if u.def_id == "kesif" else Vector3(8, 0, 0))
					elif u.def_id != "manga":
						ground.append(u)
				g.order_move(ground, Vector3(0, 0, 0), true)
				g.order_move(_units("manga").slice(2), Vector3(0, 0, 0), true)
				step += 1
		10:
			if t > 140.0:
				g.cam.focus = Vector3(4, 0, 2)
				g.cam.dist = 44.0
				step += 1
		11:
			if t > 141.0:
				_shot("06_orta_saha")
				g.cam.focus = Vector3(20, 0, 0)
				g.cam.dist = 34.0
				g.select(_units("kesif"))
				step += 1
		12:
			if t > 143.0:
				_shot("07_iha_yakin")
				step += 1
		13:
			if t > 190.0:
				var ground: Array = []
				for u in _units():
					if u is AirUnit:
						u.set_patrol(Vector3(40, 0, 0))
					elif u.def_id != "manga":
						ground.append(u)
				g.order_move(ground, g.teams[1].hq.position, true)
				g.select(ground)
				g.cam.focus = Vector3(30, 0, 0)
				g.cam.dist = 50.0
				step += 1
		14:
			if t > 215.0:
				_shot("08_saldiri")
				step += 1
		15:
			if t > 245.0:
				g.cam.focus = Vector3(44, 0, 0)
				_shot("09_dusman_ussu")
				step += 1
		16:
			if t > end_time or g.over:
				_shot("10_son")
				step += 1
		17:
			print("AUTOTEST BITTI  t=%d  kazanan=%d" % [int(g.time), g.winner])
			get_tree().quit()
