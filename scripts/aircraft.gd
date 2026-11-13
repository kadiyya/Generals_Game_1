class_name Aircraft
extends RefCounted
## Uçak ve İHA modelleri. Jetler oyun biriminde, AIRFRAMES tablosundaki ölçülerle; İHA'lar gerçek ölçüyle
## (metre) yazılıp her biri kendi ölçeğiyle küçültülür/büyütülür. Ön +Z, üst +Y.
## Pervaneler ayrı bir kurucuya (pk) bir kez çizilir: ekseni +Y, göbeği merkezde. design() göbeklerin
## [konum, döndürme (derece)] listesini döndürür; Models her göbeğe dönen bir pervane koyar.
## Not: bu dosya yalnızca Kit çağrıları ve düz hesap içerir; geliştirme önizleme aracı da aynı kodu okur.

# len/w/h: gövde boyu, genişliği, yüksekliği. eng: motor sayısı. pods: motorlar ayrı nasellerde (sp: aralarındaki
# yarı uzaklık, nr: nasel yarıçapı). intake: chin (gövde altı), side (yanlar), nose (burunda koni), box (nasel
# önünde dikdörtgen). seats: 1, 2 (arka arkaya), 3 (yan yana). Kanat ve yatay kuyruk: sağ yarının (x, z) köşeleri.
const AIRFRAMES := {
	"f16": {"len": 5.0, "w": 0.5, "h": 0.5, "eng": 1, "tail": "single", "intake": "chin", "lerx": 0.27, "ventral": true,
		"wing": [Vector2(0.25, 0.7), Vector2(1.9, -0.5), Vector2(1.9, -0.9), Vector2(0.25, -1.1)],
		"stab": [Vector2(0.25, -1.6), Vector2(1.1, -2.1), Vector2(1.1, -2.4), Vector2(0.25, -2.3)]},
	"jf17": {"len": 4.8, "w": 0.5, "h": 0.5, "eng": 1, "tail": "single", "intake": "side", "lerx": 0.24,
		"wing": [Vector2(0.25, 0.5), Vector2(1.8, -0.6), Vector2(1.8, -0.95), Vector2(0.25, -1.1)],
		"stab": [Vector2(0.25, -1.5), Vector2(1.05, -2.0), Vector2(1.05, -2.3), Vector2(0.25, -2.2)]},
	"mirage": {"len": 4.9, "w": 0.48, "h": 0.5, "eng": 1, "tail": "single", "intake": "side",
		"wing": [Vector2(0.24, 0.9), Vector2(1.9, -1.9), Vector2(0.24, -2.0)]},
	"tejas": {"len": 4.1, "w": 0.44, "h": 0.46, "eng": 1, "tail": "single", "intake": "side",
		"wing": [Vector2(0.22, 0.7), Vector2(1.55, -1.6), Vector2(0.22, -1.7)]},
	"mig21": {"len": 4.4, "w": 0.42, "h": 0.44, "eng": 1, "tail": "single", "intake": "nose",
		"wing": [Vector2(0.21, 0.4), Vector2(1.35, -1.0), Vector2(0.21, -1.1)],
		"stab": [Vector2(0.21, -1.5), Vector2(0.85, -1.95), Vector2(0.21, -2.0)]},
	"j10": {"len": 5.0, "w": 0.5, "h": 0.52, "eng": 1, "tail": "single", "intake": "chin", "ventral": true,
		"wing": [Vector2(0.25, 0.3), Vector2(1.9, -1.7), Vector2(0.25, -1.9)],
		"canard": [Vector2(0.25, 1.3), Vector2(1.0, 0.85), Vector2(0.25, 0.7)]},
	"rafale": {"len": 5.0, "w": 0.62, "h": 0.5, "eng": 2, "pods": false, "tail": "single", "intake": "side",
		"wing": [Vector2(0.31, 0.5), Vector2(2.0, -1.6), Vector2(0.31, -1.9)],
		"canard": [Vector2(0.31, 1.25), Vector2(0.95, 0.9), Vector2(0.31, 0.75)]},
	"f35": {"len": 4.9, "w": 0.8, "h": 0.55, "eng": 1, "tail": "canted", "intake": "side", "facet": true, "stealth": true,
		"wing": [Vector2(0.4, 0.5), Vector2(1.8, -0.6), Vector2(1.8, -1.0), Vector2(0.4, -1.3)],
		"stab": [Vector2(0.4, -1.5), Vector2(1.3, -2.0), Vector2(1.3, -2.4), Vector2(0.4, -2.3)]},
	"f15": {"len": 5.9, "w": 0.85, "h": 0.55, "eng": 2, "sp": 0.24, "nr": 0.15, "tail": "twin", "intake": "box", "seats": 2, "inx": 0.42, "iny": 0.0,
		"wing": [Vector2(0.42, 0.9), Vector2(2.2, -0.6), Vector2(2.2, -1.1), Vector2(0.42, -1.3)],
		"stab": [Vector2(0.5, -1.9), Vector2(1.5, -2.5), Vector2(1.5, -2.9), Vector2(0.5, -2.7)]},
	"f14": {"len": 6.0, "w": 1.15, "h": 0.5, "eng": 2, "sp": 0.36, "nr": 0.16, "tail": "twin", "intake": "box", "seats": 2, "inx": 0.5, "iny": 0.0,
		"wing": [Vector2(0.57, 0.7), Vector2(2.7, -1.0), Vector2(2.6, -1.5), Vector2(0.57, -0.9)],
		"stab": [Vector2(0.57, -2.0), Vector2(1.5, -2.7), Vector2(1.4, -3.0), Vector2(0.57, -2.8)]},
	"f4": {"len": 5.6, "w": 0.7, "h": 0.55, "eng": 2, "pods": false, "tail": "single", "intake": "side", "seats": 2, "stab_dih": -20.0,
		"wing": [Vector2(0.35, 0.6), Vector2(1.9, -0.9), Vector2(1.9, -1.3), Vector2(0.35, -1.4)],
		"stab": [Vector2(0.35, -2.0), Vector2(1.1, -2.5), Vector2(1.0, -2.8), Vector2(0.35, -2.6)]},
	"su35": {"len": 6.4, "w": 0.9, "h": 0.55, "eng": 2, "sp": 0.3, "nr": 0.16, "tail": "twin", "intake": "box", "lerx": 0.3,
		"wing": [Vector2(0.45, 1.0), Vector2(2.5, -0.9), Vector2(2.5, -1.4), Vector2(0.45, -1.5)],
		"stab": [Vector2(0.5, -2.0), Vector2(1.6, -2.9), Vector2(1.6, -3.2), Vector2(0.5, -2.9)]},
	"su30": {"len": 6.4, "w": 0.9, "h": 0.55, "eng": 2, "sp": 0.3, "nr": 0.16, "tail": "twin", "intake": "box", "lerx": 0.3, "seats": 2,
		"wing": [Vector2(0.45, 1.0), Vector2(2.5, -0.9), Vector2(2.5, -1.4), Vector2(0.45, -1.5)],
		"stab": [Vector2(0.5, -2.0), Vector2(1.6, -2.9), Vector2(1.6, -3.2), Vector2(0.5, -2.9)],
		"canard": [Vector2(0.45, 1.7), Vector2(1.15, 1.3), Vector2(0.45, 1.1)]},
	"su34": {"len": 6.6, "w": 1.1, "h": 0.55, "eng": 2, "sp": 0.32, "nr": 0.16, "tail": "twin", "intake": "box", "flat_nose": true, "seats": 3,
		"wing": [Vector2(0.55, 1.0), Vector2(2.5, -0.9), Vector2(2.5, -1.4), Vector2(0.55, -1.5)],
		"stab": [Vector2(0.55, -2.1), Vector2(1.6, -3.0), Vector2(1.6, -3.3), Vector2(0.55, -3.0)],
		"canard": [Vector2(0.55, 1.8), Vector2(1.2, 1.4), Vector2(0.55, 1.2)]},
	"mig29": {"len": 5.3, "w": 0.78, "h": 0.5, "eng": 2, "sp": 0.26, "nr": 0.14, "tail": "twin", "intake": "box", "lerx": 0.32,
		"wing": [Vector2(0.39, 0.8), Vector2(2.0, -0.7), Vector2(2.0, -1.1), Vector2(0.39, -1.2)],
		"stab": [Vector2(0.42, -1.7), Vector2(1.3, -2.4), Vector2(1.3, -2.7), Vector2(0.42, -2.4)]},
	"su57": {"len": 6.2, "w": 1.15, "h": 0.42, "eng": 2, "sp": 0.34, "nr": 0.15, "tail": "canted", "intake": "box", "flat_nose": true,
		"facet": true, "stealth": true, "lerx": 0.33,
		"wing": [Vector2(0.57, 1.7), Vector2(2.4, -1.0), Vector2(2.2, -1.7), Vector2(0.57, -1.9)],
		"stab": [Vector2(0.6, -2.0), Vector2(1.5, -2.7), Vector2(1.3, -3.1), Vector2(0.6, -2.9)]},
}

