extends Node
## Geliştirme aracı: haritanın görüntüsünü denetlemek için birkaç noktadan ekran görüntüsü alır.
## Kullanım (gerçek pencere gerekir): godot --path . -- --maptest --shots=KLASÖR [--scn=N] [--fog]

var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var g := Game.I
	var t0 := Time.get_ticks_msec()
	var probe := Terrain.new()
	g.add_child(probe)
	print("MAPTEST arazi kurulum suresi: %d ms" % (Time.get_ticks_msec() - t0))
	probe.queue_free()
	if not OS.get_cmdline_user_args().has("--fog"):
		g.fog.visible = false
		for pm in g.terrain.fog_mats:
			pm.set_shader_parameter("vis", null)
	g.hud.visible = false
	var m: Dictionary = Defs.MAP
	var spots: Array = [["genel", Vector3(0, 0, 8), 130.0], ["merkez", Vector3(0, 0, 0), 60.0]]
	if not m.get("hills", []).is_empty():
		var r: Array = m.hills[0]
		spots.append(["tepe", Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5 + 4.0), 34.0])
	if not m.water.is_empty():
		var r: Array = m.water[0]
		spots.append(["su", Vector3(clampf((r[0] + r[2]) * 0.5, -60, 60), 0, clampf((r[1] + r[3]) * 0.5, -50, 50)), 50.0])
	if not m.rock.is_empty():
		var r: Array = m.rock[0]
		spots.append(["dag", Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5 + 6.0), 55.0])
	if not m.get("forest", []).is_empty():
		var r: Array = m.forest[0]
		spots.append(["orman", Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5 + 3.0), 30.0])
	if not m.bridges.is_empty():
		var r: Array = m.bridges[1]
		spots.append(["kopru", Vector3((r[0] + r[2]) * 0.5, 0, (r[1] + r[3]) * 0.5 + 3.0), 30.0])
	spots.append(["us", g.teams[0].hq.position, 45.0])
	for s in spots:
		g.cam.focus = s[1]
		g.cam.dist = s[2]
		for i in 6:
			await RenderingServer.frame_post_draw
		if out_dir != "":
			get_viewport().get_texture().get_image().save_png(out_dir.path_join("harita_%d_%s.png" % [Scenarios.chosen, s[0]]))
	print("MAPTEST BITTI  fps=%d" % Engine.get_frames_per_second())
	get_tree().quit()
