class_name Hud
extends CanvasLayer
## Arayüz: üst bilgi çubuğu, küçük harita, grup düğmeleri, alt bağlam paneli, can çubukları.

const MM_W := 220.0
const MM_H := MM_W * Defs.MAP_H / Defs.MAP_W

var root: Control
var overlay: Control
var top: PanelContainer
var lbl_top: Label
var minimap: Control
var groups: GridContainer
var bottom: PanelContainer
var title: Label
var actions: HBoxContainer
var toast_lbl: Label
var end_panel: ColorRect
var refreshers: Array = []
var blockers: Array = []
var _t := 0.0
var _toast_t := 0.0
var _rebuild_pending := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
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

	minimap = Control.new()
	minimap.position = Vector2(8, 48)
	minimap.size = Vector2(MM_W, MM_H)
	minimap.draw.connect(_draw_minimap)
	minimap.gui_input.connect(_minimap_input)
	root.add_child(minimap)

	groups = GridContainer.new()
	groups.columns = 2
	groups.position = Vector2(8, 56 + MM_H)
	root.add_child(groups)
	for g in [["Kara", "kara"], ["Hava Sav.", "hs"], ["Hava", "hava"], ["Hepsi", ""]]:
		var b := Button.new()
		b.text = g[0]
		b.custom_minimum_size = Vector2(108, 52)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_group.bind(g[1]))
		groups.add_child(b)

	bottom = PanelContainer.new()
	bottom.anchor_top = 1.0
	bottom.anchor_bottom = 1.0
	bottom.anchor_right = 1.0
	bottom.offset_top = -140.0
	root.add_child(bottom)
	var mc := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		mc.add_theme_constant_override("margin_" + side, 8)
	bottom.add_child(mc)
	var vb := VBoxContainer.new()
	mc.add_child(vb)
	title = Label.new()
	title.clip_text = true
	vb.add_child(title)
	actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	vb.add_child(actions)

	toast_lbl = Label.new()
	toast_lbl.anchor_left = 0.5
	toast_lbl.anchor_right = 0.5
	toast_lbl.offset_left = -400.0
	toast_lbl.offset_right = 400.0
	toast_lbl.offset_top = 50.0
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	toast_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_lbl.add_theme_constant_override("outline_size", 6)
	toast_lbl.add_theme_font_size_override("font_size", 22)
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_lbl)

	blockers = [top, minimap, groups, bottom]
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


func _process(dt: float) -> void:
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
		tier_txt = "Kademe 2: %%%d" % int(ts.upgrade_t / Defs.TIER2_TIME * 100.0)
	var pw := "Enerji %d/%d" % [ts.power_used, ts.power_prod]
	if ts.power_used > ts.power_prod:
		pw += " (YETERSİZ)"
	lbl_top.text = "İkmal %d (+%d/sn)     %s     Birlik %d/%d     %s     %02d:%02d" % [
		int(ts.supply), int(ts.income), pw, ts.pop, Defs.POP_CAP, tier_txt,
		int(g.time) / 60, int(g.time) % 60]
	minimap.queue_redraw()
	for r in refreshers:
		r.call()


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
	if g.placing != "":
		bottom.visible = true
		title.text = "%s yerleştiriliyor" % Defs.BUILDINGS[g.placing].name
		_btn("İptal", g.cancel_placing)
		return
	if g.sel_pad != null:
		bottom.visible = true
		title.text = "Boş yuva: ne kuralım?"
		for id in Defs.PAD_BUILDINGS:
			var bd: Dictionary = Defs.BUILDINGS[id]
			var b := _btn("%s\n%d" % [bd.name, bd.cost], _build.bind(id))
			refreshers.append(_refresh_cost.bind(b, int(bd.cost), int(bd.get("tier", 1))))
		_btn("Kapat", g.clear_selection)
		_run_refreshers()
		return
	var units := g.selected_units()
	if not units.is_empty():
		bottom.visible = true
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
		bottom.visible = true
		refreshers.append(_refresh_building_title.bind(b))
		if b.built:
			for id in b.d.get("produces", []):
				var ud: Dictionary = Defs.UNITS[id]
				var btn := _btn("%s\n%d" % [ud.name, ud.cost], _queue.bind(b, id))
				refreshers.append(_refresh_cost.bind(btn, int(ud.cost), int(ud.get("tier", 1))))
			if b.def_id == "hq":
				var ts = g.teams[Defs.PLAYER]
				if ts.tier < 2:
					var up := _btn("Kademe 2\n%d" % Defs.TIER2_COST, _upgrade)
					refreshers.append(_refresh_upgrade.bind(up))
				var hd: Dictionary = Defs.BUILDINGS["hisar"]
				var hb := _btn("Hisar Kur\n%d" % hd.cost, g.begin_placing.bind("hisar"))
				refreshers.append(_refresh_cost.bind(hb, int(hd.cost), 2))
		_btn("Kapat", g.clear_selection)
		_run_refreshers()
		return
	bottom.visible = false


