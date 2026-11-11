class_name Hud
extends CanvasLayer
## Arayüz: üst bilgi çubuğu, hız düğmesi, küçük harita, grup düğmeleri, alt bağlam paneli, can çubukları.

const MM_W := 220.0
const MM_H := MM_W * Defs.MAP_H / Defs.MAP_W

var root: Control
var overlay: Control
var top: PanelContainer
var lbl_top: Label
var speed_btn: Button
var minimap: Control
var side: VBoxContainer
var bottom: PanelContainer
var title: Label
var actions: HBoxContainer
var toast_lbl: Label
var end_panel: ColorRect
var refreshers: Array = []
var blockers: Array = []
var _icons := {}
var _t := 0.0
var _toast_t := 0.0
var _rebuild_pending := false
var _last_ms := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_last_ms = Time.get_ticks_msec()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 19
	root.theme = th
	add_child(root)

	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.draw.connect(_draw_overlay)
	root.add_child(overlay)

	top = PanelContainer.new()
	top.anchor_right = 1.0
	top.offset_bottom = 40.0
	root.add_child(top)
	lbl_top = Label.new()
	lbl_top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(lbl_top)

	speed_btn = Button.new()
	speed_btn.anchor_left = 1.0
	speed_btn.anchor_right = 1.0
	speed_btn.offset_left = -208.0
	speed_btn.offset_right = -8.0
	speed_btn.offset_top = 48.0
	speed_btn.offset_bottom = 104.0
	speed_btn.focus_mode = Control.FOCUS_NONE
	speed_btn.pressed.connect(_on_speed)
	root.add_child(speed_btn)
	_update_speed_btn()
	var menu_btn := Button.new()
	menu_btn.text = "Menü"
	menu_btn.anchor_left = 1.0
	menu_btn.anchor_right = 1.0
	menu_btn.offset_left = -208.0
	menu_btn.offset_right = -8.0
	menu_btn.offset_top = 110.0
	menu_btn.offset_bottom = 158.0
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.pressed.connect(_to_menu)
	root.add_child(menu_btn)
	blockers.append(menu_btn)

	minimap = Control.new()
	minimap.position = Vector2(8, 48)
	minimap.size = Vector2(MM_W, MM_H)
	minimap.draw.connect(_draw_minimap)
	minimap.gui_input.connect(_minimap_input)
	root.add_child(minimap)

	side = VBoxContainer.new()
	side.position = Vector2(8, 56 + MM_H)
	root.add_child(side)
	var grid := GridContainer.new()
	grid.columns = 2
	side.add_child(grid)
	for g in [["Kara", "kara"], ["Hava Sav.", "hs"], ["Hava", "hava"], ["Hepsi", ""]]:
		var b := Button.new()
		b.text = g[0]
		b.custom_minimum_size = Vector2(108, 50)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_group.bind(g[1]))
		grid.add_child(b)
	var build := Button.new()
	build.text = "İnşa"
	build.custom_minimum_size = Vector2(220, 56)
	build.focus_mode = Control.FOCUS_NONE
	build.pressed.connect(_on_build)
	side.add_child(build)

	bottom = PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -168.0
	root.add_child(bottom)
	var mc := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + s, 8)
	bottom.add_child(mc)
	var vb := VBoxContainer.new()
	mc.add_child(vb)
	title = Label.new()
	title.clip_text = true
	vb.add_child(title)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_child(sc)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	sc.add_child(actions)

	toast_lbl = Label.new()
	toast_lbl.anchor_left = 0.5
	toast_lbl.anchor_right = 0.5
	toast_lbl.offset_left = -380.0
	toast_lbl.offset_right = 380.0
	toast_lbl.offset_top = 50.0
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	toast_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_lbl.add_theme_constant_override("outline_size", 6)
	toast_lbl.add_theme_font_size_override("font_size", 21)
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_lbl)

	blockers += [top, speed_btn, minimap, side, bottom]
	Game.I.selection_changed.connect(rebuild)
	_rebuild_now()


func is_over_ui(p: Vector2) -> bool:
	if end_panel != null:
		return true
	for c in blockers:
		if c.visible and c.get_global_rect().has_point(p):
			return true
	return false


