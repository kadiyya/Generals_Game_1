extends Node
## Geliştirme aracı: dokunmatik girdileri taklit edip kontrollerin çalıştığını doğrular.
## Kullanım (gerçek pencere gerekir; nehirli ve dağlı harita için 3. senaryo): godot --path . -- --inputtest --scn=2

var fails := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _check(name: String, ok: bool) -> void:
	print(("GECTI  " if ok else "KALDI  ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _touch(pos: Vector2, pressed: bool, index := 0) -> void:
	var ev := InputEventScreenTouch.new()
	ev.index = index
	ev.position = get_viewport().get_final_transform() * pos
	ev.pressed = pressed
	Input.parse_input_event(ev)


func _drag(from: Vector2, to: Vector2, index := 0) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = index
	var xf := get_viewport().get_final_transform()
	ev.position = xf * to
	ev.relative = xf.basis_xform(to - from)
	Input.parse_input_event(ev)


func _tap(pos: Vector2) -> void:
	_touch(pos, true)
	await _frames(2)
	_touch(pos, false)
	await _frames(2)


func _count(id: String) -> int:
	var n := 0
	for e in Game.I.entities:
		if e.team == Defs.PLAYER and e.is_building and e.kind == id:
			n += 1
	return n


func _screen(p: Vector3) -> Vector2:
	return Game.I.cam.camera.unproject_position(p)


func _run() -> void:
	var g := Game.I
	await _frames(5)
	g.teams[0].money = 5000.0
	g.cam.focus = g.teams[0].hq.position
	await _frames(2)

	# 1) İnşa düğmesi -> inşa menüsü
	await _tap(g.hud.side.get_child(1).get_global_rect().get_center())
	await _frames(2)
	_check("Insa dugmesi menuyu acar", g.menu == "build" and g.hud.bottom.visible)

	# 2) Kışla düğmesi -> yerleştirme modu -> haritaya dokun -> bina kurulur
	await _tap(g.hud.actions.get_child(2).get_global_rect().get_center())
	await _frames(2)
	_check("bina dugmesi yerlestirme modunu acar", g.placing == "kisla")
	await _tap(_screen(g.teams[0].hq.position + Vector3(16, 0, -8)))
	await _frames(2)
	_check("haritaya dokununca Kisla kurulur", g.nearest_building(0, "kisla", Vector3.ZERO) == null and g.placing == "" and _count("kisla") == 1)

	# 2b) dağın üstüne bina kurulamaz
	_check("dagin ustune bina kurulamaz", not g.terrain.is_land(Vector3(-45, 0, -50)) and not g.can_place(0, "kisla", g.teams[0].hq.position + Vector3(3, 0, 0)))

	# 2c) hız düğmesi oyunu duraklatır
	await _tap(g.hud.speed_btn.get_global_rect().get_center())
	await _tap(g.hud.speed_btn.get_global_rect().get_center())
	_check("hiz dugmesi oyunu duraklatir", Engine.time_scale == 0.0)
	await _tap(g.hud.speed_btn.get_global_rect().get_center())
	_check("hiz dugmesi normale doner", Engine.time_scale == 1.0)

	# 3) birime dokun -> seçilir
	g.clear_selection()
	var m: Unit = null
	for e in g.entities:
		if e.team == Defs.PLAYER and e.cls == "inf":
			m = e
	await _tap(_screen(m.aim_pos()))
	_check("birime dokununca secilir", g.selection.size() == 1 and g.selection[0] == m)

	# 4) yere dokun -> hareket emri
	var goal := m.position + Vector3(6, 0, 5)
	await _tap(_screen(goal))
	_check("yere dokununca birim yola cikar", m.order == "amove" and Entity.flat(m.dest, goal) < 1.0)

	# 5) çift dokun -> aynı tipin hepsi
	await _tap(_screen(m.aim_pos()))
	await _tap(_screen(m.aim_pos()))
	_check("cift dokununca ayni tipin hepsi secilir", g.selection.size() == 2)

	# 6) sürükle -> kamera kayar, seçim bozulmaz
	var f0 := g.cam.focus
	var a := Vector2(700, 300)
	_touch(a, true)
	await _frames(1)
	for i in 8:
		_drag(a + Vector2(i * 15, 0), a + Vector2((i + 1) * 15, 0))
		await _frames(1)
	_touch(a + Vector2(120, 0), false)
	await _frames(2)
	_check("surukleyince kamera kayar", g.cam.focus.distance_to(f0) > 3.0 and g.selection.size() == 2)

	# 7) basılı tut + sürükle -> kutu seçimi
	g.clear_selection()
	g.cam.focus = m.position
	await _frames(2)
	var c := _screen(m.position)
	_touch(c - Vector2(200, 150), true)
	await get_tree().create_timer(0.5, true, false, true).timeout
	_drag(c - Vector2(200, 150), c + Vector2(200, 150))
	await _frames(2)
	_check("basili tutunca kutu modu acilir", g.controls.mode == "box")
	_touch(c + Vector2(200, 150), false)
	await _frames(2)
	_check("kutu secimi birimleri secer", g.selection.size() >= 1)

	# 8) iki parmak -> yakınlaştırma
	var d0 := g.cam.dist
	_touch(Vector2(500, 300), true, 0)
	_touch(Vector2(700, 300), true, 1)
	await _frames(1)
	_drag(Vector2(700, 300), Vector2(900, 300), 1)
	await _frames(1)
	_touch(Vector2(500, 300), false, 0)
	_touch(Vector2(900, 300), false, 1)
	await _frames(2)
	_check("iki parmakla acinca yakinlasir", g.cam.dist < d0 - 1.0)

	# 9) grup düğmesi
	g.clear_selection()
	await _tap(g.hud.side.get_child(0).get_child(3).get_global_rect().get_center())
	_check("Hepsi dugmesi butun birimleri secer", g.selected_units().size() == 2)

	# 9b) yol bulma: nehrin karşısına giden birim köprüden geçer, suya girmez
	var path := g.terrain.find_path(Vector3(-30, 0, 38), Vector3(30, 0, 38))
	var wet := false
	for wp in path:
		if not g.terrain.is_land(wp):
			wet = true
	_check("yol nehri kopruden gecer", path.size() > 5 and not wet)
	_check("dagin icinden duz gidilemez", not g.terrain.line_clear(Vector3(-60, 0, -50), Vector3(-30, 0, -50)))

	# 9c) doktrin: Pakistan'da (Balistik Füze) Füze Üssü Kademe 2'de açılır, füze ucuzdur
	_check("fuze doktrini fuze ussunu kademe 2'de acar", int(Defs.BUILDINGS[Defs.bid(0, "fuze")].tier) == 2 and g.missile_info(0, 0).cost < Scenarios.country(0).missiles[0].cost)

	# 9d) uçak pist sınırı ve füze hedefleme
	g.teams[0].tier = 3
	g.teams[0].money = 50000.0
	var af := g.spawn_building(Defs.bid(0, "havaalani"), 0, g.teams[0].hq.position + Vector3(0, 0, -22), true)
	var jet := g.unit_of(0, "fighter")
	var queued := 0
	for i in 6:
		if g.queue_unit(af, jet):
			queued += 1
	_check("bir hava alani en cok 4 ucak alir", queued == Defs.PLANES_PER_AIRFIELD)
	var fz := g.spawn_building(Defs.bid(0, "fuze"), 0, g.teams[0].hq.position + Vector3(-14, 0, 14), true)
	for z in [22.0, 30.0]:
		g.spawn_building(Defs.bid(0, "santral"), 0, g.teams[0].hq.position + Vector3(-20, 0, z - 40.0), true)
	g.recalc()
	g.fog.recompute()
	_check("fuze ussunun enerjisi var", fz.powered())
	_check("gorulmeyen hedefe fuze atilamaz", not g.launch_missile(fz, 0, g.teams[1].hq.position))
	_check("gorulen hedefe fuze atilir", g.launch_missile(fz, 0, g.teams[0].hq.position + Vector3(12, 0, 0)) and fz.missile_ready[0] > 0.0)

	# 10) küçük haritaya dokun -> kamera oraya gider
	await _tap(g.hud.minimap.get_global_rect().get_center())
	_check("kucuk haritaya dokununca kamera gider", g.cam.focus.length() < 6.0)

	print("INPUTTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