func _run_refreshers() -> void:
	for r in refreshers:
		r.call()


func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(138, 78)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	actions.add_child(b)
	return b


func _refresh_cost(b: Button, cost: int, tier: int) -> void:
	var ts = Game.I.teams[Defs.PLAYER]
	b.disabled = ts.tier < tier or ts.supply < cost
	b.tooltip_text = "Kademe 2 gerekli" if ts.tier < tier else ""


func _refresh_upgrade(b: Button) -> void:
	var ts = Game.I.teams[Defs.PLAYER]
	b.visible = ts.tier < 2
	b.disabled = ts.upgrading or ts.supply < Defs.TIER2_COST
	if ts.upgrading:
		b.text = "Kademe 2\n%%%d" % int(ts.upgrade_t / Defs.TIER2_TIME * 100.0)


func _refresh_building_title(b: Building) -> void:
	if not is_instance_valid(b) or not b.alive:
		return
	var s: String = b.d.name
	if not b.built:
		s += "  (inşa ediliyor %%%d)" % int(b.build_t / b.build_time * 100.0)
	elif not b.queue.is_empty():
		s += "  |  Üretim: %s %%%d  |  Kuyruk: %d" % [
			Defs.UNITS[b.queue[0]].name, int(b.prod_fraction() * 100.0), b.queue.size()]
	if b.built and int(b.d.get("power", 0)) < 0 and not b.powered():
		s += "  |  ENERJİ YETERSİZ: Santral kur"
	title.text = s


func _build(id: String) -> void:
	var g := Game.I
	if g.sel_pad != null:
		g.build_on_pad(g.sel_pad, id)


func _queue(b: Building, id: String) -> void:
	if is_instance_valid(b):
		Game.I.queue_unit(b, id)
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
		if e is AirUnit and e.team == Defs.PLAYER and e.has_weapon():
			var txt := "Füze %d" % e.ammo if e.state == "patrol" else "Silahlanıyor"
			overlay.draw_string(font, p + Vector2(-w * 0.5, -6), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	for pt in g.points:
		var wp2: Vector3 = pt.position + Vector3(0, 5.2, 0)
		if cam.is_position_behind(wp2):
			continue
		var p2 := cam.unproject_position(wp2)
		var label := "+%d/sn" % int(pt.income)
		overlay.draw_string(font, p2 + Vector2(-24, 0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.9))
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


func _draw_minimap() -> void:
	var g := Game.I
	minimap.draw_rect(Rect2(Vector2.ZERO, minimap.size), Color(0.1, 0.14, 0.1, 0.92))
	for pt in g.points:
		var c := Color(0.85, 0.85, 0.85)
		if pt.owner_team != Defs.NEUTRAL:
			c = Defs.TEAM_COLORS[pt.owner_team]
		var mp := _mm(pt.position)
		minimap.draw_rect(Rect2(mp - Vector2(4, 4), Vector2(8, 8)), c, false, 2.0)
	for e in g.entities:
		if not e.alive or not e.seen:
			continue
		var s := 6.0 if e.is_building else 3.5
		minimap.draw_rect(Rect2(_mm(e.global_position) - Vector2(s, s) * 0.5, Vector2(s, s)), Defs.TEAM_COLORS[e.team])
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


func _restart() -> void:
	get_tree().reload_current_scene()
