extends Node
## Geliştirme aracı: oynanış mekaniklerini tek tek doğrular (arazi, EH, siper, ev, mayın, engel, rütbe,
## geri çekilme, görev, doktrin yeteneği, birim kartı). Harkiv haritası (1. senaryo, Ukrayna) gerekir.
## Kullanım: godot --headless --path . --fixed-fps 30 -- --mechtest --scn=0 --side=0

var fails := 0
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
	_run.call_deferred()


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _check(name: String, ok: bool) -> void:
	print(("GECTI  " if ok else "KALDI  ") + name)
	if not ok:
		fails += 1


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout


func _run() -> void:
	var g := Game.I
	for c in g.get_children():
		if c is EnemyAI:
			c.set_process(false)
	g.teams[0].money = 50000.0
	g.teams[1].money = 50000.0
	var ter := g.terrain
	g.cam.focus = Vector3(-24, 0, 0)
	g.cam.dist = 95.0
	await _shot("arazi")

	# ---- arazi
	_check("yikinti dogrudan atisi keser", not ter.los_clear(Vector3(-20, 0, -3), Vector3(4, 0, -3)))
	_check("acik arazide gorus hatti acik", ter.los_clear(Vector3(-80, 0, 40), Vector3(-60, 0, 40)))
	_check("yol hizlandirir", ter.speed_mult(Vector3(20, 0, 0), "heavy") > 1.2)
	_check("orman araci yavaslatir", ter.speed_mult(Vector3(-29, 0, 32), "heavy") < 0.7)
	var flat_tank = g.spawn_unit(g.unit_of(0, "tank"), 0, Vector3(-80, 0, -40))
	var hill_tank = g.spawn_unit(g.unit_of(0, "tank"), 0, Vector3(-28, 0, -29))
	_check("tepede menzil artar", hill_tank.wrange() > flat_tank.wrange() * 1.1)
	_check("tepe yuksektir", ter.height(Vector3(-28, 0, -29)) > 0.5)

	# ---- orman gizlenmesi
	var hider = g.spawn_unit(g.unit_of(1, "inf"), 1, Vector3(-29, 0, 32))
	var watcher = g.spawn_unit(g.unit_of(0, "inf"), 0, Vector3(-29, 0, 14))
	g.fog.recompute()
	_check("ormandaki dusman piyadesi uzaktan gorulmez", not hider.seen and hider.concealed())
	watcher.position = Vector3(-29, 0, 25)
	g.fog.recompute()
	_check("ormandaki piyade yakindan gorulur", hider.seen)

	# ---- elektronik harp
	var ew = g.spawn_unit(g.unit_of(0, "ew"), 0, Vector3(70, 0, -40))
	var fpv = g.spawn_unit(g.unit_of(1, "sdrone_fpv"), 1, Vector3(76, 0, -40))
	fpv.set_patrol(Vector3(76, 0, -40))
	var orion = g.spawn_unit(g.unit_of(1, "uav_strike"), 1, Vector3(74, 0, -36))
	orion.set_patrol(Vector3(74, 0, -36))
	await _wait(2.0)
	_check("EH kucuk dronu dusurur", not is_instance_valid(fpv) or not fpv.alive)
	_check("EH buyuk IHA'nin kilidini bozar", is_instance_valid(orion) and orion.jammed_t > 0.0)
	g.teams[1].researched.append("fiber")
	var fpv2 = g.spawn_unit(g.unit_of(1, "sdrone_fpv"), 1, Vector3(76, 0, -40))
	fpv2.set_patrol(Vector3(76, 0, -40))
	g._ew_tick(1.0)
	_check("fiber optik FPV EH'den etkilenmez", fpv2.alive and fpv2.hp >= fpv2.max_hp)
	for e in [ew, fpv2, orion]:
		if is_instance_valid(e) and e.alive:
			e.die()

	# ---- siper
	var a = g.spawn_unit(g.unit_of(0, "inf"), 0, Vector3(-70, 0, 10))
	var b = g.spawn_unit(g.unit_of(0, "inf"), 0, Vector3(-70, 0, 20))
	g.order_task([a], "dig")
	await _wait(Defs.DIG_TIME + 0.6)
	_check("piyade siper kazar", a.entrenched and a.trench != null)
	var ha: float = a.hp
	var hb: float = b.hp
	a.take_damage(100.0)
	b.take_damage(100.0)
	_check("siperdeki piyade yari hasar alir", is_equal_approx(ha - a.hp, 50.0) and is_equal_approx(hb - b.hp, 100.0))
	a.go(a.position + Vector3(5, 0, 0), false)
	_check("hareket edince siper bozulur", not a.entrenched)

	# ---- ev
	var house = g.houses[0]
	var c = g.spawn_unit(g.unit_of(0, "inf"), 0, house.position + Vector3(8, 0, 6))
	g.order_enter([c], house)
	await _wait(6.0)
	_check("piyade eve girer", c.garrison == house and house.owner_team() == 0)
	var hc: float = c.hp
	c.take_damage(100.0)
	_check("evdeki piyade %60 az hasar alir", is_equal_approx(hc - c.hp, 40.0))
	_check("evdeki piyadenin menzili artar", c.wrange() > float(c.d.range) + 2.0)
	_check("dolu eve dusman giremez", not house.has_room(1))

	# ---- mayın
	var mp := Vector3(60, 0, 40)
	_check("mayin dosenir", g.place_mine(0, mp) and g.team_mines(0) == 1)
	var victim = g.spawn_unit(g.unit_of(1, "tank"), 1, mp)
	var hv: float = victim.hp
	await _wait(0.6)
	_check("mayin dusman aracinda patlar", victim.hp < hv - 100.0 and g.team_mines(0) == 0)

	# ---- engel
	var ob := Vector3(60, 0, 20)
	_check("tanksavar engeli kurulur", g.place_obstacle(0, ob))
	_check("engel yolu kapatir", ter.solid(ob))

	# ---- rütbe ve geri çekilme
	var vet = g.spawn_unit(g.unit_of(0, "tank"), 0, Vector3(-80, 0, 50))
	var base: float = vet.damage_base()
	vet.gain_xp(float(vet.d.cost) * Defs.RANK_XP[0] + 1.0)
	_check("hasar veren birim terfi eder", vet.rank == 1)
	_check("rutbe hasari artirir", vet.damage_base() > base * 1.1)
	g.order_retreat([vet])
	_check("geri cekilen birlik az hasar alir", vet.retreating and vet.damage_taken_mult() < 0.7)

	# ---- görev
	var o := Scenarios.objective(0)
	g.points[o.point].owner_team = 0
	g._objective(0, 100.0)
	_check("gorev noktasini tutmak ilerleme saglar", g.teams[0].obj_prog >= 100.0 and g.objective_fraction(0) > 0.25)
	g.points[o.point].owner_team = Defs.NEUTRAL

	# ---- doktrin yeteneği (Ukrayna: Sürü Saldırısı)
	var before := g.entities.size()
	var spot: Vector3 = g.teams[0].hq.position + Vector3(20, 0, 0)
	g.fog.recompute()
	_check("doktrin yetenegi kullanilir", g.use_ability(0, spot) and g.entities.size() >= before + 8)
	_check("yetenek beklemeye girer", g.ability_ready(0) != "")

	# ---- birim kartı
	var k := g.spawn_building(Defs.bid(0, "kisla"), 0, g.teams[0].hq.position + Vector3(14, 0, 14), true)
	g.select([k])
	await _wait(0.3)
	var card: Button = null
	for btn in g.hud.actions.get_children():
		if btn.has_node("flip"):
			card = btn
			break
	_check("uretim kartinda cevirme simgesi var", card != null)
	if card != null:
		card.get_node("flip").pressed.emit()
		await _wait(0.5)
		_check("kart arkaya doner ve ozellikleri gosterir", card.text.contains("Can") and card.text.contains("Kara gücü"))
		_check("ekranin altinda ipucu gorunur", g.hud.tip_panel.visible and g.hud.tip_lbl.text.length() > 20)
		g.cam.focus = g.teams[0].hq.position + Vector3(16, 0, 6)
		g.cam.dist = 50.0
		await _shot("kart")
		card.pressed.emit()
		await _wait(0.5)
		_check("karta tekrar basinca on yuze doner", not card.text.contains("Kara gücü") and not g.hud.tip_panel.visible)

	print("MECHTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
