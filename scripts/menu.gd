extends Control
## Açılış ekranı: eğitim, kayıtlı oyuna devam, senaryo, zorluk ve taraf seçimi.
## Oyuncu her senaryoda iki tarafı da oynayabilir.

var list: VBoxContainer
var detail: VBoxContainer
var world: WorldMap
var logo: Logo
var scn_btns: Array = []


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
	if args.has("--autotest") or args.has("--inputtest") or args.has("--gallery") or args.has("--animtest") or args.has("--mechtest") or args.has("--tuttest") or args.has("--duel") or args.has("--mapshot") or args.has("--maptest") or args.has("--uishot"):
		_start.call_deferred()
		return
	if Scenarios.tutorial:
		_start.call_deferred()
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var th := Theme.new()
	th.default_font_size = 20
	theme = th
	world = WorldMap.new()
	add_child(world)
	logo = Logo.new()
	logo.position = Vector2(18, 10)
	logo.size = Vector2(520, 118)
	add_child(logo)
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_top = 136
	hb.offset_left = 18
	hb.offset_right = -18
	hb.offset_bottom = -14
	hb.add_theme_constant_override("separation", 18)
	add_child(hb)
	var left := _panel()
	left.custom_minimum_size = Vector2(400, 0)
	hb.add_child(left)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	list = VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var info := Game.saved_info()
	if not info.is_empty():
		var sc_name: String = Scenarios.LIST[int(info.scn)].name
		_list_btn("Devam Et — %s, %02d:%02d" % [sc_name, int(info.time) / 60, int(info.time) % 60], Color(0.6, 1.0, 0.65), _continue)
	_list_btn("Eğitim — oynamayı adım adım öğren", Color(1.0, 0.86, 0.45), _tutorial)
	_list_btn("Ayarlar — ses, grafik ve performans", Color(0.7, 0.85, 1.0), _settings)
	for i in Scenarios.LIST.size():
		var scn: Dictionary = Scenarios.LIST[i]
		var b := _list_btn(scn.name + ("   (kilitli)" if scn.get("locked", false) else ""), Color(0.9, 0.92, 0.95), _show.bind(i))
		scn_btns.append(b)
	var sc2 := ScrollContainer.new()
	sc2.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(sc2)
	detail = VBoxContainer.new()
	detail.add_theme_constant_override("separation", 10)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc2.add_child(detail)
	_show(Scenarios.chosen if not Scenarios.LIST[Scenarios.chosen].get("locked", false) else 0)
	for a in args:
		if a.begins_with("--menushot="):
			_menushot.call_deferred(a.trim_prefix("--menushot="))


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.02, 0.05, 0.07, 0.72)
	sb.border_color = Color(1, 1, 1, 0.12)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	return p


