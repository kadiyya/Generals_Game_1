class_name WorldMap
extends Control
## Menünün arka planı: taktik dünya haritası. Kıtalar kaba çokgenlerle (boylam, enlem) çizilir; üstünde ızgara,
## tarama çizgileri, dönen radar ışını ve her senaryonun yanıp sönen işareti vardır. Senaryo seçilince harita o
## bölgeye kayar ve yaklaşır, renk teması değişir; iki tarafın birlik simgeleri ve cephe/saldırı okları görünür.

# Kaba kıta çizgileri: [boylam, enlem]
const LANDS := [
	[[-168, 66], [-156, 71], [-128, 70], [-100, 68], [-95, 72], [-85, 70], [-80, 64], [-78, 58], [-92, 57], [-90, 52], [-80, 52],
		[-77, 60], [-70, 62], [-64, 60], [-56, 52], [-60, 47], [-66, 44], [-70, 42], [-74, 40], [-76, 35], [-81, 31], [-80, 26],
		[-82, 25], [-83, 29], [-90, 30], [-95, 29], [-97, 26], [-97, 21], [-92, 18], [-88, 21], [-87, 16], [-83, 15], [-83, 10],
		[-79, 9], [-77, 8], [-80, 7], [-85, 11], [-88, 13], [-92, 15], [-96, 16], [-105, 20], [-106, 23], [-110, 24], [-112, 29],
		[-115, 32], [-117, 33], [-120, 35], [-124, 40], [-124, 46], [-123, 49], [-130, 54], [-135, 58], [-140, 60], [-148, 61],
		[-152, 59], [-158, 57], [-163, 55], [-165, 60], [-166, 63]],
	[[-73, 78], [-60, 82], [-35, 83], [-20, 80], [-18, 75], [-22, 70], [-30, 68], [-40, 64], [-43, 60], [-48, 61], [-52, 64], [-54, 68], [-58, 74], [-68, 76]],
	[[-80, 9], [-75, 11], [-71, 12], [-63, 10], [-60, 8], [-52, 5], [-50, 0], [-44, -2], [-35, -6], [-35, -10], [-39, -15], [-40, -22],
		[-48, -26], [-53, -34], [-58, -38], [-62, -40], [-65, -45], [-68, -50], [-69, -55], [-74, -52], [-75, -45], [-73, -38], [-71, -30],
		[-70, -18], [-76, -14], [-81, -6], [-80, -2], [-78, 2], [-78, 7]],
	[[-6, 36], [-9, 37], [-9, 43], [-2, 43.5], [-1, 46], [-5, 48], [-1, 49.5], [2, 51], [4, 52], [8, 54], [8, 57], [10, 58], [11, 56],
		[13, 55], [12, 54], [18, 55], [21, 57], [24, 58], [23, 60], [25, 65], [21, 65], [17, 62], [18, 60], [16, 56], [12, 56], [10, 59],
		[5, 58], [5, 62], [10, 64], [14, 68], [18, 70], [25, 71], [30, 70], [40, 68], [44, 66], [43, 68], [55, 68], [60, 69], [68, 69],
		[72, 72], [80, 73], [90, 75], [100, 77], [110, 76], [120, 73], [130, 71], [140, 72], [150, 71], [160, 70], [170, 70], [180, 68],
		[180, 65], [178, 62], [170, 60], [163, 58], [162, 54], [157, 51], [156, 57], [160, 61], [155, 60], [143, 59], [138, 54], [141, 48],
		[135, 43], [130, 42], [129, 36], [126, 35], [126, 38], [122, 40], [119, 39], [121, 37], [119, 35], [121, 31], [122, 28], [119, 25],
		[115, 22], [110, 21], [108, 18], [106, 21], [106, 17], [109, 12], [105, 9], [103, 10], [100, 13], [99, 8], [101, 3], [104, 1],
		[103, 2], [100, 6], [98, 9], [98, 15], [97, 17], [94, 16], [94, 20], [92, 22], [90, 22], [87, 21], [85, 19], [80, 15], [80, 10],
		[77, 8], [76, 10], [73, 16], [72, 21], [70, 22], [68, 24], [66, 25], [62, 25], [57, 25], [57, 27], [52, 28], [50, 30], [48, 30],
		[50, 27], [52, 24], [56, 24], [57, 23], [59, 22], [56, 18], [52, 16], [44, 12], [42, 15], [39, 21], [36, 26], [34, 28], [32, 31],
		[34, 32], [35, 33], [36, 36], [30, 36], [27, 37], [26, 40], [23, 40], [24, 38], [22, 37], [21, 39], [19, 42], [16, 43], [13, 45],
		[12, 44], [16, 41], [18, 40], [16, 38], [15, 40], [12, 42], [10, 44], [7, 44], [3, 43], [0, 40], [-1, 37]],
	[[-17, 21], [-16, 28], [-10, 30], [-9, 33], [-6, 36], [0, 36], [10, 37], [11, 33], [20, 31], [25, 32], [32, 31], [34, 28], [36, 24],
		[38, 18], [43, 12], [51, 12], [48, 5], [42, -1], [40, -10], [40, -15], [35, -23], [33, -27], [28, -33], [20, -35], [18, -32],
		[15, -26], [12, -17], [13, -10], [9, -1], [9, 4], [4, 6], [-4, 5], [-8, 4], [-13, 8], [-17, 13], [-17, 16]],
	[[44, -25], [47, -25], [50, -15], [49, -12], [44, -17]],
	[[114, -22], [114, -34], [118, -35], [124, -33], [132, -31], [138, -35], [141, -38], [147, -39], [150, -37], [153, -31], [153, -25],
		[146, -19], [142, -11], [141, -17], [136, -12], [131, -11], [125, -14], [122, -18]],
	[[130, 31], [132, 34], [135, 34], [140, 35], [141, 38], [142, 41], [140, 41], [139, 38], [137, 37], [133, 35], [130, 33]],
	[[140, 42], [145, 43], [145, 45], [142, 45]],
	[[-5, 50], [1, 51], [2, 53], [0, 54], [-2, 56], [-2, 58], [-5, 58], [-6, 56], [-5, 54], [-3, 53], [-5, 52]],
	[[-10, 52], [-6, 52], [-6, 55], [-8, 55], [-10, 54]],
	[[95, 5], [98, 4], [106, -3], [106, -6], [102, -4], [96, 2]],
	[[109, 2], [111, -3], [116, -4], [119, 1], [117, 7], [113, 3]],
	[[105, -6], [115, -8], [114, -9], [106, -7]],
	[[131, -1], [141, -3], [150, -10], [143, -9], [138, -8], [132, -4]],
	[[120, 22], [121.8, 25], [121.5, 25.3], [120, 23.5]],
	[[80, 6], [82, 7], [81, 9.5], [80, 9]],
	[[120, 18], [122, 18], [124, 13], [126, 7], [122, 7], [120, 14]],
	[[172, -34], [178, -38], [175, -41], [171, -44], [167, -46], [170, -43], [174, -39]],
	[[-180, -70], [180, -70], [180, -89], [-180, -89]],
	[[23.5, 35.2], [26.3, 35.1], [26, 35.4], [23.6, 35.6]],
]
const SEAS := [
	[[28, 41], [28, 44], [30, 46], [33, 45], [36, 45], [38, 47], [39, 47], [37, 44], [41, 42], [36, 42], [32, 41]],
	[[47, 45], [50, 47], [53, 45], [52, 41], [54, 37], [51, 37], [49, 38], [50, 40], [48, 42]],
]

