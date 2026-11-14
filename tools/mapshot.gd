extends Node
## Geliştirme aracı: haritanın tamamını yukarıdan ve birkaç yakın açıdan çekip çıkar.
## Kullanım: godot --path . -- --mapshot --scn=N --shots=KLASÖR  (--perfonly: yalnızca kare sürelerini ölçer)

var out_dir := "."


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var g := Game.I
	g.fog.visible = false
	g.hud.visible = false
	for e in g.entities:
		e.visible = true
	var cam: Camera3D = g.cam.camera
	g.cam.set_process(false)
	var t0 := Time.get_ticks_msec()
	await _frames(3)
	print("ilk kareler: %d ms" % (Time.get_ticks_msec() - t0))
	# oyun kamerasıyla ortalama kare süresi
	g.cam.set_process(true)
	g.cam.focus = g.teams[0].hq.position
	g.cam.dist = 60.0
	await _frames(10)
	t0 = Time.get_ticks_msec()
	await _frames(30)
	print("PERF  oyun kamerasi: %.1f ms/kare" % ((Time.get_ticks_msec() - t0) / 30.0))
	g.cam.dist = 200.0
	await _frames(10)
	t0 = Time.get_ticks_msec()
	await _frames(30)
	print("PERF  uzak kamera: %.1f ms/kare" % ((Time.get_ticks_msec() - t0) / 30.0))
	g.cam.dist = 60.0
	for step in (["golge_kapali", "agaclar_gizli", "zemin_gizli", "her_sey_gizli"] if OS.get_cmdline_user_args().has("--perfonly") else []):
		match step:
			"golge_kapali":
				for c in g.get_children():
					if c is DirectionalLight3D:
						c.shadow_enabled = false
			"agaclar_gizli":
				for c in g.terrain.get_children():
					if c is MultiMeshInstance3D:
						c.visible = false
			"zemin_gizli":
				g.terrain.visible = false
			"her_sey_gizli":
				for c in g.get_children():
					if c is Node3D and not (c is Camera3D or c is CameraRig or c is DirectionalLight3D):
						c.visible = false
		await _frames(10)
		t0 = Time.get_ticks_msec()
		await _frames(30)
		print("PERF  %s: %.1f ms/kare" % [step, (Time.get_ticks_msec() - t0) / 30.0])
	g.cam.set_process(false)
	if OS.get_cmdline_user_args().has("--perfonly"):
		get_tree().quit()
		return
	cam.far = 2000.0
	cam.position = Vector3(0, 620, 120)
	cam.rotation = Vector3(-1.38, 0, 0)
	await _shot("harita_ust")
	var hq: Vector3 = g.teams[0].hq.position
	var views := [["us", hq + Vector3(0, 0, 0), 70.0]]
	for i in mini(3, g.bridges.size()):
		views.append(["kopru%d" % i, g.bridges[i].position, 45.0])
	for i in mini(2, g.houses.size()):
		views.append(["kasaba%d" % i, g.houses[i * 5 % g.houses.size()].position, 55.0])
	for v in views:
		cam.position = v[1] + Vector3(0, sin(1.0), cos(1.0)) * v[2]
		cam.rotation = Vector3(-1.0, 0, 0)
		await _shot(v[0])
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _frames(3)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
