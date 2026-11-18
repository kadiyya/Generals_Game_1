extends Node
## Geliştirme aracı: giriş ekranında parmakla kaydırmayı, müziği ve seslerin üretimini dener.
## Kullanım (gerçek pencere gerekir): godot --path . -- --menutest

var fails := 0


func _check(name: String, ok: bool) -> void:
	print(("GECTI  " if ok else "KALDI  ") + name)
	if not ok:
		fails += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ev(e: InputEvent) -> void:
	Input.parse_input_event(e)


func run(menu) -> void:
	await _frames(10)
	var sc: ScrollContainer = menu.detail.get_parent()
	# Ayrıntı alanını uzat: kayacak kadar içerik olsun
	for i in 30:
		var b := Button.new()
		b.text = "deneme %d" % i
		b.custom_minimum_size = Vector2(300, 50)
		b.pressed.connect(func(): menu.set_meta("pressed", true))
		menu.detail.add_child(b)
	await _frames(5)
	var xf := get_viewport().get_final_transform()
	var r := sc.get_global_rect()
	var p := Vector2(r.position.x + 150, r.position.y + r.size.y * 0.7)
	var t := InputEventScreenTouch.new()
	t.position = xf * p
	t.pressed = true
	_ev(t)
	await _frames(2)
	var y0 := sc.scroll_vertical
	for i in 10:
		var d := InputEventScreenDrag.new()
		d.position = xf * (p - Vector2(0, (i + 1) * 20.0))
		d.relative = xf.basis_xform(Vector2(0, -20.0))
		_ev(d)
		await _frames(1)
	var t2 := InputEventScreenTouch.new()
	t2.position = xf * (p - Vector2(0, 200))
	t2.pressed = false
	_ev(t2)
	await _frames(20)
	_check("dugmenin ustunden parmakla asagi kaydirilir", sc.scroll_vertical > y0 + 100)
	_check("kaydirirken alttaki dugmeye basilmaz", not menu.has_meta("pressed"))
	# kısa dokunuş hâlâ basar
	var bt: Button = menu.detail.get_child(menu.detail.get_child_count() - 1)
	sc.ensure_control_visible(bt)
	await _frames(3)
	var c := bt.get_global_rect().get_center()
	var a := InputEventScreenTouch.new()
	a.position = xf * c
	a.pressed = true
	_ev(a)
	await _frames(2)
	var a2 := InputEventScreenTouch.new()
	a2.position = xf * c
	a2.pressed = false
	_ev(a2)
	await _frames(3)
	_check("kisa dokunus dugmeye basar", menu.has_meta("pressed"))
	# sesler hatasız üretilir
	var ok := true
	for n in Sfx.LEVEL:
		var w: AudioStreamWAV = Sfx.stream(n)
		if w == null or w.data.size() < 200:
			ok = false
			print("   ses bos: ", n)
	_check("butun sesler uretilir", ok)
	# müzik: arka planda üretilip çalar
	var t0 := Time.get_ticks_msec()
	while not menu.sfx.music.playing and Time.get_ticks_msec() - t0 < 60000:
		await _frames(5)
	print("   muzik hazir: %d ms" % (Time.get_ticks_msec() - t0))
	_check("giris ekraninda muzik calar", menu.sfx.music.playing and menu.sfx.theme == "menu")
	print("MENUTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