var focus := Vector2(20, 25)       # bakılan boylam / enlem
var zoom := 1.0                    # derece başına piksel çarpanı (1 = dünyanın tamamı)
var theme_col := Color(0.25, 0.75, 0.85)
var sel := -1
var t := 0.0
var _tw: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Senaryoyu seçer: harita bölgeye kayar, renk teması değişir. i < 0 dünyanın tamamı.
func show_scenario(i: int) -> void:
	sel = i
	var to := Vector2(40, 22)
	var z := 1.0
	var col := Color(0.25, 0.75, 0.85)
	if i >= 0:
		var geo: Dictionary = Scenarios.LIST[i].get("geo", {})
		to = geo.get("c", to)
		z = float(geo.get("zoom", 5.0))
		col = geo.get("col", col)
	if _tw != null:
		_tw.kill()
	_tw = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tw.tween_property(self, "focus", to, 1.1)
	_tw.tween_property(self, "zoom", z, 1.1)
	_tw.tween_property(self, "theme_col", col, 0.8)


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _ppd() -> float:
	return size.x / 300.0 * zoom


## Seçili bölge ekranın sağ üstündeki açık alanda (başlığın arkasında) görünür.
func proj(ll: Vector2) -> Vector2:
	var k := _ppd()
	return size * Vector2(0.8, 0.27) + Vector2((ll.x - focus.x) * k, -(ll.y - focus.y) * k)