const DRONES := ["quad", "hexa", "small_plane", "xwing", "shahed", "shahed_s", "harop", "tb2", "twinboom", "mohajer6",
	"liutyi", "vtail", "akinci", "flyingwing"]


static func has(id: String) -> bool:
	return AIRFRAMES.has(id) or id in DRONES


## Renk yuvaları. ac: ülkenin uçak boyası, tc: takım rengi.
static func slots(k: Kit, ac: Color, tc: Color) -> void:
	k.slot("skin", "paint", ac, 0.0)
	k.slot("skin2", "paint", ac.darkened(0.16), 0.0)
	k.slot("radome", "paint", ac.darkened(0.3), 0.0)
	k.slot("steel", "steel", Color(0.42, 0.41, 0.4), 0.0)
	k.slot("dark", "steel", Color(0.07, 0.07, 0.08), 0.0)
	k.slot("plastic", "paint", Color(0.17, 0.18, 0.18), 0.0)
	k.slot("glass", "optic", Color(0.24, 0.31, 0.36), 0.0)
	k.slot("stealth", "paint", Color(0.25, 0.27, 0.29), 0.0)
	k.slot("team", "paint", tc, 0.0)
	k.slot("white", "paint", Color(0.88, 0.88, 0.85), 0.0)
	k.slot("bomb", "paint", Color(0.36, 0.37, 0.3), 0.0)
	k.slot("rotor", "steel", Color(0.12, 0.12, 0.12), 0.0)


static func design(id: String, k: Kit, pk: Kit, cls: String) -> Array:
	if AIRFRAMES.has(id):
		_jet(k, AIRFRAMES[id], cls)
		return []
	if id == "quad":
		return _quad(k, pk)
	if id == "hexa":
		return _hexa(k, pk)
	if id == "small_plane":
		return _orlan(k, pk)
	if id == "xwing":
		return _lancet(k, pk)
	if id == "shahed":
		return _shahed(k, pk, 0.85)
	if id == "shahed_s":
		return _shahed(k, pk, 0.5)
	if id == "harop":
		return _harop(k, pk)
	if id == "tb2":
		return _tb2(k, pk)
	if id == "twinboom":
		return _heron(k, pk)
	if id == "mohajer6":
		return _mohajer(k, pk)
	if id == "liutyi":
		return _liutyi(k, pk)
	if id == "vtail":
		return _mq9(k, pk)
	if id == "akinci":
		return _akinci(k, pk)
	return _flyingwing(k, pk)


# ---------------------------------------------------------------- jetler (oyun biriminde)

