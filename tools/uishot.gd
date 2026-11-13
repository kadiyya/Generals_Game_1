extends Node
## Geliştirme aracı: üretim panellerinin (boş yuvalar, deneysel kartlar, doktrin fiyatları) ve hava araçlarının
## mühimmat göstergesinin görüntüsünü alır. Kullanım: godot --path . -- --uishot --scn=N [--side=N] --shots=KLASÖR

var out_dir := "."


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var g := Game.I
	var ts = g.teams[0]
	ts.money = 50000.0
	ts.tier = 3
	var hq: Vector3 = ts.hq.position
	var dx := -signf(hq.x)
	var k := g.spawn_building(Defs.bid(0, "kisla"), 0, hq + Vector3(dx * 16, 0, -14), true)
	var f := g.spawn_building(Defs.bid(0, "fabrika"), 0, hq + Vector3(dx * 16, 0, 12), true)
	var af := g.spawn_building(Defs.bid(0, "havaalani"), 0, hq + Vector3(dx * 30, 0, 0), true)
	var fz := g.spawn_building(Defs.bid(0, "fuze"), 0, hq + Vector3(0, 0, -24), true)
	g.cam.focus = hq + Vector3(dx * 20, 0, 0)
	g.cam.dist = 70.0
	for i in 3:
		var u = g.spawn_unit(g.unit_of(0, "fighter") if g.unit_of(0, "fighter") != "" else g.unit_of(0, "uav_strike"), 0, hq + Vector3(dx * 20 + i * 6, 0, 4))
		u.set_patrol(hq + Vector3(dx * 20, 0, 0))
		u.ammo = int(u.d.ammo) - i
	await _frames(20)
	for b in [[k, "panel_kisla"], [f, "panel_fabrika"], [af, "panel_havaalani"], [fz, "panel_fuze"]]:
		g.select([b[0]])
		await _shot(b[1])
	g.open_build_menu()
	await _shot("panel_insa")
	get_tree().quit()


func _frames(n: int) -> void:
	for i in n:
		await RenderingServer.frame_post_draw


func _shot(name: String) -> void:
	await _frames(6)
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
