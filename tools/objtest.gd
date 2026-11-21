extends Node
## Geliştirme aracı: görev sistemini dener. Kullanım:
##   godot --headless --path . -- --objtest --scn=1 [--goal=N]
## goal 0: senaryo görevi (İran–İsrail ve Pakistan–Hindistan'da stratejik tesisler; tutma görevinde kesintisiz sayaç),
## goal 1: bölgeyi tut, goal 2: tam imha.

var fails := 0


func _ready() -> void:
	_run.call_deferred()


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
	await _wait(0.5)
	var o := Scenarios.objective(Defs.PLAYER)
	match Scenarios.GOALS[Scenarios.goal].id:
		"senaryo":
			if o.get("strategic", false) or Scenarios.objective(1).get("strategic", false):
				await _strategic(g, o)
			else:
				await _hold(g, o)
		"imha":
			await _annihilate(g, o)
		"tut":
			_check("bolgeyi tut gorevi", o.type == "hold" and o.point == 0)
			await _hold(g, o)
	print("OBJTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _strategic(g: Game, o: Dictionary) -> void:
	if Scenarios.side == 1:
		# Oyuncu İran: tesisler oyuncunun, düşman (İsrail) onları yıkmaya çalışır.
		var mine := 0
		for e in g.entities:
			if e.strategic and e.team == Defs.PLAYER:
				mine += 1
		_check("tesisler oyuncunun", mine == Defs.MAP.strategic.size())
		_check("dusmanin gorevi stratejik tesisler", Scenarios.objective(1).get("strategic", false))
		return
	_check("gorev stratejik tesisler", o.type == "destroy" and o.get("strategic", false))
	var need: int = int(o.count)
	var targets: Array = []
	var guards := 0
	for e in g.entities:
		if e.strategic:
			targets.append(e)
		if e.guard:
			guards += 1
	_check("%d stratejik tesis kurulu" % need, targets.size() == need)
	# Hedefler düşman üssünün dibinde doğmaz.
	var near := 1e9
	for e in targets:
		for t in Defs.N:
			if Defs.foe(Defs.PLAYER, t) and g.teams[t].hq != null:
				near = minf(near, Entity.flat(e.position, g.teams[t].hq.position))
	print("  en yakin tesis - dusman karargahi: %.0f" % near)
	_check("tesisler dusman ussunden uzakta", near > 70.0)
	_check("tesisler dusmanin ve hep gorunur", targets.all(func(e): return Defs.foe(Defs.PLAYER, e.team) and e.discovered and g.is_obj_target(e)))
	_check("tesislerin bagimsiz savunuculari var", guards >= need * 4)
	_check("savunucular birlik sinirina sayilmaz", g.teams[1].pop <= 4)
	_check("tesisler dusmanin enerjisini bozmaz", g.teams[1].power_used == 0)
	_check("tesisler kademe sartini saglamaz", g.count_kind(1, "teknoloji") == 0)
	# Stratejik olmayan bir hedef sayılmaz.
	var extra := g.spawn_building(Defs.bid(1, "santral"), 1, g.terrain.nearest_free(g.teams[1].hq.position + Vector3(0, 0, 16)), true)
	extra.take_damage(extra.max_hp * 10.0)
	await _wait(0.2)
	_check("isaretsiz santral gorevi ilerletmez", is_zero_approx(g.teams[0].obj_prog))
	for i in targets.size():
		targets[i].take_damage(targets[i].max_hp * 10.0)
		await _wait(0.2)
		if i < targets.size() - 1:
			_check("tesis %d sayilir" % (i + 1), int(g.teams[0].obj_prog) == i + 1 and not g.over)
	_check("tesisler yikilinca zafer", g.over and g.winner == Defs.SIDE[Defs.PLAYER])
	_check("zafer nedeni gorev", g.end_reason.begins_with("Görev tamamlandı"))


## Tutma görevi: süre kesintisizdir; nokta elden çıkınca sayaç sıfırlanır.
func _hold(g: Game, o: Dictionary) -> void:
	_check("tutma gorevi", o.type == "hold")
	var pt: SupplyPoint = g.points[o.point]
	pt.claim(0)
	await _wait(1.5)
	_check("tutulan sure artar", g.teams[0].obj_prog > 0.5)
	pt.claim(1)
	await _wait(0.3)
	_check("nokta kaybedilince sayac sifirlanir", is_zero_approx(g.teams[0].obj_prog))
	pt.claim(0)
	await _wait(1.0)
	_check("geri alininca sayac bastan baslar", g.teams[0].obj_prog > 0.3 and g.teams[0].obj_prog < 1.5)
	pt.claim(-1)
	await _wait(0.3)
	_check("nokta kimsesiz kalinca da sifirlanir", is_zero_approx(g.teams[0].obj_prog))
	# Düşman görevini bitirirse yenilgi nedeni doğru yazılır.
	g.points[0].claim(1)
	g.teams[1].obj_prog = 599.5
	await _wait(1.0)
	_check("dusman gorevi bitirince yenilgi", g.over and g.winner != Defs.SIDE[Defs.PLAYER])
	_check("yenilgi nedeni dusmanin gorevi", g.end_reason.begins_with("Düşman görevini tamamladı"))


func _annihilate(g: Game, o: Dictionary) -> void:
	_check("tam imha gorevi", o.type == "annihilate")
	g.teams[1].hq.take_damage(1e9)
	await _wait(1.2)
	_check("karargah yikilinca oyun bitmez", not g.over)
	_check("kalan dusman sayilir", g.foe_left[1] > 0)
	for e in g.entities.duplicate():
		if e.alive and Defs.foe(Defs.PLAYER, e.team):
			e.take_damage(1e9)
	await _wait(1.5)
	_check("her sey yok edilince zafer", g.over and g.winner == Defs.SIDE[Defs.PLAYER])
	_check("zafer nedeni tam imha", g.end_reason.contains("tamamen yok edildi"))