static func _jet(k: Kit, p: Dictionary, cls: String) -> void:
	var l: float = p["len"]
	var w: float = p["w"]
	var h: float = p["h"]
	var hw := w * 0.5
	var hh := h * 0.5
	var twin: bool = p["eng"] == 2
	var pods: bool = twin and p.get("pods", true)
	var facet: bool = p.get("facet", false)
	var flat: bool = p.get("flat_nose", false)
	var intake: String = p.get("intake", "chin")
	var n := 8 if facet else 12
	var skin := "skin2" if p.get("stealth", false) else "skin"
	# burun (radom)
	var nose := [[0.5, 0.06, 0.06, 0.06], [0.41, 0.55, 0.52, 0.48]]
	if flat:
		nose = [[0.5, 0.12, 0.04, 0.05], [0.4, 0.85, 0.45, 0.5]]
	if intake == "nose":
		nose = [[0.5, 0.62, 0.62, 0.62], [0.41, 0.7, 0.7, 0.7]]
	_body(k, "radome", l, hw, hh, nose, n, facet)
	# gövde
	var body := [nose[1], [0.32, 0.85, 0.82, 0.8], [0.2, 1.0, 1.0, 0.95], [-0.1, 1.0, 1.0, 1.0], [-0.36, 0.9, 0.85, 0.85], [-0.44, 0.75, 0.7, 0.7]]
	if pods:
		body = [nose[1], [0.32, 0.85, 0.82, 0.8], [0.2, 1.0, 1.0, 0.95], [0.02, 0.9, 0.95, 0.8], [-0.25, 0.6, 0.75, 0.5], [-0.42, 0.35, 0.5, 0.3]]
	if flat:
		body[1] = [0.32, 1.0, 0.75, 0.8]
	_body(k, skin, l, hw, hh, body, n, facet)
	var sp: float = p.get("sp", 0.0)
	var nr: float = p.get("nr", 0.0)
	var ny := -hh * 0.05
	if pods:
		# motorlar arası yassı gövde ve iki nasel
		k.loft(skin, [_ring(0.24 * l, 0.0, 0.0, sp * 0.6, hh * 0.35, hh * 0.15, 8),
			_ring(0.08 * l, 0.0, 0.0, sp + nr * 0.6, hh * 0.5, hh * 0.15, 8),
			_ring(-0.36 * l, 0.0, 0.0, sp + nr * 0.6, hh * 0.45, hh * 0.15, 8),
			_ring(-0.44 * l, 0.0, 0.0, sp + nr * 0.3, hh * 0.3, hh * 0.1, 8)])
		for sx in [-1.0, 1.0]:
			k.loft(skin, [_ring(0.12 * l, sp * sx, ny, nr * 0.95, nr, nr, 10),
				_ring(-0.2 * l, sp * sx, ny, nr, nr, nr, 10),
				_ring(-0.43 * l, sp * sx, ny, nr * 0.9, nr * 0.9, nr * 0.9, 10)], true)
	# hava alığı
	if intake == "box":
		var front: float = l * p.get("inz", 0.27)
		for sx in [-1.0, 1.0]:
			# önde (F-15/F-14'te kokpit yanında yüksekte, Su/MiG'de kanat kökü altında) dikdörtgen ağız, geride nasele bağlanır
			var x: float = p.get("inx", sp) * sx
			var a := nr * 1.05
			var b := nr * 1.15
			var y: float = -hh * p.get("iny", 0.55)
			var bx: float = sp * sx
			k.loft(skin, [
				[Vector3(x - a, y - b, front - l * 0.04), Vector3(x + a, y - b, front - l * 0.04), Vector3(x + a, y + b, front), Vector3(x - a, y + b, front)],
				[Vector3(bx - a, ny - b, l * 0.08), Vector3(bx + a, ny - b, l * 0.08), Vector3(bx + a, ny + b * 0.8, l * 0.08), Vector3(bx - a, ny + b * 0.8, l * 0.08)],
			])
			k.box("dark", Vector3(a * 1.7, b * 1.7, 0.01), Vector3(x, y, front - l * 0.02 + 0.006), Vector3(-rad_to_deg(atan2(l * 0.04, b * 2.0)), 0, 0))
	elif intake == "chin":
		k.loft(skin, [
			[Vector3(-hw * 0.6, -hh * 1.45, 0.2 * l), Vector3(hw * 0.6, -hh * 1.45, 0.2 * l), Vector3(hw * 0.6, -hh * 0.4, 0.21 * l), Vector3(-hw * 0.6, -hh * 0.4, 0.21 * l)],
			[Vector3(-hw * 0.5, -hh * 1.3, -0.08 * l), Vector3(hw * 0.5, -hh * 1.3, -0.08 * l), Vector3(hw * 0.5, -hh * 0.4, -0.08 * l), Vector3(-hw * 0.5, -hh * 0.4, -0.08 * l)],
		])
		k.box("dark", Vector3(hw * 1.0, hh * 0.85, 0.01), Vector3(0, -hh * 0.92, 0.2 * l + 0.008))
	elif intake == "side":
		for sx in [-1.0, 1.0]:
			var x: float = (hw * 0.9 + w * 0.12) * sx
			var a := w * 0.12
			k.loft(skin, [
				[Vector3(x - a, -hh * 0.75, 0.21 * l), Vector3(x + a, -hh * 0.75, 0.19 * l), Vector3(x + a, hh * 0.45, 0.19 * l), Vector3(x - a, hh * 0.45, 0.21 * l)],
				[Vector3(x - a, -hh * 0.6, -0.12 * l), Vector3(x - a * 0.2, -hh * 0.5, -0.12 * l), Vector3(x - a * 0.2, hh * 0.3, -0.12 * l), Vector3(x - a, hh * 0.4, -0.12 * l)],
			])
			k.box("dark", Vector3(a * 1.6, hh * 1.05, 0.01), Vector3(x, -hh * 0.15, 0.2 * l + 0.006), Vector3(0, 6.0 * sx, 0))
	else:
		k.lathe("dark", [Vector2(0, 0), Vector2(hh * 0.6, 0), Vector2(hh * 0.6, 0.01), Vector2(0, 0.01)], Vector3(0, 0, 0.5 * l - 0.01), Vector3(90, 0, 0), 12)
		k.lathe("steel", [Vector2(hh * 0.35, 0), Vector2(0.01, l * 0.07)], Vector3(0, 0, 0.5 * l - 0.02), Vector3(90, 0, 0), 10)
	# kokpit camı
	var seats: int = p.get("seats", 1)
	var cz := l * (0.36 if flat else 0.33)
	var cl := l * (0.25 if seats == 2 else 0.16)
	var cw := minf(hw * (0.95 if seats == 3 else 0.6), 0.3)
	var ch := minf(hh * 0.6, 0.16)
	var top := hh * 0.9
	k.loft("glass", [_dome(cz, top, cw * 0.3, ch * 0.3), _dome(cz - cl * 0.3, top, cw, ch), _dome(cz - cl * 0.7, top, cw * 0.95, ch * 0.92),
		_dome(cz - cl, top, cw * 0.55, ch * 0.4)], true)
	k.box("dark", Vector3(cw * 2.0, 0.02, 0.025), Vector3(0, top + ch * 0.62, cz - cl * 0.3))
	if seats == 2:
		k.box("dark", Vector3(cw * 1.95, 0.02, 0.025), Vector3(0, top + ch * 0.9, cz - cl * 0.55))
	# kanatlar, yatay kuyruk, kanardlar, kök uzantıları
	var wing: Array = p["wing"]
	_slab(k, skin, wing, 0.0, h * 0.14, h * 0.05, 0.0)
	if p.has("stab"):
		_slab(k, skin, p["stab"], 0.0, h * 0.09, h * 0.04, p.get("stab_dih", 0.0))
	if p.has("canard"):
		_slab(k, skin, p["canard"], hh * 0.4, h * 0.07, h * 0.03, 0.0)
	var root: Vector2 = wing[0]
	if p.has("lerx"):
		var lx: float = p["lerx"]
		_slab(k, skin, [Vector2(hw * 0.85, lx * l), Vector2(root.x + l * 0.03, root.y), Vector2(hw * 0.85, root.y - l * 0.03)], 0.0, h * 0.06, h * 0.04, 0.0)
	# dikey kuyruk ve uç bandı (takım rengi)
	var fh: float = l * 0.2
	var fin := [Vector2(-l * 0.2, hh * 0.8), Vector2(-l * 0.4, hh * 0.8 + fh), Vector2(-l * 0.46, hh * 0.8 + fh), Vector2(-l * 0.44, hh * 0.8)]
	var tail: String = p["tail"]
	var fx: float = sp if pods else w * 0.38
	if tail == "single":
		_fin(k, skin, fin, 0.0, 0.0, h * 0.08)
	else:
		var cant := 0.0 if tail == "twin" else 24.0
		for sx in [-1.0, 1.0]:
			_fin(k, skin, fin, fx * sx, cant * sx, h * 0.08)
	if p.get("ventral", false):
		for sx in [-1.0, 1.0]:
			_fin(k, skin, [Vector2(-l * 0.3, -hh * 0.6), Vector2(-l * 0.38, -hh * 0.6), Vector2(-l * 0.4, -hh * 1.3), Vector2(-l * 0.34, -hh * 1.3)], hw * 0.6 * sx, -25.0 * sx, 0.025)
	var band := [fin[1].lerp(fin[0], 0.22), fin[1], fin[2], fin[2].lerp(fin[3], 0.22)]
	if tail == "single":
		_fin(k, "team", band, 0.0, 0.0, h * 0.08 + 0.012)
	else:
		for sx in [-1.0, 1.0]:
			_fin(k, "team", band, fx * sx, (0.0 if tail == "twin" else 24.0) * sx, h * 0.08 + 0.012)
	# lüleler
	if pods:
		for sx in [-1.0, 1.0]:
			_nozzle(k, Vector3(sp * sx, ny, -0.43 * l), nr * 0.92, l * 0.07)
	elif twin:
		for sx in [-1.0, 1.0]:
			_nozzle(k, Vector3(w * 0.25 * sx, 0, -0.44 * l), w * 0.22, l * 0.07)
	else:
		_nozzle(k, Vector3(0, 0, -0.44 * l), hw * 0.72, l * 0.08)
	# kanat üstü milli işaret (takım rengi) ve silahlar
	var tip := root
	for q in wing:
		if q.x > tip.x:
			tip = q
	var rx := lerpf(root.x, tip.x, 0.62)
	var ch2 := _chord(wing, rx)
	var rr := minf(0.2, (ch2.x - ch2.y) * 0.3)
	var ty := lerpf(h * 0.14, h * 0.05, 0.62) * 0.6
	for sx in [-1.0, 1.0]:
		var c := Vector3(rx * sx, ty, (ch2.x + ch2.y) * 0.5)
		k.lathe("team", [Vector2(rr, 0), Vector2(rr, 0.006), Vector2(0, 0.006)], c, Vector3.ZERO, 14)
		k.lathe("white", [Vector2(rr * 0.42, 0), Vector2(rr * 0.42, 0.01), Vector2(0, 0.01)], c, Vector3.ZERO, 10)
	if p.get("stealth", false):
		return
	var tc := _chord(wing, tip.x - 0.02)
	var ml := l * 0.18
	for sx in [-1.0, 1.0]:
		var mx := lerpf(root.x, tip.x, 0.55)
		var mc := _chord(wing, mx)
		if cls == "striker":
			_bomb(k, Vector3(mx * sx, -0.16, (mc.x + mc.y) * 0.5 - ml * 0.5), ml * 0.9, 0.075)
			var bx := lerpf(root.x, tip.x, 0.3)
			var bc := _chord(wing, bx)
			_bomb(k, Vector3(bx * sx, -0.17, (bc.x + bc.y) * 0.5 - ml * 0.5), ml * 0.9, 0.075)
		else:
			_missile(k, Vector3(mx * sx, -0.12, (mc.x + mc.y) * 0.5 - ml * 0.5), ml, 0.04)
			_missile(k, Vector3((tip.x + 0.04) * sx, 0.0, tc.y - ml * 0.1), ml * 0.85, 0.035)
		k.box("skin2", Vector3(0.025, 0.07, ml * 0.5), Vector3(mx * sx, -0.06, (mc.x + mc.y) * 0.5))
	if cls == "striker":
		k.lathe("skin2", [Vector2(0, 0), Vector2(0.09, l * 0.05), Vector2(0.1, l * 0.17), Vector2(0, l * 0.24)],
			Vector3(0, -hh * 1.5 - 0.1, -0.12 * l), Vector3(90, 0, 0), 10)


