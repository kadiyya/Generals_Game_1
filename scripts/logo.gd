class_name Logo
extends Control
## Oyunun logosu: defne dallarıyla çevrili kalkan amblemi (yıldız ve üç rütbe şevronu), altın başlık ve
## altında iki ordunun karşılaştığı cephe hattı çizgisi. Tamamı kodla çizilir; dosya gerekmez.
## Oyunun adı tek yerde: TITLE. Uygulama simgesi (icon.svg) aynı amblemi kullanır.

const TITLE := "CEPHE HATTI"
const SUBTITLE := "MODERN HARP STRATEJİSİ"
const GOLD := Color(0.98, 0.78, 0.3)
const GOLD_DARK := Color(0.62, 0.42, 0.12)
const OLIVE := Color(0.2, 0.25, 0.16)

var accent := Color(0.95, 0.55, 0.15)   # senaryoya göre değişen vurgu rengi
var t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(470, 118)


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var em := Vector2(h * 0.48, h * 0.5)
	draw_emblem(self, em, h * 0.44, accent, t)
	var font := ThemeDB.fallback_font
	var x := h * 1.0
	var fs := int(h * 0.42)
	var base := Vector2(x, h * 0.56)
	# gölge, kalın kontur ve altın dolgu
	draw_string_outline(font, base + Vector2(3, 4), TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 10, Color(0, 0, 0, 0.6))
	draw_string_outline(font, base, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 7, Color(0.1, 0.08, 0.04))
	draw_string(font, base, TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, GOLD)
	# üstten vuran parıltı: başlığın üst yarısı daha açık
	var tw := font.get_string_size(TITLE, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var shine := fmod(t * 0.35, 1.6) - 0.3
	if shine > 0.0 and shine < 1.0:
		var sx := x + tw * shine
		draw_line(Vector2(sx, base.y - fs * 0.8), Vector2(sx - fs * 0.35, base.y + fs * 0.1), Color(1, 1, 1, 0.35), 6.0)
	var sub := Vector2(x + 4, h * 0.78)
	draw_string(font, sub, _spaced(SUBTITLE), HORIZONTAL_ALIGNMENT_LEFT, -1, int(h * 0.13), Color(0.85, 0.88, 0.82))
	# cephe hattı: mavi ve kırmızı oklar arasında kırık çizgi
	var y := h * 0.9
	var x1 := x + maxf(tw, 300.0)
	var pts := PackedVector2Array()
	var n := 14
	for i in n + 1:
		var f := float(i) / n
		pts.append(Vector2(lerpf(x, x1, f), y + (4.0 if i % 2 == 0 else -4.0)))
	draw_polyline(pts, accent, 2.5, true)
	_arrow(Vector2(x - 2, y), Vector2(x + 26, y), Color(0.3, 0.55, 1.0))
	_arrow(Vector2(x1 + 2, y), Vector2(x1 - 26, y), Color(0.95, 0.3, 0.25))


func _arrow(a: Vector2, b: Vector2, c: Color) -> void:
	draw_line(a, b, c, 4.0)
	var d := (b - a).normalized()
	var nrm := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([b + d * 9.0, b + nrm * 7.0, b - nrm * 7.0]), c)


static func _spaced(s: String) -> String:
	var out := ""
	for ch in s:
		out += ch + (" " if ch != " " else "  ")
	return out.strip_edges()


## Amblem: altın kenarlı zeytin yeşili kalkan, içinde yıldız ve üç şevron, iki yanda defne dalları.
## Menüde ve yükleme ekranında kullanılır; c merkez, r yarıçap.
static func draw_emblem(ci: CanvasItem, c: Vector2, r: float, accent: Color, time := 0.0) -> void:
	# defne dalları
	for side in [-1.0, 1.0]:
		for i in 7:
			var a := deg_to_rad(100.0 + i * 20.0)
			var off := Vector2(cos(a), sin(a)) * r * 1.02
			var ang := a + PI * 0.5
			if side > 0.0:
				off.x = -off.x
				ang = PI - ang
			var leaf := _leaf(c + off, r * 0.24, ang)
			ci.draw_colored_polygon(leaf, GOLD_DARK.lerp(GOLD, 0.35 + i * 0.06))
	# kalkan
	var sh := PackedVector2Array()
	sh.append(c + Vector2(-r * 0.78, -r * 0.82))
	sh.append(c + Vector2(r * 0.78, -r * 0.82))
	sh.append(c + Vector2(r * 0.78, r * 0.05))
	for i in 9:
		var f := float(i) / 8.0
		sh.append(c + Vector2(r * 0.78 * cos(f * PI * 0.5), r * 0.05 + r * 0.92 * sin(f * PI * 0.5)))
	for i in 9:
		var f := float(i) / 8.0
		sh.append(c + Vector2(-r * 0.78 * sin(f * PI * 0.5), r * 0.05 + r * 0.92 * cos(f * PI * 0.5)))
	sh.append(c + Vector2(-r * 0.78, -r * 0.82))
	var big := PackedVector2Array()
	for p in sh:
		big.append(c + (p - c) * 1.1)
	ci.draw_colored_polygon(big, GOLD)
	ci.draw_colored_polygon(sh, OLIVE)
	ci.draw_polyline(sh, GOLD_DARK, 2.0, true)
	# yıldız
	var star := PackedVector2Array()
	var sc := c + Vector2(0, -r * 0.38)
	for i in 10:
		var a := -PI * 0.5 + i * PI / 5.0
		var rr := r * (0.28 if i % 2 == 0 else 0.11)
		star.append(sc + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(star, GOLD)
	# şevronlar
	for i in 3:
		var y := c.y + r * (0.0 + i * 0.22)
		var w := r * 0.52
		var col := accent if i == 0 else GOLD
		var chev := PackedVector2Array([
			Vector2(c.x - w, y + r * 0.12), Vector2(c.x, y - r * 0.06), Vector2(c.x + w, y + r * 0.12),
			Vector2(c.x + w, y + r * 0.24), Vector2(c.x, y + r * 0.06), Vector2(c.x - w, y + r * 0.24)])
		ci.draw_colored_polygon(PackedVector2Array([chev[1], chev[2], chev[3], chev[4]]), col)
		ci.draw_colored_polygon(PackedVector2Array([chev[0], chev[1], chev[4], chev[5]]), col)
	# kenarda dönen radar ışığı
	var sw := fmod(time * 1.2, TAU)
	ci.draw_arc(c, r * 1.22, sw, sw + 0.7, 12, Color(accent, 0.7), 2.0, true)


static func _leaf(p: Vector2, l: float, ang: float) -> PackedVector2Array:
	var d := Vector2(cos(ang), sin(ang))
	var n := Vector2(-d.y, d.x)
	return PackedVector2Array([p - d * l * 0.5, p + n * l * 0.22, p + d * l * 0.5, p - n * l * 0.22])