func _list_btn(text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(372, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", col)
	b.pressed.connect(cb)
	list.add_child(b)
	return b


func _menushot(path: String) -> void:
	# Geliştirme aracı: menünün ekran görüntüsünü alıp çıkar.
	for i in 40:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()


## Haritanın üstünde okunur yazı: koyu kontur.
func _outlined(text: String, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	return l


## Ayrıntı alanında yarı saydam bir kutu açar ve içindeki dikey düzeni döndürür.
func _box() -> VBoxContainer:
	var p := _panel()
	detail.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	return v


func _clear_detail() -> void:
	for c in detail.get_children():
		detail.remove_child(c)
		c.queue_free()


func _show(i: int) -> void:
	_clear_detail()
	var scn: Dictionary = Scenarios.LIST[i]
	world.show_scenario(i)
	var geo: Dictionary = scn.get("geo", {})
	logo.accent = geo.get("col", Color(0.95, 0.55, 0.15))
	for k in scn_btns.size():
		scn_btns[k].modulate = Color(1, 1, 1) if k == i else Color(0.8, 0.8, 0.8)
	detail.add_child(_outlined(scn.name, 32, geo.get("col", Color.WHITE).lerp(Color.WHITE, 0.4)))
	var desc := _outlined(scn.desc, 17, Color(0.92, 0.94, 0.96))
	desc.custom_minimum_size = Vector2(440, 110)
	desc.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	detail.add_child(desc)
	if scn.get("locked", false):
		detail.add_child(_outlined("Bu senaryo deniz modu eklendiğinde açılacak.", 18, Color(1.0, 0.8, 0.4)))
		return
	var box := _box()
	# harita önizlemesi; yanında düzen ve zorluk
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	var pv := MapPreview.new()
	pv.setup(scn)
	row.add_child(pv)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 6)
	row.add_child(col)
	var map_lbl := Label.new()
	map_lbl.text = "Harita: %s" % Scenarios.MAPS[scn.map].name
	map_lbl.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
	map_lbl.add_theme_font_size_override("font_size", 16)
	col.add_child(map_lbl)
	var mlbl := Label.new()
	mlbl.text = "Düzen"
	mlbl.add_theme_font_size_override("font_size", 16)
	col.add_child(mlbl)
	var ml := HFlowContainer.new()
	ml.add_theme_constant_override("h_separation", 6)
	ml.add_theme_constant_override("v_separation", 6)
	col.add_child(ml)
	for k in Defs.MODES.size():
		var mb := Button.new()
		mb.text = Defs.MODES[k].name
		mb.toggle_mode = true
		mb.button_pressed = k == Scenarios.mode
		mb.custom_minimum_size = Vector2(0, 44)
		mb.focus_mode = Control.FOCUS_NONE
		mb.add_theme_font_size_override("font_size", 16)
		mb.tooltip_text = Defs.MODES[k].desc
		mb.pressed.connect(func():
			Scenarios.mode = k
			_show(i))
		ml.add_child(mb)
	var mdesc := Label.new()
	mdesc.text = Defs.MODES[Scenarios.mode].desc
	mdesc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mdesc.add_theme_font_size_override("font_size", 14)
	mdesc.add_theme_color_override("font_color", Color(0.75, 0.8, 0.85))
	col.add_child(mdesc)
	var dlbl := Label.new()
	dlbl.text = "Zorluk"
	dlbl.add_theme_font_size_override("font_size", 16)
	col.add_child(dlbl)
	var dl := HBoxContainer.new()
	dl.add_theme_constant_override("separation", 6)
	col.add_child(dl)
	for k in Defs.DIFFS.size():
		var db := Button.new()
		db.text = Defs.DIFFS[k].name
		db.toggle_mode = true
		db.button_pressed = k == Scenarios.difficulty
		db.custom_minimum_size = Vector2(96, 44)
		db.focus_mode = Control.FOCUS_NONE
		db.add_theme_font_size_override("font_size", 16)
		db.pressed.connect(func():
			Scenarios.difficulty = k
			_show(i))
		dl.add_child(db)
	var pick := Label.new()
	pick.text = "Tarafını seç:"
	box.add_child(pick)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	box.add_child(hb)
	var codes: Array = [scn.a, scn.b]
	for side in 2:
		var c: Dictionary = Scenarios.COUNTRIES[codes[side]]
		var doc: Dictionary = Scenarios.DOCTRINES[c.doctrine]
		var b := Button.new()
		b.text = "%s — %s\n%s" % [c.name, doc.name, doc.desc]
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(250, 128)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 15)
		var sbn := StyleBoxFlat.new()
		sbn.bg_color = Color(0.1, 0.13, 0.15, 0.9)
		sbn.border_color = [Color(0.35, 0.6, 1.0), Color(1.0, 0.35, 0.3)][side]
		sbn.border_width_left = 4
		sbn.set_corner_radius_all(5)
		sbn.content_margin_left = 84
		sbn.content_margin_right = 10
		b.add_theme_stylebox_override("normal", sbn)
		var sbh := sbn.duplicate()
		sbh.bg_color = Color(0.16, 0.2, 0.22, 0.95)
		b.add_theme_stylebox_override("hover", sbh)
		b.add_theme_stylebox_override("pressed", sbh)
		var cc: String = codes[side]
		b.draw.connect(func(): WorldMap.draw_flag(b, Rect2(14, b.size.y * 0.5 - 20, 60, 40), cc))
		b.pressed.connect(_pick.bind(i, side))
		hb.add_child(b)


## Ayarlar: her biri açılıp kapanır ve hemen kaydedilir. Gölge ve texture bir sonraki maçta geçerli olur.
func _settings() -> void:
	_clear_detail()
	world.show_scenario(-1)
	var holder := detail
	detail = _box()
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
	detail = holder


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
	if world == null:
		get_tree().change_scene_to_file("res://scenes/main.tscn")
		return
	# Büyük harita kurulurken logolu bekleme ekranı.
	var cover := ColorRect.new()
	cover.color = Color(0.02, 0.04, 0.05, 0.92)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cover)
	var lg := Logo.new()
	lg.accent = logo.accent
	lg.size = Vector2(520, 118)
	lg.position = size * 0.5 - Vector2(260, 100)
	cover.add_child(lg)
	var l := Label.new()
	l.text = "Harita hazırlanıyor..."
	l.position = size * 0.5 + Vector2(-110, 40)
	l.add_theme_font_size_override("font_size", 22)
	cover.add_child(l)
	for i in 3:
		await RenderingServer.frame_post_draw
	get_tree().change_scene_to_file("res://scenes/main.tscn")