## Oyun birimindeki gövde istasyonları: [z oranı, yarı genişlik oranı, üst, alt].
static func _body(k: Kit, s: String, l: float, hw: float, hh: float, st: Array, n: int, facet: bool) -> void:
	var rings: Array = []
	for r in st:
		rings.append(_ring(r[0] * l, 0.0, 0.0, hw * r[1], hh * r[2], hh * r[3], n))
	k.loft(s, rings, not facet)


## Gövde kesiti: z'de, (xc, yc) merkezli, yarı genişlik hw, üste top, alta bot uzanan n köşeli halka.
static func _ring(z: float, xc: float, yc: float, hw: float, top: float, bot: float, n: int) -> Array:
	var r: Array = []
	for i in n:
		var a := TAU * (i + 0.5) / n
		var sy := sin(a)
		r.append(Vector3(xc + hw * cos(a), yc + sy * (top if sy > 0.0 else bot), z))
	return r


## Kokpit camı kesiti: gövde üstünde yarım elips.
static func _dome(z: float, y: float, cw: float, ch: float) -> Array:
	var r: Array = []
	for i in 9:
		var a := PI * i / 8.0
		r.append(Vector3(cw * cos(a), y + ch * sin(a), z))
	return r


## Kanat / kuyruk levhası: sağ yarı (x, z) köşeleri, kökte t0 uçta t1 kalınlık, dih derece kanat açısı. İki yanı kurar.
static func _slab(k: Kit, s: String, pts: Array, y: float, t0: float, t1: float, dih: float) -> void:
	var x0: float = pts[0].x
	var x1: float = pts[0].x
	for q in pts:
		x0 = minf(x0, q.x)
		x1 = maxf(x1, q.x)
	var dt := tan(deg_to_rad(dih))
	for sx in [-1.0, 1.0]:
		var lo: Array = []
		var hi: Array = []
		for q in pts:
			var f: float = (q.x - x0) / maxf(x1 - x0, 0.001)
			var t := lerpf(t0, t1, f)
			var yy: float = y + (q.x - x0) * dt
			lo.append(Vector3(q.x * sx, yy - t * 0.4, q.y))
			hi.append(Vector3(q.x * sx, yy + t * 0.6, q.y))
		k.loft(s, [lo, hi])


## Dikey yüzey: (z, y) köşeleri, x konumunda, cant derece dışa yatık, t kalınlık.
static func _fin(k: Kit, s: String, pts: Array, x: float, cant: float, t: float) -> void:
	var a: Array = []
	var b: Array = []
	for q in pts:
		a.append(Vector3(-t * 0.5, q.y, q.x))
		b.append(Vector3(t * 0.5, q.y, q.x))
	k.push(Vector3(x, 0, 0), Vector3(0, 0, -cant))
	k.loft(s, [a, b])
	k.pop()


## Konveks çokgende x hizasındaki kirişin ön ve arka z'si (Vector2(ön, arka)).
static func _chord(pts: Array, x: float) -> Vector2:
	var zs: Array = []
	var m := pts.size()
	for i in m:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % m]
		if absf(a.x - b.x) > 0.0001 and (a.x - x) * (b.x - x) <= 0.0:
			zs.append(lerpf(a.y, b.y, (x - a.x) / (b.x - a.x)))
	if zs.is_empty():
		return Vector2(pts[0].y, pts[0].y)
	var hi: float = zs[0]
	var lo: float = zs[0]
	for z in zs:
		hi = maxf(hi, z)
		lo = minf(lo, z)
	return Vector2(hi, lo)


## Jet lülesi: geriye bakan, içi koyu.
static func _nozzle(k: Kit, p: Vector3, r: float, ln: float) -> void:
	k.lathe("steel", [Vector2(r, 0), Vector2(r * 0.97, ln * 0.6), Vector2(r * 0.86, ln), Vector2(r * 0.72, ln), Vector2(r * 0.72, ln * 0.4)],
		p, Vector3(-90, 0, 0), 12)
	k.lathe("dark", [Vector2(0, 0), Vector2(r * 0.73, 0), Vector2(r * 0.73, 0.01), Vector2(0, 0.01)], p + Vector3(0, 0, -ln * 0.42), Vector3(-90, 0, 0), 10)


## Hava-hava füzesi: beyaz gövde, koyu burun, arkada dört kanatçık. p arka uç, öne doğru ln uzunluk.
static func _missile(k: Kit, p: Vector3, ln: float, r: float) -> void:
	k.lathe("white", [Vector2(0, 0), Vector2(r, 0), Vector2(r, ln * 0.86)], p, Vector3(90, 0, 0), 8)
	k.lathe("radome", [Vector2(r, ln * 0.86), Vector2(0, ln)], p, Vector3(90, 0, 0), 8)
	for a in [45.0, 135.0]:
		k.box("white", Vector3(r * 5.0, 0.008, ln * 0.12), p + Vector3(0, 0, ln * 0.08), Vector3(0, 0, a))


