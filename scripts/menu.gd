extends Control
## Açılış ekranı: eğitim, kayıtlı oyuna devam, senaryo, zorluk ve taraf seçimi.
## Oyuncu her senaryoda iki tarafı da oynayabilir.

var list: VBoxContainer
var detail: VBoxContainer


func _ready() -> void:
	Engine.time_scale = 1.0
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--scn="):
			Scenarios.chosen = int(a.trim_prefix("--scn="))
		elif a.begins_with("--side="):
			Scenarios.side = int(a.trim_prefix("--side="))
		elif a.begins_with("--diff="):
			Scenarios.difficulty = int(a.trim_prefix("--diff="))
		elif a.begins_with("--mode="):
			Scenarios.mode = int(a.trim_prefix("--mode="))
	Scenarios.tutorial = args.has("--tutorial")
	if args.has("--load"):
		_continue.call_deferred()
		return
	if args.has("--autotest") or args.has("--inputtest") or args.has("--gallery") or args.has("--animtest") or args.has("--mechtest") or args.has("--tuttest") or args.has("--duel") or args.has("--mapshot") or args.has("--maptest"):
		_start.call_deferred()
		return
	if Scenarios.tutorial:
		_start.call_deferred()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 20
	theme = th
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.11)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var mc := MarginContainer.new()
	mc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 24)
	add_child(mc)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	mc.add_child(vb)
	var title := Label.new()
	title.text = "SENARYO SEÇ"
	title.add_theme_font_size_override("font_size", 34)
	vb.add_child(title)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 24)
	hb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(hb)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(470, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	hb.add_child(sc)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 10)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var info := Game.saved_info()
	if not info.is_empty():
		var cont := Button.new()
		var sc_name: String = Scenarios.LIST[int(info.scn)].name
		cont.text = "Devam Et — %s, %02d:%02d" % [sc_name, int(info.time) / 60, int(info.time) % 60]
		cont.custom_minimum_size = Vector2(450, 64)
		cont.focus_mode = Control.FOCUS_NONE
		cont.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cont.add_theme_color_override("font_color", Color(0.6, 1.0, 0.65))
		cont.pressed.connect(_continue)
		list.add_child(cont)
	var tut := Button.new()
	tut.text = "Eğitim — oynamayı adım adım öğren"
	tut.custom_minimum_size = Vector2(450, 64)
	tut.focus_mode = Control.FOCUS_NONE
	tut.alignment = HORIZONTAL_ALIGNMENT_LEFT
	tut.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
	tut.pressed.connect(_tutorial)
	list.add_child(tut)
	var st := Button.new()
	st.text = "Ayarlar — ses, grafik ve performans"
	st.custom_minimum_size = Vector2(450, 64)
	st.focus_mode = Control.FOCUS_NONE
	st.alignment = HORIZONTAL_ALIGNMENT_LEFT
	st.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	st.pressed.connect(_settings)
	list.add_child(st)
	for i in Scenarios.LIST.size():
		var scn: Dictionary = Scenarios.LIST[i]
		var b := Button.new()
		b.text = scn.name + ("   (kilitli)" if scn.get("locked", false) else "")
		b.custom_minimum_size = Vector2(450, 64)
		b.focus_mode = Control.FOCUS_NONE
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_show.bind(i))
		list.add_child(b)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 14)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(detail)
	_show(Scenarios.chosen if not Scenarios.LIST[Scenarios.chosen].get("locked", false) else 0)
	for a in args:
		if a.begins_with("--menushot="):
			_menushot.call_deferred(a.trim_prefix("--menushot="))


func _menushot(path: String) -> void:
	# Geliştirme aracı: menünün ekran görüntüsünü alıp çıkar.
	for i in 4:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


func _show(i: int) -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var scn: Dictionary = Scenarios.LIST[i]
	var name_lbl := Label.new()
	name_lbl.text = scn.name
	name_lbl.add_theme_font_size_override("font_size", 28)
	detail.add_child(name_lbl)
	var desc := Label.new()
	desc.text = scn.desc
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail.add_child(desc)
	if scn.get("locked", false):
		var l := Label.new()
		l.text = "Bu senaryo deniz modu eklendiğinde açılacak."
		l.add_theme_color_override("font_color", Color(1.0, 0.8, 0.4))
		detail.add_child(l)
		return
	var map_lbl := Label.new()
	map_lbl.text = "Harita: %s" % Scenarios.MAPS[scn.map].name
	map_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	detail.add_child(map_lbl)
	var dl := HBoxContainer.new()
	dl.add_theme_constant_override("separation", 10)
	detail.add_child(dl)
	var dlbl := Label.new()
	dlbl.text = "Zorluk:"
	dl.add_child(dlbl)
	for k in Defs.DIFFS.size():
		var db := Button.new()
		db.text = Defs.DIFFS[k].name
		db.toggle_mode = true
		db.button_pressed = k == Scenarios.difficulty
		db.custom_minimum_size = Vector2(110, 48)
		db.focus_mode = Control.FOCUS_NONE
		db.pressed.connect(func():
			Scenarios.difficulty = k
			_show(i))
		dl.add_child(db)
	var pick := Label.new()
	pick.text = "Tarafını seç:"
	detail.add_child(pick)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	detail.add_child(hb)
	var codes: Array = [scn.a, scn.b]
	for side in 2:
		var c: Dictionary = Scenarios.COUNTRIES[codes[side]]
		var doc: Dictionary = Scenarios.DOCTRINES[c.doctrine]
		var b := Button.new()
		b.text = "%s\n%s\n\n%s" % [c.name, doc.name, doc.desc]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.custom_minimum_size = Vector2(330, 190)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_pick.bind(i, side))
		hb.add_child(b)


## Ayarlar: her biri açılıp kapanır ve hemen kaydedilir. Gölge ve texture bir sonraki maçta geçerli olur.
func _settings() -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()
	var t := Label.new()
	t.text = "Ayarlar"
	t.add_theme_font_size_override("font_size", 28)
	detail.add_child(t)
	var note := Label.new()
	note.text = "Oyun eski bir telefonda takılıyorsa gölgeleri, efektleri ve texture'ları kapat. Gölge ve texture değişikliği bir sonraki maçta geçerli olur."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	detail.add_child(note)
	for k in Settings.KEYS:
		var cb := CheckButton.new()
		cb.text = Settings.KEYS[k][0]
		cb.button_pressed = Settings.get_v(k)
		cb.custom_minimum_size = Vector2(0, 56)
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on: bool): Settings.set_v(k, on))
		detail.add_child(cb)


func _pick(i: int, side: int) -> void:
	Scenarios.chosen = i
	Scenarios.side = side
	Scenarios.tutorial = false
	Scenarios.load_data = {}
	_start()


func _tutorial() -> void:
	Scenarios.chosen = 0
	Scenarios.side = 0
	Scenarios.difficulty = 0
	Scenarios.tutorial = true
	Scenarios.load_data = {}
	_start()


func _continue() -> void:
	var info := Game.saved_info()
	if info.is_empty():
		if OS.get_cmdline_user_args().has("--loadtest"):
			print("LOADTEST BITTI  hata=1  (kayit yok)")
			get_tree().quit(1)
		return
	Scenarios.chosen = int(info.scn)
	Scenarios.side = int(info.side)
	Scenarios.difficulty = int(info.diff)
	Scenarios.mode = int(info.get("mode", 0))
	Scenarios.tutorial = false
	Scenarios.load_data = info
	_start()


func _start() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
