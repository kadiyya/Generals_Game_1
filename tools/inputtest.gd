extends Node
## Geliştirme aracı: dokunmatik girdileri taklit edip kontrollerin çalıştığını doğrular.
## Kullanım (gerçek pencere gerekir): godot --path . -- --inputtest

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


func _screen(p: Vector3) -> Vector2:
	return Game.I.cam.camera.unproject_position(p)


func _run() -> void:
	var g := Game.I
	await _frames(5)
	g.teams[0].supply = 5000.0
	g.cam.focus = g.teams[0].hq.position
	await _frames(2)

	# 1) boş yuvaya dokun -> inşa menüsü
	var pad = null
	for p in g.pads:
		if p.team == Defs.PLAYER:
			pad = p
	await _tap(_screen(pad.pos))
	_check("yuvaya dokununca insa menusu acilir", g.sel_pad == pad and g.hud.bottom.visible)

	# 2) arayüz düğmesine dokun (Android yolu: dokunma -> düğme) -> Kışla kurulur, haritaya emir gitmez
	var btn: Button = g.hud.actions.get_child(1)
	await _tap(btn.get_global_rect().get_center())
	_check("dugmeye dokununca Kisla kurulur", pad.building != null and pad.building.def_id == "kisla")

	# 3) birime dokun -> seçilir
	g.clear_selection()
	var m: Unit = null
	for e in g.entities:
		if e.team == Defs.PLAYER and e.def_id == "manga":
			m = e
	await _tap(_screen(m.aim_pos()))
	_check("birime dokununca secilir", g.selection.size() == 1 and g.selection[0] == m)

	# 4) yere dokun -> hareket emri
	var goal := m.position + Vector3(8, 0, 3)
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
	await _tap(g.hud.groups.get_child(3).get_global_rect().get_center())
	_check("Hepsi dugmesi butun birimleri secer", g.selected_units().size() == 2)

	# 10) küçük haritaya dokun -> kamera oraya gider
	await _tap(g.hud.minimap.get_global_rect().get_center())
	_check("kucuk haritaya dokununca kamera gider", g.cam.focus.length() < 6.0)

	print("INPUTTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