func toast(text: String, secs := 4.0) -> void:
	if toast_lbl == null:
		return
	toast_lbl.text = text
	_toast_t = secs


func _on_group(cat: String) -> void:
	Game.I.select_category(cat)


func _on_build() -> void:
	var g := Game.I
	if g.placing != "":
		g.cancel_placing()
	g.open_build_menu()


func _on_speed() -> void:
	Game.I.set_speed(Game.I.speed_i + 1)
	_update_speed_btn()


func _update_speed_btn() -> void:
	speed_btn.text = "Hız: %s" % Game.SPEED_NAMES[Game.I.speed_i]


func _process(_dt: float) -> void:
	# Oyun duraklatılmışken de arayüz çalışsın diye gerçek zamanı kullan.
	var now := Time.get_ticks_msec()
	var dt := minf(0.1, (now - _last_ms) / 1000.0)
	_last_ms = now
	overlay.queue_redraw()
	if _toast_t > 0.0:
		_toast_t -= dt
		if _toast_t <= 0.0:
			toast_lbl.text = ""
	_t -= dt
	if _t > 0.0:
		return
	_t = 0.2
	var g := Game.I
	var ts = g.teams[Defs.PLAYER]
	var tier_txt := "Kademe %d" % ts.tier
	if ts.upgrading:
		tier_txt = "Kademe %d: %%%d" % [ts.tier + 1, int(ts.upgrade_t / Defs.TIER_TIME[ts.tier] * 100.0)]
	var pw := "Enerji %d/%d" % [ts.power_used, ts.power_prod]
	if ts.power_used > ts.power_prod:
		pw += " (YETERSİZ)"
	lbl_top.text = "%s    $%d (+$%d/sn)    %s    Birlik %d/%d    Vinç %d    %s    %02d:%02d" % [
		Scenarios.country(Defs.PLAYER).name, int(ts.money), int(ts.income), pw, ts.pop, ts.pop_cap, ts.cranes, tier_txt,
		int(g.time) / 60, int(g.time) % 60]
	minimap.queue_redraw()
	_run_refreshers()


# ---------------------------------------------------------------- simgeler

## Birim ya da binanın 3B modelinden küçük bir resim üretir (bir kez çizilir).
func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var def: Dictionary = {}
	var r := 3.0
	if Defs.UNITS.has(id):
		def = Defs.UNITS[id]
		r = float(def.get("icon_r", float(def.radius) * 1.55))
	elif Defs.BUILDINGS.has(id):
		def = Defs.BUILDINGS[id]
		r = float(def.radius)
	var vp := SubViewport.new()
	vp.size = Vector2i(128, 128)
	vp.own_world_3d = true
	vp.transparent_bg = true
	add_child(vp)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var m: Node3D = Models.crane() if id == "vinc" else Models.build(def, Defs.PLAYER)
	vp.add_child(m)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	vp.add_child(sun)
	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.7
	var c := Camera3D.new()
	c.fov = 30.0
	c.environment = env
	vp.add_child(c)
	var mid := Vector3(0, 0.0 if def.get("air", false) else r * 0.4, 0)
	var dir := Vector3(0.55, 0.6, 0.75)
	if def.get("air", false):
		dir = Vector3(0.35, 1.0, 0.45)     # hava araçları üstten: siluet okunur
	if id == "vinc":
		mid = Vector3(-1.0, 3.0, 0)
	c.look_at_from_position(mid + dir.normalized() * r * 5.2, mid, Vector3.UP)
	_icons[id] = vp.get_texture()
	return _icons[id]


# ---------------------------------------------------------------- alt panel

func rebuild() -> void:
	# Düğme kendi tıklamasının içinde silinmesin diye bir sonraki kareye ertelenir.
	if not _rebuild_pending:
		_rebuild_pending = true
		_rebuild_now.call_deferred()


