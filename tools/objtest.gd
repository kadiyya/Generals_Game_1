extends Node
## Geliştirme aracı: görev sistemini dener. Kullanım:
##   godot --headless --path . -- --objtest --scn=1 [--goal=N]
## goal 0: senaryo görevi (İran–İsrail'de bağımsız kuvvetlerin tuttuğu 4 bölge), goal 2: tam imha. scn 2: hedeflerin 2. dakikada açılması.

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
				await _zones(g, o)
			elif o.get("strategic", false) or Scenarios.objective(1).get("strategic", false):
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


## İran–İsrail: dört bölgeyi bağımsız kuvvetler tutar; iki orduya da saldırırlar, ölünce zayıf yeniden doğarlar;
## iki taraf da dördünü birlikte tutmaya çalışır.
func _zones(g: Game, o: Dictionary) -> void:
	var me: int = Defs.SIDE[Defs.PLAYER]
	_check("iki tarafin gorevi bolgeler", o.type == "zones" and Scenarios.objective(1).get("type", "") == "zones")
	_check("4 bolge kurulu", g.regions.size() == 4)
	_check("bagimsiz kuvvet ayri taraf, iki orduya da dusman", Defs.IND == Defs.N and Defs.foe(0, Defs.IND) and Defs.foe(1, Defs.IND))
	var per: Array = []
	for rg in g.regions:
		var n := 0
		for e in g.entities:
			if e.alive and e.team == Defs.IND and Entity.flat(e.position, rg.position) < Region.RADIUS + 6.0:
				n += 1
		per.append(n)
	_check("her bolgede bagimsiz savunucu var", per.all(func(n): return n >= 6))
	_check("bagimsizlar birlik sinirina ve imha sayimina girmez", g.teams[0].pop <= 4 and g.foe_left.size() == 2)
	_check("bolgeler basta tarafsiz", g.regions.all(func(r): return r.owner_side == -1))
	# Bağımsızlar iki orduya da saldırır.
	var r0: Region = g.regions[0]
	var r1: Region = g.regions[1]
	var mine = g.spawn_unit(g.unit_of(0, "ifv"), 0, g.terrain.nearest_free(r0.position + Vector3(Region.RADIUS + 4.0, 0, 0)))
	var theirs = g.spawn_unit(g.unit_of(1, "ifv"), 1, g.terrain.nearest_free(r1.position + Vector3(Region.RADIUS + 4.0, 0, 0)))
	mine.set_process(false)
	theirs.set_process(false)
	var h0: float = mine.hp
	var h1: float = theirs.hp
	await _wait(4.0)
	_check("bagimsizlar oyuncuya saldirir", mine.hp < h0)
	_check("bagimsizlar dusmana da saldirir", theirs.hp < h1)
	mine.set_process(true)
	# Savunucu varken bölge alınamaz.
	var squad: Array = []
	for i in 3:
		var u = g.spawn_unit(g.unit_of(0, "ifv"), 0, g.terrain.nearest_free(r0.position + Vector3(i * 2.0 - 2.0, 0, 3.0)))
		u.max_hp = 1e6
		u.hp = 1e6
		squad.append(u)
	mine.max_hp = 1e6
	mine.hp = 1e6
	await _wait(Region.CAP_TIME * 0.6)
	_check("savunucu varken bolge alinamaz", r0.owner_side == -1)
	for e in g.entities.duplicate():
		if e.alive and e.team == Defs.IND and Entity.flat(e.position, r0.position) < Region.RADIUS + 26.0:
			e.take_damage(1e9)
	await _wait(Region.CAP_TIME + 1.5)
	_check("savunucular olunce bolge alinir", r0.owner_side == me)
	_check("bolge sayilir", g.regions_held(me) == 1)
	# Yeniden doğma: zayıf bir grup belirir.
	r0.respawn_t = Region.RESPAWN - 0.6
	await _wait(1.6)
	var back: Array = []
	for e in g.entities:
		if e.alive and e.team == Defs.IND and Entity.flat(e.position, r0.position) < Region.RADIUS + 6.0:
			back.append(e)
	_check("savunucular bir sure sonra yeniden dogar", back.size() >= 3 and back.size() < per[0])
	_check("yeniden doganlar zayif", not back.is_empty() and back.all(func(e): return e.max_hp < float(Defs.UNITS[e.def_id].hp) * 0.7))
	# Dördü birden: görev süresi işler, dolunca zafer.
	for e in g.entities.duplicate():
		if e.alive and e.team == Defs.IND:
			e.take_damage(1e9)
	for rg in g.regions:
		rg.owner_side = me
		rg.respawn_t = -1.0
	# Süre kesintisiz: bölgelerden biri elden çıkınca sayaç sıfırlanır.
	g.teams[0].obj_prog = 30.0
	await _wait(0.5)
	_check("dort bolge tutulurken sure isler", g.teams[0].obj_prog > 30.2)
	g.regions[2].owner_side = -1
	await _wait(0.3)
	_check("bir bolge kaybedilince sayac sifirlanir", is_zero_approx(g.teams[0].obj_prog))
	g.regions[2].owner_side = me
	g.regions[2].respawn_t = -1.0
	for e in g.entities.duplicate():
		if e.alive and e.team == Defs.IND:
			e.take_damage(1e9)
	g.teams[0].obj_prog = float(o.secs) - 1.0
	await _wait(2.0)
	_check("dort bolge tutulunca zafer", g.over and g.winner == me)
	_check("zafer nedeni gorev", g.end_reason.begins_with("Görev tamamlandı"))


## Pakistan–Hindistan: üç üretim tesisi düşman üssünde değil, ileri hatta hazır kurulu ve işaretli.
func _strategic(g: Game, o: Dictionary) -> void:
	var need: int = Defs.MAP.strategic.size()
	if Scenarios.side == 1:
		var mine := 0
		for e in g.entities:
			if e.strategic and e.team == Defs.PLAYER:
				mine += 1
		_check("tesisler oyuncunun", mine == need)
		_check("dusmanin gorevi stratejik tesisler", Scenarios.objective(1).get("strategic", false))
		return
	_check("gorev isaretli uretim tesisleri", o.type == "destroy" and o.get("strategic", false) and int(o.count) == need)
	var targets: Array = []
	for e in g.entities:
		if e.strategic:
			targets.append(e)
	_check("%d tesis kurulu" % need, targets.size() == need)
	var near := 1e9
	for e in targets:
		for t in Defs.N:
			if Defs.foe(Defs.PLAYER, t) and t < g.teams.size() and g.teams[t].hq != null:
				near = minf(near, Entity.flat(e.position, g.teams[t].hq.position))
	print("  en yakin tesis - dusman karargahi: %.0f" % near)
	_check("tesisler dusman ussunden uzakta", near > 60.0)
	_check("tesisler dusmanin ve hep gorunur", targets.all(func(e): return Defs.foe(Defs.PLAYER, e.team) and e.discovered and g.is_obj_target(e)))
	# Düşmanın kendi kurduğu üretim binası sayılmaz.
	var extra := g.spawn_building(Defs.bid(1, "kisla"), 1, g.terrain.nearest_free(g.teams[1].hq.position + Vector3(0, 0, 16)), true)
	extra.take_damage(extra.max_hp * 10.0)
	await _wait(0.2)
	_check("isaretsiz kisla gorevi ilerletmez", is_zero_approx(g.teams[0].obj_prog))
	for i in targets.size():
		targets[i].take_damage(targets[i].max_hp * 10.0)
		await _wait(0.2)
	_check("tesisler yikilinca zafer", g.over and g.winner == Defs.SIDE[Defs.PLAYER])


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