func _draw() -> void:
	var bg := Color(0.03, 0.06, 0.08).lerp(theme_col, 0.05)
	draw_rect(Rect2(Vector2.ZERO, size), bg)
	var land := Color(0.07, 0.14, 0.15).lerp(theme_col, 0.12)
	var edge := theme_col.lerp(Color.WHITE, 0.2)
	edge.a = 0.65
	var k := _ppd()
	# ızgara
	var step := 15.0 if zoom < 2.5 else (5.0 if zoom < 8.0 else 1.0)
	var gc := Color(theme_col, 0.12)
	var lon := floorf((focus.x - size.x * 0.7 / k) / step) * step
	while lon < focus.x + size.x * 0.5 / k:
		var x := proj(Vector2(lon, 0)).x
		draw_line(Vector2(x, 0), Vector2(x, size.y), gc, 1.0)
		lon += step
	var lat := floorf((focus.y - size.y * 0.7 / k) / step) * step
	while lat < focus.y + size.y * 0.7 / k:
		var y := proj(Vector2(0, lat)).y
		draw_line(Vector2(0, y), Vector2(size.x, y), gc, 1.0)
		lat += step
	# kıtalar
	var view := Rect2(Vector2.ZERO, size).grow(200.0)
	for poly in LANDS:
		var pts := PackedVector2Array()
		var any := false
		for p in poly:
			var q := proj(Vector2(p[0], p[1]))
			pts.append(q)
			any = any or view.has_point(q)
		if not any and zoom > 2.0:
			continue
		draw_colored_polygon(pts, land)
		pts.append(pts[0])
		draw_polyline(pts, edge, 1.5, true)
	for poly in SEAS:
		var pts := PackedVector2Array()
		for p in poly:
			pts.append(proj(Vector2(p[0], p[1])))
		draw_colored_polygon(pts, bg)
		pts.append(pts[0])
		draw_polyline(pts, edge, 1.0, true)
	# senaryo işaretleri
	var font := ThemeDB.fallback_font
	for i in Scenarios.LIST.size():
		var geo: Dictionary = Scenarios.LIST[i].get("geo", {})
		if geo.is_empty():
			continue
		var c := proj(geo.c)
		var locked: bool = Scenarios.LIST[i].get("locked", false)
		var mc: Color = geo.get("col", theme_col) if not locked else Color(0.55, 0.6, 0.62)
		var pulse := fmod(t * 0.8 + i * 0.3, 1.0)
		draw_arc(c, 6.0 + pulse * 22.0, 0, TAU, 28, Color(mc, 1.0 - pulse), 2.0, true)
		draw_circle(c, 5.0 if i != sel else 7.0, mc)
		if i != sel and zoom < 3.0:
			draw_string_outline(font, c + Vector2(10, -8), Scenarios.LIST[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color(0, 0, 0, 0.8))
			draw_string(font, c + Vector2(10, -8), Scenarios.LIST[i].name, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(mc, 0.9))
	if sel >= 0:
		_draw_front(Scenarios.LIST[sel])
	# radar taraması
	var center := proj(Scenarios.LIST[sel].geo.c) if sel >= 0 and Scenarios.LIST[sel].has("geo") else size * Vector2(0.8, 0.27)
	var ang := fmod(t * 0.9, TAU)
	var reach := size.length()
	for i in 14:
		var a := ang - i * 0.035
		draw_line(center, center + Vector2(cos(a), sin(a)) * reach, Color(theme_col, 0.1 * (1.0 - i / 14.0)), 3.0)
	for r in [80.0, 160.0, 240.0, 320.0]:
		draw_arc(center, r, 0, TAU, 64, Color(theme_col, 0.08), 1.0, true)
	# tarama çizgileri ve kararan kenarlar
	var y2 := 0.0
	while y2 < size.y:
		draw_line(Vector2(0, y2), Vector2(size.x, y2), Color(0, 0, 0, 0.12), 1.0)
		y2 += 4.0
	draw_rect(Rect2(0, 0, size.x, 70), Color(0, 0, 0, 0.25))
	draw_rect(Rect2(0, size.y - 50, size.x, 50), Color(0, 0, 0, 0.25))


## Seçilen senaryonun taktik çizimi: iki tarafın birlik simgeleri, cephe çizgisi ve saldırı okları.
func _draw_front(scn: Dictionary) -> void:
	if not scn.has("geo") or scn.get("locked", false):
		return
	var geo: Dictionary = scn.geo
	var font := ThemeDB.fallback_font
	var a := proj(geo.a)
	var b := proj(geo.b)
	var ca := Color(0.35, 0.6, 1.0)
	var cb := Color(1.0, 0.35, 0.3)
	# cephe hattı: iki taraf arasında kırık çizgi
	var mid := (a + b) * 0.5
	var dir := (b - a).normalized()
	var nrm := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	for i in 13:
		var f := (i - 6) / 6.0
		pts.append(mid + nrm * f * 140.0 + dir * (sin(i * 1.7 + t * 0.5) * 6.0))
	draw_polyline(pts, Color(1.0, 0.85, 0.4, 0.85), 3.0, true)
	# saldırı okları (yay)
	for k in 3:
		var off := nrm * (k - 1) * 40.0
		_arc_arrow(a + off, mid + off - dir * 18.0, ca, k * 0.33)
		_arc_arrow(b - off, mid - off + dir * 18.0, cb, k * 0.33 + 0.15)
	# birlik simgeleri (NATO tarzı)
	for k in 3:
		_unit_box(a - dir * (30.0 + k * 26.0) + nrm * (k - 1) * 34.0, ca, k)
		_unit_box(b + dir * (30.0 + k * 26.0) + nrm * (k - 1) * 34.0, cb, k + 1)
	var na: String = Scenarios.COUNTRIES[scn.a].name
	var nb: String = Scenarios.COUNTRIES[scn.b].name
	for pair in [[a, na, ca], [b, nb, cb]]:
		var p: Vector2 = pair[0] + Vector2(-30, 40)
		draw_string_outline(font, p, pair[1].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, 5, Color(0, 0, 0, 0.8))
		draw_string(font, p, pair[1].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, pair[2])
	var lbl: String = geo.get("label", "")
	if lbl != "":
		draw_string_outline(font, mid + Vector2(-80, -60), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color(0, 0, 0, 0.8))
		draw_string(font, mid + Vector2(-80, -60), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.9, 0.6))


