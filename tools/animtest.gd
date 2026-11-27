extends Node
## Geliştirme aracı: iki küçük grubu karşı karşıya getirip çatışma anından ekran görüntüleri alır.
## Kullanım (gerçek pencere gerekir): godot --path . --fixed-fps 30 -- --animtest --shots=KLASÖR

var out_dir := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
	_run.call_deferred()


func _run() -> void:
	var g := Game.I
	for c in g.get_children():
		if c is EnemyAI:
			c.set_process(false)
	var mid: Vector3 = g.teams[0].hq.position + Vector3(-signf(g.teams[0].hq.position.x) * 30.0, 0, 0)
	var dirx := -signf(g.teams[0].hq.position.x)
	var mine: Array = []
	for cls in ["tank", "tank", "ifv", "inf", "inf", "at", "arty"]:
		mine.append(g.spawn_unit(g.unit_of(0, cls) if g.unit_of(0, cls) != "" else g.unit_of(0, "ifv"), 0, mid + Vector3(-dirx * 16.0, 0, mine.size() * 3.5 - 10.0)))
	var foes: Array = []
	for cls in ["tank", "tank", "ifv", "inf", "inf"]:
		foes.append(g.spawn_unit(g.unit_of(1, cls) if g.unit_of(1, cls) != "" else g.unit_of(1, "ifv"), 1, mid + Vector3(dirx * 10.0, 0, foes.size() * 3.5 - 7.0)))
	var jet = g.spawn_unit(g.unit_of(1, "fighter"), 1, mid + Vector3(dirx * 14.0, 0, 0))
	var aa = g.spawn_unit(g.unit_of(0, "spaag"), 0, mid + Vector3(-dirx * 6.0, 0, 12.0))
	jet.set_patrol(mid)
	g.order_move(mine.slice(0, 6), mid + Vector3(dirx * 4.0, 0, 0), true)
	g.cam.focus = mid
	g.cam.dist = 40.0
	var moved := false
	var turned := false
	var fired := false
	for i in 9:
		await get_tree().create_timer(1.0).timeout
		for u in mine:
			if is_instance_valid(u) and u.alive:
				if u.moving:
					moved = true
				if u.turret != null and absf(u.turret.rotation.y) > 0.2:
					turned = true
				if u.recoil > 0.0:
					fired = true
		if i in [1, 4, 6, 8]:
			await RenderingServer.frame_post_draw
			if out_dir != "":
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("anim_%d.png" % i))
	print("ANIMTEST  hareket=%s  taret_dondu=%s  geri_tepme=%s  ucak=%s  hs=%s" % [moved, turned, fired, is_instance_valid(jet) and jet.alive, is_instance_valid(aa) and aa.alive])
	# 2. bölüm: emir önceliği. Yan tarafta düşman varken "git" emri alan birlik yolundan sapmaz, yürürken ateş eder;
	# zırhlının kulesi gövdeden bağımsız hedefe döner. Piyade bacakları adım atar.
	for e in g.entities.duplicate():
		if e is Unit and e.alive:
			e.die()
	await get_tree().create_timer(1.5).timeout
	var p0: Vector3 = mid + Vector3(-dirx * 20.0, 0, -14.0)
	var walker = g.spawn_unit(g.unit_of(0, "tank") if g.unit_of(0, "tank") != "" else g.unit_of(0, "ifv"), 0, p0)
	var sq = g.spawn_unit(g.unit_of(0, "inf"), 0, p0 + Vector3(0, 0, 4.0))
	var dummy = g.spawn_unit(g.unit_of(1, "inf"), 1, mid + Vector3(0, 0, -4.0))
	dummy.max_hp = 1e6
	dummy.hp = 1e6
	dummy.set_process(false)
	var goal: Vector3 = p0 + Vector3(dirx * 40.0, 0, 0)
	g.order_move([walker, sq], goal, false)
	g.cam.focus = mid + Vector3(0, 0, -8.0)
	g.cam.dist = 30.0
	var kept := true
	var fired2 := false
	var max_turn := 0.0
	var leg_max := 0.0
	for i in 60:
		await get_tree().create_timer(0.1).timeout
		if walker.order != "move" and walker.order != "idle":
			kept = false
		if walker.target != null and walker.cd_timer > 0.0:
			fired2 = true
		if walker.turret != null:
			max_turn = maxf(max_turn, absf(walker.turret.rotation.y))
		if not sq.figs.is_empty():
			leg_max = maxf(leg_max, absf(sq.figs[0].legs[0].rotation.x))
		if i == 25:
			await RenderingServer.frame_post_draw
			if out_dir != "":
				get_viewport().get_texture().get_image().save_png(out_dir.path_join("anim_yuruyus.png"))
	var on_path: bool = Entity.flat(walker.position, goal) < Entity.flat(p0, goal)
	print("EMIRTEST  emir_korundu=%s  yururken_ates=%s  taret_maks=%.2f  ilerledi=%s  bacak_maks=%.2f" % [kept, fired2, max_turn, on_path, leg_max])
	# 3. bölüm: kayıp veren manga — vurulan asker yere yığılır
	sq.order = "idle"
	sq.take_damage(sq.max_hp * 0.55, dummy)
	await get_tree().create_timer(0.8).timeout
	var downs := 0
	for f in sq.figs:
		if f.down:
			downs += 1
	g.cam.focus = sq.position
	g.cam.dist = 18.0
	await get_tree().create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	if out_dir != "":
		get_viewport().get_texture().get_image().save_png(out_dir.path_join("anim_kayip.png"))
	print("KAYIPTEST  yere_dusen=%d" % downs)
	get_tree().quit()