## Bomba: yeşil gövde, sivri burun, kuyruk kanatçıkları.
static func _bomb(k: Kit, p: Vector3, ln: float, r: float) -> void:
	k.lathe("bomb", [Vector2(0, 0), Vector2(r * 0.55, 0), Vector2(r, ln * 0.3), Vector2(r, ln * 0.75), Vector2(0, ln)], p, Vector3(90, 0, 0), 10)
	for a in [45.0, 135.0]:
		k.box("bomb", Vector3(r * 3.2, 0.008, ln * 0.18), p + Vector3(0, 0, ln * 0.08), Vector3(0, 0, a))


# ---------------------------------------------------------------- İHA ortak parçaları (gerçek ölçü)

## Yuvarlak gövde: [z, yarı genişlik, üst, alt] istasyonları, yc yüksekliğinde.
static func _pod(k: Kit, s: String, st: Array, yc: float) -> void:
	var rings: Array = []
	for r in st:
		rings.append(_ring(r[0], 0.0, yc, r[1], r[2], r[3], 12))
	k.loft(s, rings, true)


## İnce kiriş / boru: x, y'de, z0'dan z1'e, r yarıçap.
static func _boom(k: Kit, s: String, x: float, y: float, z0: float, z1: float, r: float) -> void:
	k.loft(s, [_ring(z0, x, y, r, r, r, 8), _ring(z1, x, y, r * 0.7, r * 0.7, r * 0.7, 8)], true)


## Elektro-optik kamera topu.
static func _eo(k: Kit, p: Vector3, r: float) -> void:
	var prof: Array = []
	for i in 7:
		var a := -PI * 0.5 + PI * i / 6.0
		prof.append(Vector2(cos(a) * r, sin(a) * r))
	k.lathe("skin2", prof, p, Vector3.ZERO, 10)
	k.box("glass", Vector3(r * 0.9, r * 0.6, 0.02), p + Vector3(0, -r * 0.1, r * 0.98))


## Pervane: n kanat, r yarıçap, c kanat genişliği. Ekseni +Y, göbek merkezde.
static func _prop(k: Kit, n: int, r: float, c: float) -> void:
	k.lathe("dark", [Vector2(0, -c * 0.4), Vector2(c * 0.5, -c * 0.4), Vector2(c * 0.3, c * 0.3), Vector2(0, c * 0.6)], Vector3.ZERO, Vector3.ZERO, 8)
	for i in n:
		k.push(Vector3.ZERO, Vector3(0, 360.0 * i / n, 0))
		k.box("rotor", Vector3(r - c * 0.3, c * 0.12, c), Vector3((r + c * 0.3) * 0.5, 0, 0), Vector3(18, 0, 0))
		k.box("white", Vector3(r * 0.08, c * 0.13, c * 1.01), Vector3(r * 0.95, 0, 0), Vector3(18, 0, 0))
		k.pop()


## Takım rengi işaret: kanat üstünde disk.
static func _mark(k: Kit, p: Vector3, r: float) -> void:
	k.lathe("team", [Vector2(r, 0), Vector2(r, 0.008), Vector2(0, 0.008)], p, Vector3.ZERO, 14)
	k.lathe("white", [Vector2(r * 0.42, 0), Vector2(r * 0.42, 0.012), Vector2(0, 0.012)], p, Vector3.ZERO, 10)


## Ölçeği uygulanmış göbek listesi.
static func _hubs(s: float, hubs: Array) -> Array:
	var out: Array = []
	for hb in hubs:
		out.append([hb[0] * s, hb[1]])
	return out


# ---------------------------------------------------------------- küçük İHA'lar

## DJI Mavic / FPV / Switch: dört kollu, katlanır kollu küçük helikopter dron (görünürlük için büyütülmüş).
static func _quad(k: Kit, pk: Kit) -> Array:
	var s := 4.0
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	k.loft("plastic", [_ring(0.11, 0.0, 0.0, 0.035, 0.025, 0.025, 10), _ring(0.06, 0.0, 0.0, 0.05, 0.04, 0.035, 10),
		_ring(-0.07, 0.0, 0.0, 0.05, 0.04, 0.035, 10), _ring(-0.11, 0.0, 0.0, 0.035, 0.03, 0.025, 10)], true)
	k.box("team", Vector3(0.06, 0.006, 0.09), Vector3(0, 0.041, -0.01))
	_eo(k, Vector3(0, -0.035, 0.11), 0.018)
	var hubs: Array = []
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var m := Vector3(0.14 * sx, 0.01, 0.12 * sz)
			k.push(Vector3(0.07 * sx, 0.0, 0.06 * sz), Vector3(0, rad_to_deg(atan2(0.14 * sx, 0.12 * sz)), 0))
			k.box("plastic", Vector3(0.016, 0.014, 0.19), Vector3.ZERO)
			k.pop()
			k.lathe("dark", [Vector2(0, -0.02), Vector2(0.016, -0.02), Vector2(0.016, 0.02), Vector2(0, 0.02)], m, Vector3.ZERO, 8)
			hubs.append([m + Vector3(0, 0.025, 0), Vector3.ZERO])
	_prop(pk, 2, 0.12, 0.022)
	k.pop()
	pk.pop()
	return _hubs(s, hubs)


## Baba Yaga: altı kollu ağır bombardıman dronu, altında bomba.
static func _hexa(k: Kit, pk: Kit) -> Array:
	var s := 1.25
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	k.loft("plastic", [_ring(0.22, 0.0, 0.0, 0.12, 0.08, 0.06, 8), _ring(-0.22, 0.0, 0.0, 0.12, 0.08, 0.06, 8)])
	k.box("skin2", Vector3(0.2, 0.08, 0.3), Vector3(0, 0.11, 0))
	k.box("team", Vector3(0.16, 0.01, 0.2), Vector3(0, 0.155, 0))
	var hubs: Array = []
	for i in 6:
		var a := TAU * (i + 0.5) / 6.0
		var e := Vector3(cos(a), 0.0, sin(a)) * 0.8
		k.push(e * 0.5, Vector3(0, rad_to_deg(atan2(e.x, e.z)), 0))
		k.lathe("plastic", [Vector2(0.025, -0.4), Vector2(0.025, 0.4)], Vector3.ZERO, Vector3(90, 0, 0), 6)
		k.pop()
		k.lathe("dark", [Vector2(0, -0.04), Vector2(0.045, -0.04), Vector2(0.045, 0.04), Vector2(0, 0.05)], e, Vector3.ZERO, 8)
		hubs.append([e + Vector3(0, 0.06, 0), Vector3.ZERO])
	for sx in [-1.0, 1.0]:
		k.box("plastic", Vector3(0.02, 0.3, 0.02), Vector3(0.18 * sx, -0.2, 0), Vector3(0, 0, 12 * sx))
		k.box("plastic", Vector3(0.025, 0.025, 0.55), Vector3(0.21 * sx, -0.34, 0))
	_bomb(k, Vector3(0, -0.2, -0.22), 0.45, 0.07)
	_prop(pk, 2, 0.36, 0.05)
	k.pop()
	pk.pop()
	return _hubs(s, hubs)