func _arc_arrow(a: Vector2, b: Vector2, c: Color, phase: float) -> void:
	var pts := PackedVector2Array()
	var d := b - a
	var n := Vector2(-d.y, d.x).normalized() * d.length() * 0.18
	for i in 17:
		var f := i / 16.0
		pts.append(a + d * f + n * sin(f * PI))
	draw_polyline(pts, Color(c, 0.75), 3.0, true)
	var tip := pts[16]
	var back := (pts[16] - pts[14]).normalized()
	var side := Vector2(-back.y, back.x)
	draw_colored_polygon(PackedVector2Array([tip + back * 10.0, tip + side * 7.0, tip - side * 7.0]), c)
	# ok boyunca ilerleyen ışık
	var f2 := fmod(t * 0.6 + phase, 1.0)
	draw_circle(pts[int(f2 * 16.0)], 3.5, Color(1, 1, 1, 0.9))


func _unit_box(p: Vector2, c: Color, kind: int) -> void:
	var r := Rect2(p - Vector2(16, 10), Vector2(32, 20))
	draw_rect(r, Color(c, 0.3))
	draw_rect(r, c, false, 2.0)
	match kind % 3:
		0:   # piyade: çarpı
			draw_line(r.position, r.end, c, 1.5)
			draw_line(Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.position.y), c, 1.5)
		1:   # zırhlı: oval
			draw_arc(p, 7.0, 0, TAU, 16, c, 1.5)
		2:   # topçu: nokta
			draw_circle(p, 3.5, c)