func _rebuild_now() -> void:
	_rebuild_pending = false
	refreshers.clear()
	for c in actions.get_children():
		actions.remove_child(c)
		c.queue_free()
	var g := Game.I
	bottom.visible = true
	if g.placing != "":
		title.text = "%s yerleştiriliyor: sarı çemberin içinde bir yere dokun" % Defs.BUILDINGS[Defs.bid(0, g.placing)].name
		_btn("İptal", g.cancel_placing)
		return
	if g.targeting != null:
		title.text = "%s: hedef için haritada görebildiğin bir yere dokun" % g.missile_info(0, g.targeting_i).name
		_btn("İptal", g.cancel_targeting)
		return
	var hq_selected: bool = g.selection.size() == 1 and g.selection[0] is Building and g.selection[0].kind == "hq"
	if g.menu == "build" or hq_selected:
		title.text = "İnşa: bir bina seç, sonra haritada yerini göster  (%s)" % Scenarios.doctrine(0).name
		for kind in Defs.BUILD_KINDS:
			var id := Defs.bid(0, kind)
			var bd: Dictionary = Defs.BUILDINGS[id]
			var b := _btn("%s\n$%d" % [bd.name, bd.cost], g.begin_placing.bind(kind), id)
			refreshers.append(_refresh_cost.bind(b, bd.name, int(bd.cost), int(bd.get("tier", 1))))
		var cr := _btn("Vinç", _crane, "vinc")
		refreshers.append(_refresh_crane.bind(cr))
		var up := _btn("Kademe", _upgrade)
		refreshers.append(_refresh_upgrade.bind(up))
		_btn("Kapat", g.clear_selection)
		_run_refreshers()
		return
	var units := g.selected_units()
	if not units.is_empty():
		var counts := {}
		for u in units:
			counts[u.d.name] = counts.get(u.d.name, 0) + 1
		var parts: Array = []
		for k in counts:
			parts.append("%d %s" % [counts[k], k])
		title.text = ", ".join(parts)
		_btn("Dur", _stop)
		_btn("Geri Çekil", _retreat)
		_btn("Seçimi Bırak", g.clear_selection)
		return
	if g.selection.size() == 1 and g.selection[0] is Building:
		var b: Building = g.selection[0]
		refreshers.append(_refresh_building_title.bind(b))
		if b.built:
			for id in b.d.get("produces", []):
				var ud: Dictionary = Defs.UNITS[id]
				var cost := g.unit_cost(0, id)
				var label: String = ud.name
				if int(ud.get("count", 1)) > 1:
					label += " x%d" % int(ud.count)
				var btn := _btn("%s\n$%d" % [label, cost], _queue.bind(b, id), id)
				refreshers.append(_refresh_cost.bind(btn, label, cost, int(ud.get("tier", 1))))
			if b.kind == "teknoloji":
				for r in Scenarios.RESEARCH:
					var rb := _btn("%s\n$%d" % [r.name, r.cost], _research.bind(b, r))
					rb.tooltip_text = r.desc
					refreshers.append(_refresh_research.bind(rb, b, r))
			if b.kind == "fuze":
				var ms: Array = Scenarios.country(0).missiles
				for i in ms.size():
					var mb := _btn(ms[i].name, g.begin_targeting.bind(b, i))
					refreshers.append(_refresh_missile.bind(mb, b, i))
		_btn("Kapat", g.clear_selection)
		_run_refreshers()
		return
	bottom.visible = false


func _run_refreshers() -> void:
	for r in refreshers:
		r.call()


func _btn(text: String, cb: Callable, icon_id := "") -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(126, 112)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", 15)
	if icon_id != "":
		b.icon = icon(icon_id)
		b.expand_icon = true
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.pressed.connect(cb)
	actions.add_child(b)
	return b


func _refresh_cost(b: Button, label: String, cost: int, tier: int) -> void:
	var ts = Game.I.teams[Defs.PLAYER]
	if ts.tier < tier:
		b.text = "%s\nKademe %d" % [label, tier]
		b.disabled = true
	else:
		b.text = "%s\n$%d" % [label, cost]
		b.disabled = ts.money < cost


