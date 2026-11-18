extends Node
## Geliştirme aracı: haritanın görüntüsünü denetlemek için tepe, su, dağ, orman, köprü, kasaba ve üsten
## bölge ve üsten ekran görüntüsü alır; arazi kurulum süresini yazar.
## Kullanım (gerçek pencere gerekir): godot --path . -- --viewtest --shots=KLASÖR [--scn=N] [--fog]

var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
	_run.call_deferred()


## türü k olan ve çevresi de çoğunlukla k olan bir hücrenin yeri (yoksa INF)
func _find(k: int) -> Vector3:
	var ter := Game.I.terrain
	var best := Vector3.INF
	var bn := -1
	for y in range(4, ter.gh - 4, 3):
		for x in range(4, ter.gw - 4, 3):
			if ter.kind[y * ter.gw + x] != k:
				continue
			var n := 0
			for dy in range(-3, 4):
				for dx in range(-3, 4):
					if ter.kind[(y + dy) * ter.gw + x + dx] == k:
						n += 1
			if n > bn:
				bn = n
				best = ter.center(Vector2i(x, y))
	return best


func _run() -> void:
	var g := Game.I
	var t0 := Time.get_ticks_msec()
	var probe := Terrain.new()
	g.add_child(probe)
	print("VIEWTEST arazi kurulum suresi: %d ms" % (Time.get_ticks_msec() - t0))
	probe.queue_free()
	if not OS.get_cmdline_user_args().has("--fog"):
		g.fog.visible = false
		for pm in g.terrain.fog_mats:
			pm.set_shader_parameter("vis", null)
	g.hud.visible = false
	var spots: Array = [["genel", Vector3(0, 0, 8), 210.0], ["merkez", Vector3(0, 0, 0), 70.0]]
	var want := [["tepe", Terrain.HILL, 40.0], ["su", Terrain.WATER, 50.0], ["dag", Terrain.MOUNTAIN, 70.0],
		["orman", Terrain.FOREST, 34.0], ["agac_hatti", Terrain.TREES, 34.0], ["kopru", Terrain.BRIDGE, 34.0], ["yikinti", Terrain.RUINS, 30.0]]
	for w in want:
		var p := _find(w[1])
		if p != Vector3.INF:
			spots.append([w[0], p + Vector3(0, 0, 3), w[2]])
	if not g.regions.is_empty():
		spots.append(["bolge", g.regions[0].position + Vector3(0, 0, 4), 46.0])
	spots.append(["us", g.teams[0].hq.position, 50.0])
	for s in spots:
		g.cam.focus = s[1]
		g.cam.dist = s[2]
		for i in 6:
			await RenderingServer.frame_post_draw
		if out_dir != "":
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("harita_%d_%s.png" % [Scenarios.chosen, s[0]]))
	print("VIEWTEST BITTI  fps=%d" % Engine.get_frames_per_second())
	get_tree().quit()
