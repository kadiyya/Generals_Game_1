extends Node
## Geliştirme aracı: senaryodaki bütün birim ve bina modellerini yan yana dizip ekran görüntüsü alır.
## Kullanım (gerçek pencere gerekir): godot --path . -- --gallery --shots=KLASÖR [--scn=N]

var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var g := Game.I
	g.set_process(false)
	for c in g.get_children():
		if c is EnemyAI or c is Fog or c is SupplyPoint or c is Terrain or c is Garrison or c is Bridge or c is Deposit:
			c.set_process(false)
			if c is Node3D:
				c.visible = false
	g.hud.visible = false
	for e in g.entities.duplicate():
		e.visible = false
		e.set_process(false)
	var stage := Node3D.new()
	g.add_child(stage)
	Models.box(stage, Vector3(400, 0.1, 400), Vector3(0, 0.3, 0), Color(0.4, 0.45, 0.32))
	for team in (2 if not OS.get_cmdline_user_args().has("--archonly") else 0):
		var cc: String = Defs.COUNTRY[team]
		var air: Array = []
		var ground: Array = []
		for id in Defs.UNITS:
			var d: Dictionary = Defs.UNITS[id]
			if d.cc == cc:
				if d.get("air", false):
					air.append(d)
				else:
					ground.append(d)
		var sets := [["hava", air, 8.5, 48.0], ["kara", ground, 8.0, 46.0]]
		for s in sets:
			for c in stage.get_children().slice(1):
				c.queue_free()
			var list: Array = s[1]
			var cols := 5
			for i in list.size():
				var m := Models.build(list[i], team)
				m.position = Vector3((i % cols - (cols - 1) * 0.5) * s[2], 0.4 if s[0] == "kara" else 1.5, (i / cols - 1.0) * s[2])
				m.rotation.y = PI
				stage.add_child(m)
			g.cam.focus = Vector3(0, 0, 0)
			g.cam.dist = s[3]
			await _shot("model_%s_%s" % [cc, s[0]])
	# binalar: her ülkenin kendi mimarisiyle; ardından haritanın köy evleri
	var kinds := ["hq", "kisla", "santral", "fabrika", "teknoloji", "havaalani", "maden", "ileri", "sam", "fuze"]
	for team in 2:
		for c in stage.get_children().slice(1):
			c.queue_free()
		for i in kinds.size():
			var m := Models.build(Defs.BUILDINGS[Defs.bid(team, kinds[i])], team)
			m.position = Vector3((i % 5 - 2.0) * 15.0, 0.35, (i / 5 - 0.5) * 16.0)
			m.rotation.y = 0.5
			stage.add_child(m)
		g.cam.focus = Vector3(0, 0, 2)
		g.cam.dist = 62.0
		await _shot("model_binalar_%s" % Defs.COUNTRY[team])
	for c in stage.get_children().slice(1):
		c.queue_free()
	var civ := ["house", "block", "ruin_factory", "deposit"]
	for i in civ.size():
		var m := Models.build({"model": civ[i]}, 0)
		m.position = Vector3((i - 1.5) * 12.0, 0.35, 0)
		m.rotation.y = 0.5
		stage.add_child(m)
	g.cam.dist = 50.0
	await _shot("model_kasaba")
	get_tree().quit()


func _shot(name: String) -> void:
	for i in 4:
		await RenderingServer.frame_post_draw
	if out_dir != "":
		get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