## Orlan-10 / Orbiter / Ababil / Uqab: yüksek kanatlı, burnunda pervane olan küçük keşif uçağı.
static func _orlan(k: Kit, pk: Kit) -> Array:
	var s := 0.7
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_pod(k, "skin", [[0.85, 0.06, 0.06, 0.06], [0.7, 0.12, 0.12, 0.12], [0.2, 0.13, 0.15, 0.13], [-0.3, 0.08, 0.1, 0.08], [-0.5, 0.04, 0.05, 0.04]], 0.0)
	_boom(k, "skin", 0.0, 0.02, -0.4, -1.45, 0.035)
	_slab(k, "skin", [Vector2(0.05, 0.28), Vector2(1.55, 0.22), Vector2(1.55, 0.0), Vector2(0.05, -0.05)], 0.16, 0.04, 0.025, 2.0)
	_slab(k, "skin", [Vector2(0.03, -1.2), Vector2(0.45, -1.28), Vector2(0.45, -1.42), Vector2(0.03, -1.45)], 0.03, 0.02, 0.015, 0.0)
	_fin(k, "skin", [Vector2(-1.15, 0.04), Vector2(-1.35, 0.4), Vector2(-1.45, 0.4), Vector2(-1.45, 0.04)], 0.0, 0.0, 0.02)
	_eo(k, Vector3(0, -0.15, 0.35), 0.07)
	for sx in [-1.0, 1.0]:
		_mark(k, Vector3(1.0 * sx, 0.2, 0.11), 0.09)
		k.box("team", Vector3(0.12, 0.03, 0.24), Vector3(1.49 * sx, 0.175, 0.11))
	k.lathe("dark", [Vector2(0.06, 0), Vector2(0.06, 0.05), Vector2(0, 0.06)], Vector3(0, 0, 0.84), Vector3(90, 0, 0), 8)
	_prop(pk, 2, 0.32, 0.05)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, 0.9), Vector3(90, 0, 0)]])


## Lancet-3 / Hero / Meraj / Nagastra: boru gövde, önde ve arkada X kanatlar, arkada itici pervane.
static func _lancet(k: Kit, pk: Kit) -> Array:
	var s := 1.0
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_pod(k, "skin", [[0.85, 0.02, 0.02, 0.02], [0.68, 0.075, 0.075, 0.075], [-0.6, 0.075, 0.075, 0.075], [-0.75, 0.05, 0.05, 0.05]], 0.0)
	k.lathe("glass", [Vector2(0.075, 0), Vector2(0.06, 0.06), Vector2(0, 0.09)], Vector3(0, 0, 0.7), Vector3(90, 0, 0), 10)
	for a in [45.0, -45.0]:
		k.push(Vector3.ZERO, Vector3(0, 0, a))
		_slab(k, "skin", [Vector2(0.06, 0.35), Vector2(0.62, 0.2), Vector2(0.62, 0.05), Vector2(0.06, 0.05)], 0.0, 0.02, 0.012, 0.0)
		_slab(k, "skin", [Vector2(0.06, -0.38), Vector2(0.5, -0.48), Vector2(0.5, -0.6), Vector2(0.06, -0.62)], 0.0, 0.02, 0.012, 0.0)
		k.pop()
	k.push(Vector3.ZERO, Vector3(0, 0, 45))
	k.box("team", Vector3(0.22, 0.026, 0.12), Vector3(0.5, 0.0, 0.14))
	k.box("team", Vector3(0.22, 0.026, 0.12), Vector3(-0.5, 0.0, 0.14))
	k.pop()
	_prop(pk, 2, 0.17, 0.035)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -0.8), Vector3(90, 0, 0)]])


## Shahed-136 / Geran-2 (sc 0.85), Shahed-131 (sc 0.5): delta kanat, kanat uçlarında dikey yüzeyler, arkada pervane.
static func _shahed(k: Kit, pk: Kit, sc: float) -> Array:
	k.push(Vector3.ZERO, Vector3.ZERO, sc)
	pk.push(Vector3.ZERO, Vector3.ZERO, sc)
	_pod(k, "skin", [[1.75, 0.03, 0.03, 0.03], [1.5, 0.13, 0.12, 0.11], [1.0, 0.18, 0.17, 0.14], [-1.3, 0.18, 0.18, 0.14], [-1.6, 0.12, 0.12, 0.1]], 0.02)
	_slab(k, "skin", [Vector2(0.15, 1.3), Vector2(1.25, -1.0), Vector2(1.25, -1.45), Vector2(0.15, -1.45)], 0.0, 0.08, 0.035, 0.0)
	for sx in [-1.0, 1.0]:
		_fin(k, "skin", [Vector2(-0.85, -0.18), Vector2(-1.1, 0.38), Vector2(-1.45, 0.38), Vector2(-1.45, -0.18)], 1.27 * sx, 0.0, 0.03)
		_fin(k, "team", [Vector2(-1.03, 0.2), Vector2(-1.1, 0.38), Vector2(-1.45, 0.38), Vector2(-1.45, 0.2)], 1.27 * sx, 0.0, 0.04)
		_mark(k, Vector3(0.7 * sx, 0.05, -0.6), 0.16)
	k.lathe("dark", [Vector2(0.12, 0), Vector2(0.1, 0.2), Vector2(0.03, 0.25)], Vector3(0, 0.02, -1.6), Vector3(-90, 0, 0), 10)
	k.lathe("radome", [Vector2(0, -0.01), Vector2(0.13, 0.0), Vector2(0.03, 0.25)], Vector3(0, 0.02, 1.5), Vector3(90, 0, 0), 10)
	_prop(pk, 2, 0.38, 0.06)
	k.pop()
	pk.pop()
	return _hubs(sc, [[Vector3(0, 0.02, -1.88), Vector3(90, 0, 0)]])


## Harop: önde kanard, arkada kanat uçları dikey yüzeyli ok kanat, itici pervane.
static func _harop(k: Kit, pk: Kit) -> Array:
	var s := 1.0
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_pod(k, "skin", [[1.35, 0.03, 0.03, 0.03], [1.15, 0.13, 0.13, 0.12], [0.5, 0.17, 0.19, 0.15], [-0.85, 0.16, 0.16, 0.13], [-1.1, 0.1, 0.1, 0.09]], 0.0)
	_slab(k, "skin", [Vector2(0.12, 0.25), Vector2(1.45, -0.75), Vector2(1.45, -1.0), Vector2(0.12, -1.0)], 0.04, 0.06, 0.03, 0.0)
	_slab(k, "skin", [Vector2(0.12, 1.02), Vector2(0.4, 0.86), Vector2(0.4, 0.78), Vector2(0.12, 0.78)], 0.06, 0.025, 0.015, 0.0)
	for sx in [-1.0, 1.0]:
		_fin(k, "skin", [Vector2(-0.7, 0.06), Vector2(-0.88, 0.42), Vector2(-1.02, 0.42), Vector2(-1.0, 0.06)], 1.47 * sx, 0.0, 0.025)
		_fin(k, "team", [Vector2(-0.84, 0.32), Vector2(-0.88, 0.42), Vector2(-1.02, 0.42), Vector2(-1.015, 0.32)], 1.47 * sx, 0.0, 0.035)
		_mark(k, Vector3(0.85 * sx, 0.08, -0.55), 0.13)
	_eo(k, Vector3(0, -0.15, 1.0), 0.07)
	_prop(pk, 2, 0.32, 0.05)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -1.15), Vector3(90, 0, 0)]])