func _refresh_crane(b: Button) -> void:
	var ts = Game.I.teams[Defs.PLAYER]
	if ts.cranes >= Defs.MAX_CRANES:
		b.text = "Vinç %d/%d\nazami" % [ts.cranes, Defs.MAX_CRANES]
		b.disabled = true
	else:
		b.text = "Vinç %d/%d\n$%d" % [ts.cranes, Defs.MAX_CRANES, Defs.CRANE_COST]
		b.disabled = ts.money < Defs.CRANE_COST


func _refresh_upgrade(b: Button) -> void:
	var g := Game.I
	var ts = g.teams[Defs.PLAYER]
	b.visible = ts.tier < Defs.MAX_TIER
	if not b.visible:
		return
	var why := g.can_upgrade(Defs.PLAYER)
	b.disabled = why != ""
	if ts.upgrading:
		b.text = "Kademe %d\n%%%d" % [ts.tier + 1, int(ts.upgrade_t / Defs.TIER_TIME[ts.tier] * 100.0)]
	elif why == "Teknoloji Merkezi gerekli":
		b.text = "Kademe %d\nTek. Merkezi" % (ts.tier + 1)
	else:
		b.text = "Kademe %d\n$%d" % [ts.tier + 1, Defs.TIER_COST[ts.tier]]


func _refresh_research(btn: Button, b: Building, r: Dictionary) -> void:
	if not is_instance_valid(b):
		return
	var g := Game.I
	var ts = g.teams[Defs.PLAYER]
	if ts.researched.has(r.id):
		btn.text = "%s\ntamam" % r.name
		btn.disabled = true
	elif b.research_id == r.id:
		btn.text = "%s\n%%%d" % [r.name, int(b.research_t / float(r.time) * 100.0)]
		btn.disabled = true
	else:
		btn.text = "%s\n$%d" % [r.name, r.cost]
		btn.disabled = b.research_id != "" or ts.money < float(r.cost) or not g.can_research(Defs.PLAYER, r.id)


func _refresh_missile(btn: Button, b: Building, i: int) -> void:
	if not is_instance_valid(b):
		return
	var g := Game.I
	var ts = g.teams[Defs.PLAYER]
	var m := g.missile_info(Defs.PLAYER, i)
	if ts.tier < int(m.tier):
		btn.text = "%s\nKademe %d" % [m.name, int(m.tier)]
		btn.disabled = true
	elif b.missile_ready[i] > 0.0:
		btn.text = "%s\n%d sn" % [m.name, int(ceil(b.missile_ready[i]))]
		btn.disabled = true
	else:
		btn.text = "%s\n$%d" % [m.name, int(m.cost)]
		btn.disabled = ts.money < float(m.cost)


func _refresh_building_title(b: Building) -> void:
	if not is_instance_valid(b) or not b.alive:
		return
	var s: String = b.d.name
	if not b.built:
		if b.crane_active:
			s += "  (inşa ediliyor %%%d)" % int(b.build_t / b.build_time * 100.0)
		else:
			s += "  (vinç bekliyor)"
	elif not b.queue.is_empty():
		s += "  |  Üretim: %s %%%d  |  Kuyruk: %d" % [
			Defs.UNITS[b.queue[0]].name, int(b.prod_fraction() * 100.0), b.queue.size()]
	elif b.research_id != "":
		s += "  |  Araştırma: %s" % b.research_def().name
	elif b.kind == "teknoloji":
		s += "  |  Araştırma seç. Kademe 3 için gerekli."
	elif b.kind == "fuze":
		s += "  |  Füze seç, sonra görebildiğin bir hedefe dokun. Hava savunma önleyebilir."
	elif b.kind == "havaalani":
		s += "  |  Uçak: %d/%d pist" % [Game.I.plane_count(0), Defs.PLANES_PER_AIRFIELD * Game.I.count_kind(0, "havaalani")]
	elif b.kind == "maden":
		s += "  |  +$%d/sn" % int(b.d.income)
	if b.built and int(b.d.get("power", 0)) < 0 and not b.powered():
		s += "  |  ENERJİ YETERSİZ: Santral kur"
	title.text = s


func _queue(b: Building, id: String) -> void:
	if is_instance_valid(b):
		Game.I.queue_unit(b, id)
		_run_refreshers()