## Basit ülke bayrakları (menüde taraf kartlarında).
static func draw_flag(ci: CanvasItem, r: Rect2, cc: String) -> void:
	var w := r.size.x
	var h := r.size.y
	match cc:
		"ua":
			ci.draw_rect(Rect2(r.position, Vector2(w, h * 0.5)), Color(0.0, 0.36, 0.73))
			ci.draw_rect(Rect2(r.position + Vector2(0, h * 0.5), Vector2(w, h * 0.5)), Color(1.0, 0.84, 0.0))
		"ru":
			for i in 3:
				ci.draw_rect(Rect2(r.position + Vector2(0, h * i / 3.0), Vector2(w, h / 3.0)), [Color.WHITE, Color(0.0, 0.22, 0.65), Color(0.84, 0.17, 0.12)][i])
		"il":
			ci.draw_rect(r, Color.WHITE)
			ci.draw_rect(Rect2(r.position + Vector2(0, h * 0.12), Vector2(w, h * 0.12)), Color(0.0, 0.22, 0.72))
			ci.draw_rect(Rect2(r.position + Vector2(0, h * 0.76), Vector2(w, h * 0.12)), Color(0.0, 0.22, 0.72))
			var c := r.get_center()
			var s := h * 0.2
			for k in 2:
				var tri := PackedVector2Array()
				for j in 3:
					var a := -PI * 0.5 + k * PI + j * TAU / 3.0
					tri.append(c + Vector2(cos(a), sin(a)) * s)
				tri.append(tri[0])
				ci.draw_polyline(tri, Color(0.0, 0.22, 0.72), 2.0)
		"ir":
			for i in 3:
				ci.draw_rect(Rect2(r.position + Vector2(0, h * i / 3.0), Vector2(w, h / 3.0)), [Color(0.14, 0.62, 0.25), Color.WHITE, Color(0.85, 0.12, 0.1)][i])
			ci.draw_circle(r.get_center(), h * 0.1, Color(0.85, 0.12, 0.1))
		"pk":
			ci.draw_rect(r, Color(0.0, 0.4, 0.15))
			ci.draw_rect(Rect2(r.position, Vector2(w * 0.25, h)), Color.WHITE)
			var c2 := r.position + Vector2(w * 0.62, h * 0.5)
			ci.draw_circle(c2, h * 0.27, Color.WHITE)
			ci.draw_circle(c2 + Vector2(h * 0.08, -h * 0.05), h * 0.23, Color(0.0, 0.4, 0.15))
			ci.draw_circle(c2 + Vector2(h * 0.2, -h * 0.12), h * 0.06, Color.WHITE)
		"in":
			for i in 3:
				ci.draw_rect(Rect2(r.position + Vector2(0, h * i / 3.0), Vector2(w, h / 3.0)), [Color(1.0, 0.6, 0.2), Color.WHITE, Color(0.07, 0.53, 0.03)][i])
			ci.draw_arc(r.get_center(), h * 0.13, 0, TAU, 16, Color(0.0, 0.0, 0.5), 1.5)
		_:
			ci.draw_rect(r, Color(0.4, 0.4, 0.4))
	ci.draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)