# ---------------------------------------------------------------- büyük İHA'lar

## İki kirişli, itici pervaneli İHA gövdesi. Ortak: gövde, düz kanat, kirişler, kamera, işaretler.
## span: kanat açıklığı, ln: gövde boyu, bx: kirişlerin x'i, wy: kanat yüksekliği, tz: kirişlerin bittiği z.
static func _twin(k: Kit, span: float, ln: float, bx: float, wy: float, tz: float, chord: float) -> void:
	var hz := ln * 0.5
	_pod(k, "skin", [[hz, 0.06, 0.06, 0.06], [hz - 0.4, 0.28, 0.3, 0.26], [hz - 1.3, 0.36, 0.4, 0.34], [0.0, 0.34, 0.37, 0.3],
		[-hz * 0.7, 0.24, 0.25, 0.2], [-hz + 0.1, 0.12, 0.13, 0.12]], 0.0)
	_slab(k, "skin", [Vector2(0.2, chord * 0.65), Vector2(span * 0.5, chord * 0.45), Vector2(span * 0.5, -chord * 0.15), Vector2(0.2, -chord * 0.35)],
		wy, 0.16, 0.06, 1.5)
	for sx in [-1.0, 1.0]:
		_boom(k, "skin", bx * sx, wy - 0.05, chord * 0.55, tz, 0.08)
		_mark(k, Vector3(span * 0.33 * sx, wy + 0.1 + span * 0.33 * 0.026, chord * 0.15), minf(0.45, chord * 0.3))
		k.box("team", Vector3(0.35, 0.05, chord * 0.62), Vector3((span * 0.5 - 0.2) * sx, wy + 0.05 + (span * 0.5 - 0.2) * 0.026, chord * 0.15))
		k.lathe("bomb", [Vector2(0, 0), Vector2(0.05, 0.1), Vector2(0.06, 0.7), Vector2(0, 0.95)], Vector3(span * 0.22 * sx, wy - 0.3, -0.3), Vector3(90, 0, 0), 8)
		k.box("skin2", Vector3(0.04, 0.2, 0.4), Vector3(span * 0.22 * sx, wy - 0.14, chord * 0.15))
	_eo(k, Vector3(0, -0.42, hz - 0.8), 0.17)
	k.lathe("dark", [Vector2(0.14, 0), Vector2(0.1, 0.12), Vector2(0, 0.16)], Vector3(0, 0, -hz + 0.1), Vector3(-90, 0, 0), 8)


## Bayraktar TB2: iki kirişi birleştiren ters V kuyruk (tepesi ortada), aralarında itici pervane.
static func _tb2(k: Kit, pk: Kit) -> Array:
	var s := 0.45
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_twin(k, 12.0, 6.5, 1.15, 0.3, -2.9, 0.9)
	for sx in [-1.0, 1.0]:
		# kiriş ucundan yukarı ve içe doğru yükselip ortada birleşen yüzey
		k.push(Vector3(1.15 * sx, 0.25, 0), Vector3(0, 0, 50 * sx))
		k.loft("skin", [
			[Vector3(-0.025, 0.0, -2.2), Vector3(-0.025, 0.0, -2.95), Vector3(-0.025, 1.5, -3.05), Vector3(-0.025, 1.5, -2.55)],
			[Vector3(0.025, 0.0, -2.2), Vector3(0.025, 0.0, -2.95), Vector3(0.025, 1.5, -3.05), Vector3(0.025, 1.5, -2.55)],
		])
		k.pop()
	_prop(pk, 2, 0.8, 0.13)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -3.35), Vector3(90, 0, 0)]])


## Kirişlerin sonunda iki dikey kuyruk ve aralarında yatay dengeleyici (Heron, Mohajer-6, Liutyi).
static func _htail(k: Kit, bx: float, y: float, z: float, fh: float, ch: float) -> void:
	for sx in [-1.0, 1.0]:
		_fin(k, "skin", [Vector2(z + ch * 0.3, y), Vector2(z - ch * 0.35, y + fh), Vector2(z - ch * 0.75, y + fh), Vector2(z - ch * 0.7, y)], bx * sx, 0.0, 0.06)
		_fin(k, "team", [Vector2(z - ch * 0.29, y + fh * 0.82), Vector2(z - ch * 0.35, y + fh), Vector2(z - ch * 0.75, y + fh), Vector2(z - ch * 0.74, y + fh * 0.82)], bx * sx, 0.0, 0.075)
	k.box("skin", Vector3(bx * 2.0 + 0.1, 0.06, ch * 0.75), Vector3(0, y + fh * 0.55, z - ch * 0.35))


## IAI Heron / Heron TP: uzun kanat, iki kiriş, H kuyruk, burun üstünde uydu anteni kamburu.
static func _heron(k: Kit, pk: Kit) -> Array:
	var s := 0.42
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_twin(k, 16.6, 8.5, 1.6, 0.35, -4.4, 1.0)
	_pod(k, "skin", [[3.6, 0.1, 0.05, 0.05], [3.0, 0.32, 0.25, 0.05], [1.8, 0.3, 0.22, 0.05], [1.0, 0.1, 0.05, 0.05]], 0.3)
	_htail(k, 1.6, 0.3, -3.9, 1.2, 1.0)
	_prop(pk, 2, 0.95, 0.15)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -4.4), Vector3(90, 0, 0)]])


## Mohajer-6: daha kısa gövde, yüksek kanat, kirişlerin üstünde yatay dengeleyici.
static func _mohajer(k: Kit, pk: Kit) -> Array:
	var s := 0.5
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_twin(k, 10.0, 5.6, 1.1, 0.32, -2.9, 0.85)
	_htail(k, 1.1, 0.3, -2.45, 0.85, 0.8)
	_prop(pk, 2, 0.7, 0.12)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -2.95), Vector3(90, 0, 0)]])


## AN-196 Liutyi: alçak kanat, iki kiriş, arkada üç kanatlı itici pervane, burnu harp başlıklı.
static func _liutyi(k: Kit, pk: Kit) -> Array:
	var s := 0.55
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_twin(k, 6.7, 4.4, 0.85, -0.18, -2.3, 0.75)
	_htail(k, 0.85, -0.18, -1.9, 0.75, 0.6)
	_prop(pk, 3, 0.55, 0.1)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -2.3), Vector3(90, 0, 0)]])


