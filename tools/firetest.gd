extends Node
## Geliştirme aracı: oyuncunun silahlı bütün kara birlikleri bir düşman binasına "saldır" emri alır; her birinin
## binaya gerçekten hasar verdiğini (tecrübe kazandığını) doğrular.
## Kullanım: godot --headless --path . --fixed-fps 30 -- --firetest --scn=N [--side=N]

var fails := 0


func _ready() -> void:
	_run.call_deferred()


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout


func _run() -> void:
	var g := Game.I
	for c in g.get_children():
		if c is EnemyAI:
			c.process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(0.5)
	var hq: Vector3 = g.teams[0].hq.position
	var tp: Vector3 = g.terrain.nearest_free(hq + Vector3(-signf(hq.x) * 70.0, 0, 0))
	var tb := g.spawn_building(Defs.bid(1, "kisla"), 1, tp, true)
	tb.max_hp = 1.0e7
	tb.hp = tb.max_hp
	var shooters: Array = []
	var k := 0
	for id in Defs.UNITS:
		var ud: Dictionary = Defs.UNITS[id]
		if ud.cc != Defs.COUNTRY[0] or ud.get("air", false) or not ud.has("dmg"):
			continue
		var ang := k * TAU / 12.0
		k += 1
		var sp: Vector3 = g.terrain.nearest_free(tp + Vector3(cos(ang), 0, sin(ang)) * (tb.radius + 14.0 + float(ud.get("min_range", 0.0))))
		shooters.append(g.spawn_unit(id, 0, sp))
	g.fog.recompute()
	g.order_attack(shooters, tb)
	await _wait(25.0)
	for su in shooters:
		var ok: bool = su.alive and su.xp > 0.0
		print(("GECTI  " if ok else "KALDI  ") + "%s binaya ates eder" % su.d.name)
		if not ok:
			fails += 1
			print("    emir=%s hedef=%s uzaklik=%.1f menzil=%.1f vurabilir=%s gorus=%s" % [su.order, su.target == tb, Entity.flat(su.position, tb.position) - tb.radius, su.weapon_range(), su.can_hit(tb), g.terrain.los_clear(su.global_position, tb.global_position, Entity.los_skip(tb))])
	print("FIRETEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
