class_name Controls
extends Node
## Dokunmatik kontroller (fare ile de çalışır):
##   dokun = seç / emir ver, çift dokun = aynı tipin hepsini seç,
##   sürükle = kamerayı kaydır, basılı tutup sürükle = kutu seçimi,
##   iki parmak = yakınlaştır.

const TAP_SLOP := 14.0
const HOLD_TIME := 0.35
const DOUBLE_TIME := 0.35

var touches := {}
var mode := "none"   # none / tap / pan / box / pinch / wait
var start_pos := Vector2.ZERO
var start_time := 0.0
var box_end := Vector2.ZERO
var pinch_d := 0.0
var pinch_c := Vector2.ZERO
var last_tap_time := -10.0
var last_tap_pos := Vector2.ZERO


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func box_rect() -> Rect2:
	return Rect2(start_pos, box_end - start_pos).abs()


func _process(_dt: float) -> void:
	if mode == "tap" and _now() - start_time > HOLD_TIME:
		mode = "box"
		box_end = start_pos


func _unhandled_input(ev: InputEvent) -> void:
	var g := Game.I
	if g.over:
		return
	if ev is InputEventScreenTouch:
		if ev.pressed:
			if g.hud.is_over_ui(ev.position):
				return
			touches[ev.index] = ev.position
			if touches.size() == 1:
				mode = "tap"
				start_pos = ev.position
				start_time = _now()
			elif touches.size() == 2:
				mode = "pinch"
				_pinch_reset()
		elif touches.has(ev.index):
			touches.erase(ev.index)
			if mode == "tap":
				_tap(ev.position)
			elif mode == "box":
				_box(ev.position)
			mode = "none" if touches.is_empty() else "wait"
	elif ev is InputEventScreenDrag:
		if not touches.has(ev.index):
			return
		touches[ev.index] = ev.position
		match mode:
			"tap":
				if ev.position.distance_to(start_pos) > TAP_SLOP:
					mode = "pan"
			"pan":
				g.cam.pan_screen(ev.position - ev.relative, ev.position)
			"box":
				box_end = ev.position
			"pinch":
				_pinch()
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			g.cam.zoom(0.9)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			g.cam.zoom(1.1)


func _pinch_reset() -> void:
	var p: Array = touches.values()
	pinch_d = maxf(10.0, p[0].distance_to(p[1]))
	pinch_c = (p[0] + p[1]) * 0.5


func _pinch() -> void:
	if touches.size() < 2:
		return
	var p: Array = touches.values()
	var dd := maxf(10.0, p[0].distance_to(p[1]))
	var c: Vector2 = (p[0] + p[1]) * 0.5
	var g := Game.I
	g.cam.zoom(pinch_d / dd)
	g.cam.pan_screen(pinch_c, c)
	pinch_d = dd
	pinch_c = c


func _tap(pos: Vector2) -> void:
	var g := Game.I
	var world := g.cam.ground_at(pos)
	var now := _now()
	var dbl := now - last_tap_time < DOUBLE_TIME and pos.distance_to(last_tap_pos) < 40.0
	last_tap_time = now
	last_tap_pos = pos
	if g.placing != "":
		g.try_place(world)
		return
	if g.targeting != null:
		g.try_launch(world)
		return
	if g.ab_targeting:
		g.try_ability(world)
		return
	var e = g.pick_entity(pos)
	if e != null and e.team == Defs.PLAYER:
		if dbl and not e.is_building:
			g.select_same_on_screen(e)
		else:
			g.select([e])
		return
	var units := g.selected_units()
	if not units.is_empty():
		var house = g.pick_house(world) if e == null else null
		if house != null:
			g.order_enter(units, house)
			g.fx_marker(house.position, Color(0.3, 1.0, 0.4))
			return
		if e != null:
			g.order_attack(units, e)
		else:
			g.order_move(units, world, true)
		return
	g.clear_selection()


func _box(pos: Vector2) -> void:
	box_end = pos
	var g := Game.I
	var r := box_rect()
	if r.size.length() < 20.0:
		return
	var list: Array = []
	for e in g.entities:
		if e.team == Defs.PLAYER and not e.is_building and e.alive:
			if g.cam.camera.is_position_behind(e.global_position):
				continue
			if r.has_point(g.cam.camera.unproject_position(e.global_position)):
				list.append(e)
	if not list.is_empty():
		g.select(list)