## MQ-9 / Hermes 900 / Orion / Shahed-129 / Burraq: uzun ince gövde, burun üstü kambur, çok uzun kanat,
## V kuyruk ve altta dikey yüzey, arkada itici pervane.
static func _mq9(k: Kit, pk: Kit) -> Array:
	var s := 0.32
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_pod(k, "skin", [[5.6, 0.1, 0.1, 0.1], [5.1, 0.42, 0.5, 0.35], [4.0, 0.48, 0.62, 0.4], [2.5, 0.45, 0.45, 0.42], [0.0, 0.42, 0.42, 0.4],
		[-3.5, 0.25, 0.25, 0.25], [-4.8, 0.14, 0.14, 0.14]], 0.0)
	_slab(k, "skin", [Vector2(0.3, 0.75), Vector2(10.0, 0.35), Vector2(10.0, -0.15), Vector2(0.3, -0.45)], 0.2, 0.22, 0.07, 1.0)
	for sx in [-1.0, 1.0]:
		_fin(k, "skin", [Vector2(-3.3, 0.2), Vector2(-4.3, 2.0), Vector2(-4.8, 2.0), Vector2(-4.7, 0.2)], 0.15 * sx, 45.0 * sx, 0.08)
		_fin(k, "team", [Vector2(-4.12, 1.65), Vector2(-4.3, 2.0), Vector2(-4.8, 2.0), Vector2(-4.78, 1.65)], 0.15 * sx, 45.0 * sx, 0.1)
		_mark(k, Vector3(6.0 * sx, 0.35, 0.15), 0.4)
		for f in [0.3, 0.5]:
			var x: float = 10.0 * f * sx
			k.box("skin2", Vector3(0.06, 0.25, 0.5), Vector3(x, 0.03, 0.2))
			k.lathe("bomb", [Vector2(0, 0), Vector2(0.09, 0.0), Vector2(0.09, 1.3), Vector2(0, 1.6)], Vector3(x, -0.18, -0.6), Vector3(90, 0, 0), 8)
	_fin(k, "skin", [Vector2(-3.8, -0.15), Vector2(-4.4, -1.2), Vector2(-4.75, -1.2), Vector2(-4.7, -0.15)], 0.0, 0.0, 0.08)
	_eo(k, Vector3(0, -0.5, 4.3), 0.25)
	_prop(pk, 3, 1.3, 0.2)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(0, 0, -4.95), Vector3(90, 0, 0)]])


## Bayraktar Akıncı: uzun gövde, uçları bükük uzun kanat, kanatlarda iki turboprop motor (çekici pervane), V kuyruk.
static func _akinci(k: Kit, pk: Kit) -> Array:
	var s := 0.36
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	pk.push(Vector3.ZERO, Vector3.ZERO, s)
	_pod(k, "skin", [[6.1, 0.1, 0.1, 0.1], [5.4, 0.5, 0.5, 0.45], [4.0, 0.62, 0.65, 0.55], [0.0, 0.6, 0.6, 0.55], [-4.0, 0.35, 0.35, 0.3],
		[-6.0, 0.15, 0.15, 0.15]], 0.0)
	k.lathe("glass", [Vector2(0.3, 0), Vector2(0.2, 0.25), Vector2(0, 0.35)], Vector3(0, 0.45, 4.6), Vector3(90, 0, 0), 10)
	_slab(k, "skin", [Vector2(0.4, 1.2), Vector2(7.0, 0.7), Vector2(7.0, -0.35), Vector2(0.4, -0.7)], 0.1, 0.32, 0.16, 2.0)
	for sx in [-1.0, 1.0]:
		# bükük dış kanat parçası
		k.push(Vector3(7.0 * sx, 0.1 + 6.6 * 0.035, 0), Vector3(0, 0, 9.0 * sx))
		k.loft("skin", [
			[Vector3(0, -0.06, 0.7), Vector3(0, -0.06, -0.35), Vector3(3.0 * sx, -0.04, -0.2), Vector3(3.0 * sx, -0.04, 0.4)],
			[Vector3(0, 0.1, 0.7), Vector3(0, 0.1, -0.35), Vector3(3.0 * sx, 0.04, -0.2), Vector3(3.0 * sx, 0.04, 0.4)],
		])
		k.box("team", Vector3(0.6, 0.1, 0.62), Vector3(2.6 * sx, 0.0, 0.1))
		k.pop()
		# motor naseli
		k.loft("skin2", [_ring(2.35, 2.6 * sx, 0.1, 0.28, 0.32, 0.3, 10), _ring(1.8, 2.6 * sx, 0.1, 0.34, 0.38, 0.36, 10),
			_ring(-0.3, 2.6 * sx, 0.1, 0.32, 0.36, 0.3, 10), _ring(-1.3, 2.6 * sx, 0.15, 0.1, 0.1, 0.1, 10)], true)
		_mark(k, Vector3(4.6 * sx, 0.31, 0.2), 0.42)
		for f in [0.38, 0.62]:
			var x: float = 7.0 * f * sx
			k.box("skin2", Vector3(0.08, 0.3, 0.6), Vector3(x, -0.08, 0.2))
			k.lathe("bomb", [Vector2(0, 0), Vector2(0.11, 0.1), Vector2(0.13, 1.4), Vector2(0, 1.8)], Vector3(x, -0.35, -0.6), Vector3(90, 0, 0), 8)
		_fin(k, "skin", [Vector2(-4.3, 0.3), Vector2(-5.4, 2.1), Vector2(-6.0, 2.1), Vector2(-5.9, 0.3)], 0.2 * sx, 40.0 * sx, 0.1)
		_fin(k, "team", [Vector2(-5.18, 1.75), Vector2(-5.4, 2.1), Vector2(-6.0, 2.1), Vector2(-5.98, 1.75)], 0.2 * sx, 40.0 * sx, 0.12)
	_eo(k, Vector3(0, -0.62, 4.8), 0.3)
	_prop(pk, 4, 1.2, 0.2)
	k.pop()
	pk.pop()
	return _hubs(s, [[Vector3(2.6, 0.1, 2.45), Vector3(90, 0, 0)], [Vector3(-2.6, 0.1, 2.45), Vector3(90, 0, 0)]])


## S-70 Okhotnik-B / Ghatak: kuyruksuz uçan kanat, sırtında hava alığı, arkada tek jet lülesi.
static func _flyingwing(k: Kit, pk: Kit) -> Array:
	var s := 0.34
	k.push(Vector3.ZERO, Vector3.ZERO, s)
	_slab(k, "stealth", [Vector2(0.0, 7.0), Vector2(3.4, 3.0), Vector2(3.4, -4.2), Vector2(0.0, -5.8)], 0.0, 1.0, 0.7, 0.0)
	_slab(k, "stealth", [Vector2(3.4, 3.0), Vector2(9.9, -2.4), Vector2(9.4, -3.6), Vector2(3.4, -4.2)], 0.0, 0.7, 0.18, 0.0)
	k.loft("stealth", [_ring(5.5, 0.0, 0.3, 0.6, 0.15, 0.1, 8), _ring(3.0, 0.0, 0.3, 1.1, 0.55, 0.1, 8), _ring(-2.5, 0.0, 0.3, 1.0, 0.5, 0.1, 8),
		_ring(-5.0, 0.0, 0.3, 0.6, 0.2, 0.1, 8)])
	k.box("dark", Vector3(1.1, 0.35, 0.05), Vector3(0, 0.62, 3.6), Vector3(-30, 0, 0))
	k.lathe("dark", [Vector2(0.5, 0), Vector2(0.45, 0.6), Vector2(0.38, 0.6), Vector2(0, 0.3)], Vector3(0, 0.25, -5.2), Vector3(-90, 0, 0), 10)
	for sx in [-1.0, 1.0]:
		_mark(k, Vector3(6.0 * sx, 0.52, -1.6), 0.5)
	_slab(k, "team", [Vector2(8.9, -1.85), Vector2(9.9, -2.4), Vector2(9.4, -3.6), Vector2(8.9, -3.4)], 0.02, 0.26, 0.22, 0.0)
	k.pop()
	return []
