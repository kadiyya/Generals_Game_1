extends Node
## Geliştirme aracı: görev sistemini dener. Kullanım:
##   godot --headless --path . -- --objtest --scn=1 [--goal=N]
## goal 0: senaryo görevi (İran–İsrail'de stratejik tesisler), goal 2: tam imha. scn 2: hedeflerin 2. dakikada açılması.

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
			if Scenarios.chosen == 1:
				await _strategic(g, o)
			else:
				await _reveal(g, o)
		"imha":
			await _annihilate(g, o)
		"tut":
			_check("bolgeyi tut gorevi", o.type == "hold" and o.point == 0)
	print("OBJTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)


func _strategic(g: Game, o: Dictionary) -> void:
	if Scenarios.side == 1:
		# Oyuncu İran: tesisler oyuncunun, düşman (İsrail) onları yıkmaya çalışır.
		var mine := 0
		for e in g.entities:
			if e.strategic and e.team == Defs.PLAYER:
				mine += 1
		_check("Iran olarak tesisler oyuncunun", mine == 4)
		_check("dusmanin gorevi stratejik tesisler", Scenarios.objective(1).get("strategic", false))
		return
	_check("Israil'in gorevi stratejik tesisler", o.type == "destroy" and o.get("strategic", false))
	var targets: Array = []
	var guards := 0
	for e in g.entities:
		if e.strategic:
			targets.append(e)
		if e.guard:
			guards += 1
	_check("4 stratejik tesis kurulu", targets.size() == 4)
	_check("tesisler dusmanin ve hep gorunur", targets.all(func(e): return Defs.foe(Defs.PLAYER, e.team) and e.discovered and g.is_obj_target(e)))
	_check("tesislerin bagimsiz savunuculari var", guards >= 16)
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
	_check("dort tesis yikilinca zafer", g.over and g.winner == Defs.SIDE[Defs.PLAYER])
	_check("zafer nedeni gorev", g.end_reason.begins_with("Görev tamamlandı"))


func _reveal(g: Game, o: Dictionary) -> void:
	_check("Pakistan'in gorevi uretim tesisleri", o.type == "destroy")
	var k := g.spawn_building(Defs.bid(1, "kisla"), 1, g.terrain.nearest_free(g.teams[1].hq.position + Vector3(0, 0, 18)), true)
	g.fog.recompute()
	_check("ilk iki dakikada hedef gizli", not k.discovered and not g.is_obj_target(k))
	g.time = Game.REVEAL_AT + 1.0
	g._reveal_targets()
	_check("2. dakikadan sonra hedef haritada", k.discovered and g.is_obj_target(k))
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