func _research(b: Building, r: Dictionary) -> void:
	if is_instance_valid(b):
		Game.I.start_research(b, r)
		_run_refreshers()


func _crane() -> void:
	Game.I.buy_crane(Defs.PLAYER)
	_run_refreshers()


func _upgrade() -> void:
	Game.I.start_tier_upgrade(Defs.PLAYER)
	_run_refreshers()


func _stop() -> void:
	Game.I.order_stop(Game.I.selected_units())


func _retreat() -> void:
	Game.I.order_retreat(Game.I.selected_units())


# ---------------------------------------------------------------- çizim

func _draw_overlay() -> void:
	var g := Game.I
	var cam := g.cam.camera
	var font := ThemeDB.fallback_font
	for e in g.entities:
		if not e.alive or not e.seen:
			continue
		var is_sel: bool = g.selection.has(e)
		var unbuilt: bool = e.is_building and not e.built
		if e.hp >= e.max_hp and not is_sel and not unbuilt:
			continue
		var wp: Vector3 = e.global_position + Vector3(0, 2.4 if not e.is_building else 4.5, 0)
		if cam.is_position_behind(wp):
			continue
		var p := cam.unproject_position(wp)
		var w := 46.0 if not e.is_building else 80.0
		var f: float = clampf(e.hp / e.max_hp, 0.0, 1.0)
		var col := Color(0.25, 0.9, 0.3)
		if f < 0.35:
			col = Color(0.95, 0.25, 0.2)
		elif f < 0.7:
			col = Color(0.95, 0.8, 0.2)
		overlay.draw_rect(Rect2(p.x - w * 0.5 - 1, p.y - 1, w + 2, 7), Color(0, 0, 0, 0.7))
		overlay.draw_rect(Rect2(p.x - w * 0.5, p.y, w * f, 5), col)
		if e is AirUnit and e.team == Defs.PLAYER and e.d.has("ammo"):
			var txt := "Füze %d" % e.ammo if e.state == "patrol" else "Silahlanıyor"
			overlay.draw_string(font, p + Vector2(-w * 0.5, -6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for pt in g.points:
		var wp2: Vector3 = pt.position + Vector3(0, 5.2, 0)
		if cam.is_position_behind(wp2):
			continue
		var p2 := cam.unproject_position(wp2)
		var label := "+$%d/sn" % int(pt.income)
		var lc := Color(1, 1, 1, 0.95)
		if pt.owner_team != Defs.NEUTRAL:
			lc = Defs.TEAM_COLORS[pt.owner_team].lightened(0.45)
		overlay.draw_string_outline(font, p2 + Vector2(-30, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, 5, Color(0, 0, 0, 0.8))
		overlay.draw_string(font, p2 + Vector2(-30, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, lc)
		if pt.cap_t > 0.0 and pt.cap_team != Defs.NEUTRAL:
			var f2: float = clampf(pt.cap_t / pt.cap_time, 0.0, 1.0)
			overlay.draw_rect(Rect2(p2.x - 41, p2.y + 5, 82, 9), Color(0, 0, 0, 0.7))
			overlay.draw_rect(Rect2(p2.x - 40, p2.y + 6, 80 * f2, 7), Defs.TEAM_COLORS[pt.cap_team])
	if g.controls != null and g.controls.mode == "box":
		var r: Rect2 = g.controls.box_rect()
		overlay.draw_rect(r, Color(0.3, 1.0, 0.4, 0.15))
		overlay.draw_rect(r, Color(0.3, 1.0, 0.4, 0.9), false, 2.0)


func _mm(p: Vector3) -> Vector2:
	return Vector2((p.x / Defs.MAP_W + 0.5) * MM_W, (p.z / Defs.MAP_H + 0.5) * MM_H)


func _mm_rect(r: Array) -> Rect2:
	var a := _mm(Vector3(r[0], 0, r[1]))
	var b := _mm(Vector3(r[2], 0, r[3]))
	return Rect2(a, b - a)


func _draw_minimap() -> void:
	var g := Game.I
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color(0.16, 0.22, 0.14, 0.95))
	var mp_def: Dictionary = Defs.MAP
	for r in mp_def.water:
		minimap.draw_rect(_mm_rect(r), Color(0.14, 0.3, 0.5))
	for r in mp_def.bridges:
		minimap.draw_rect(_mm_rect(r), Color(0.4, 0.4, 0.32))
	for r in mp_def.rock:
		minimap.draw_rect(_mm_rect(r), Color(0.42, 0.39, 0.35))
	for r in mp_def.trees:
		minimap.draw_rect(_mm_rect(r), Color(0.1, 0.3, 0.14))
	for r in mp_def.ruins:
		minimap.draw_rect(_mm_rect(r), Color(0.5, 0.47, 0.44))
	for pt in g.points:
		var c := Color(0.9, 0.9, 0.9)
		if pt.owner_team != Defs.NEUTRAL:
			c = Defs.TEAM_COLORS[pt.owner_team].lightened(0.3)
		var mp := _mm(pt.position)
		minimap.draw_rect(Rect2(mp - Vector2(4, 4), Vector2(8, 8)), c, false, 2.0)
	for e in g.entities:
		if not e.alive or not e.seen:
			continue
		var s := 6.0 if e.is_building else 3.5
		minimap.draw_rect(Rect2(_mm(e.global_position) - Vector2(s, s) * 0.5, Vector2(s, s)), Defs.TEAM_COLORS[e.team].lightened(0.3))
	var vr := get_viewport().get_visible_rect().size
	var a := _mm(g.cam.ground_at(Vector2(0, 0)))
	var b := _mm(g.cam.ground_at(Vector2(vr.x, 0)))
	var c2 := _mm(g.cam.ground_at(vr))
	var d := _mm(g.cam.ground_at(Vector2(0, vr.y)))
	var wc := Color(1, 1, 1, 0.8)
	var clip := Rect2(Vector2.ZERO, minimap.size)
	for seg in [[a, b], [b, c2], [c2, d], [d, a]]:
		var p0: Vector2 = seg[0].clamp(clip.position, clip.end)
		var p1: Vector2 = seg[1].clamp(clip.position, clip.end)
		minimap.draw_line(p0, p1, wc, 1.5)
	minimap.draw_rect(clip, Color(1, 1, 1, 0.5), false, 1.5)


func _minimap_input(ev: InputEvent) -> void:
	var pos := Vector2.INF
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
	elif ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		pos = ev.position
	elif ev is InputEventScreenTouch and ev.pressed:
		pos = ev.position
	elif ev is InputEventScreenDrag:
		pos = ev.position
	if pos == Vector2.INF:
		return
	Game.I.cam.focus = Vector3((pos.x / MM_W - 0.5) * Defs.MAP_W, 0, (pos.y / MM_H - 0.5) * Defs.MAP_H)
	minimap.accept_event()


# ---------------------------------------------------------------- bitiş

func show_end(won: bool) -> void:
	Engine.time_scale = 1.0
	end_panel = ColorRect.new()
	end_panel.color = Color(0, 0, 0, 0.65)
	end_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(end_panel)
	var vb := VBoxContainer.new()
	vb.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	vb.grow_vertical = Control.GROW_DIRECTION_BOTH
	vb.add_theme_constant_override("separation", 24)
	end_panel.add_child(vb)
	var l := Label.new()
	l.text = "ZAFER" if won else "YENİLGİ"
	l.add_theme_font_size_override("font_size", 72)
	l.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5) if won else Color(1.0, 0.4, 0.35))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l)
	var l2 := Label.new()
	l2.text = "Düşman karargâhı yıkıldı." if won else "Karargâhın yıkıldı."
	l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(l2)
	var b := Button.new()
	b.text = "Yeniden Oyna"
	b.custom_minimum_size = Vector2(260, 80)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_restart)
	vb.add_child(b)
	var mb := Button.new()
	mb.text = "Senaryo Seç"
	mb.custom_minimum_size = Vector2(260, 80)
	mb.focus_mode = Control.FOCUS_NONE
	mb.pressed.connect(_to_menu)
	vb.add_child(mb)


func _restart() -> void:
	get_tree().reload_current_scene()


func _to_menu() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
