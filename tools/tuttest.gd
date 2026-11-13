extends Node
## Geliştirme aracı: eğitimi oyuncu yerine adım adım oynar; her adımın ilerlediğini ve eğitim
## sürerken yapay zekânın beklediğini doğrular.
## Kullanım: godot --headless --path . --fixed-fps 30 -- --tutorial --tuttest

func _ready() -> void:
	_run.call_deferred()


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout


func _run() -> void:
	var g := Game.I
	var tut: Node = null
	for c in g.get_children():
		if c.get_script() != null and c.get_script().resource_path.ends_with("tutorial.gd"):
			tut = c
	var fails := 0
	var log: Array = []
	var hq: Vector3 = g.teams[0].hq.position
	var dir := -signf(hq.x)
	var acts := [
		func(): g.cam.focus += Vector3(10, 0, 0),
		func(): g.place_building(0, "kisla", hq + Vector3(dir * 16, 0, -10)),
		func():
			var k = g.nearest_building(0, "kisla", hq)
			if k != null and k.built and k.queue.is_empty():
				g.queue_unit(k, g.unit_of(0, "inf")),
		func():
			for e in g.entities:
				if e.team == 0 and e.cls == "inf" and e.order == "idle":
					e.go(g.points[0].position, true),
		func():
			for e in g.entities:
				if e.team == 0 and e.cls == "inf" and e.order == "dig":
					return
			for e in g.entities:
				if e.team == 0 and e.cls == "inf":
					g.order_task([e], "dig")
					break,
		func():
			g.buy_crane(0)
			g.place_building(0, "santral", hq + Vector3(dir * 2, 0, 16))
			g.place_building(0, "fabrika", hq + Vector3(dir * 18, 0, 12)),
		func():
			var f = g.nearest_building(0, "fabrika", hq)
			if f != null and f.built and f.queue.is_empty():
				g.queue_unit(f, g.unit_of(0, "ifv")),
		func():
			g.select_category("")
			g.save_group(0),
		func():
			g.fog.recompute()
			g.use_ability(0, hq + Vector3(dir * 20, 0, 0)),
		func(): pass,
	]
	var out := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out = a.trim_prefix("--shots=")
	if out != "" and DisplayServer.get_name() != "headless":
		await _wait(1.0)
		g.cam.focus = hq + Vector3(dir * 14, 0, 0)
		g.cam.dist = 52.0
		for n in 4:
			await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(out.path_join("egitim.png"))
	var last := -1
	var ai_built := false
	var t := 0.0
	while tut != null and is_instance_valid(tut) and t < 400.0:
		if tut.i != last:
			last = tut.i
			log.append(last)
		acts[mini(tut.i, acts.size() - 1)].call()
		for e in g.entities:
			if e.team == 1 and e.is_building and e.kind != "hq":
				if g.tutorial_on:
					ai_built = true
		await _wait(1.0)
		t += 1.0
	var done := tut == null or not is_instance_valid(tut)
	print(("GECTI  " if done else "KALDI  ") + "egitim butun adimlarla biter (%s)" % str(log))
	print(("GECTI  " if not ai_built else "KALDI  ") + "egitim surerken yapay zeka bekler")
	print(("GECTI  " if not g.tutorial_on else "KALDI  ") + "egitimden sonra mac baslar")
	fails = int(not done) + int(ai_built) + int(g.tutorial_on)
	print("TUTTEST BITTI  hata=%d  sure=%d" % [fails, int(t)])
	get_tree().quit(1 if fails > 0 else 0)
