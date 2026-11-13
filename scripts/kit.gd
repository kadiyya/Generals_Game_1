class_name Kit
extends RefCounted
## Araç modelleri için mesh kurucusu. Parçalar (kutu, kesit dizisi, döner profil, palet bandı) üçgen olarak
## eklenir ve malzemeye göre gruplanır: model kaç parçadan oluşursa oluşsun malzeme başına tek yüzey çizilir.
## Renk köşe rengine yazılır: alt kısımlar gölgelenir ve çamurlanır, üste bakan yüzeyler tozlanır, her parçanın
## boyası biraz farklı tondadır. Böylece bütün araçlar aynı birkaç malzemeyi paylaşır.
## Tasarımlar gerçek ölçüyle (metre) yazılır; push() ile verilen ölçek oyundaki boyuta indirir.

# tür: [texture, döşeme boyu (oyun birimi), pürüzlülük, metalik]
const MATS := {
	"armor": ["armor", 2.4, 0.6, 0.0],
	"steel": ["steel", 1.2, 0.6, 0.2],
	"track": ["track", 1.0, 0.7, 0.25],
	"fabric": ["fabric", 0.9, 0.95, 0.0],
	"paint": ["skin", 3.0, 0.42, 0.12],
	"concrete": ["concrete", 2.6, 0.9, 0.0],
	"corrug": ["corrug", 1.0, 0.55, 0.25],
	"optic": ["", 1.0, 0.12, 0.3],
	"emit": ["", 1.0, 1.0, 0.0],
	"camo_ru": ["air_ru", 3.2, 0.36, 0.2],
	"camo_desert": ["air_desert", 3.2, 0.42, 0.15],
	"camo_il": ["air_il", 3.2, 0.42, 0.15],
	"camo_split": ["air_split", 3.2, 0.36, 0.2],
}

static var _mats := {}

var dust := Color(0.55, 0.5, 0.4)
var grounded := true   # yer aracı: alt kısım çamurlanır ve gölgelenir. Hava araçlarında kapalı.
var soot := Vector3.ZERO   # hava aracı egzoz isi: z, soot.x'ten geriye soot.y'ye doğru kararır; |x| < soot.z şeridinde (z 0 ise yok)
var _slots := {}      # yuva adı -> [malzeme türü, renk, toz oranı]
var _surf := {}       # malzeme türü -> [köşeler, normaller, renkler, uv]
var _xf := Transform3D.IDENTITY
var _nb := Basis.IDENTITY   # normaller için ters-devrik dönüşüm (eksen başına ölçekte normaller doğru kalsın)
var _scale := 1.0
var _stack: Array = []
var _seed := 12345
var _tint := 1.0
var _parts := {}      # parça adı -> [yüzeyler, eksen merkezi, eksen]: ayrı mesh olur, oyunda oynatılır
var _main := {}
var _pivot := Vector3.ZERO


## Bir renk yuvası tanımlar. dusty: kirlenme oranı (0 = hiç, 1 = alt kısmı tamamen çamur rengine döner).
func slot(name: String, kind: String, c: Color, dusty := 0.5) -> void:
	_slots[name] = [kind, c, dusty]


## Sonraki parçalar bu konum, döndürme (derece) ve ölçekle yerleştirilir. pop() ile geri alınır.
func push(pos: Vector3, rot := Vector3.ZERO, scale := 1.0) -> void:
	_stack.append([_xf, _scale, _nb])
	var r := Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))
	_xf = _xf * Transform3D(Basis.from_euler(r) * scale, pos)
	_nb = _nb * Basis.from_euler(r)
	_scale *= scale


## Eksen başına ölçek: oranları stilize etmek için (ör. gövdeyi ve kanatları biraz genişletmek). pop() ile geri alınır.
func push_scale(v: Vector3) -> void:
	_stack.append([_xf, _scale, _nb])
	_xf = _xf * Transform3D(Basis.from_scale(v), Vector3.ZERO)
	_nb = _nb * Basis.from_scale(Vector3(1.0 / v.x, 1.0 / v.y, 1.0 / v.z))


func pop() -> void:
	var s: Array = _stack.pop_back()
	_xf = s[0]
	_scale = s[1]
	_nb = s[2]


## Hareketli parça başlatır: bundan sonraki üçgenler ayrı bir mesh'e gider. pivot ve axis yerel koordinatta
## verilir (dönme merkezi ve ekseni); end_part() ile ana gövdeye dönülür.
func begin_part(name: String, pivot: Vector3, axis: Vector3) -> void:
	var pv := _xf * pivot
	var ax := (_xf.basis * axis).normalized()
	if not _parts.has(name):
		_parts[name] = [{}, pv, ax]
	_main = _surf
	_surf = _parts[name][0]
	_pivot = pv


func end_part() -> void:
	_surf = _main
	_pivot = Vector3.ZERO


## Hareketli parçalar: [ad, mesh, merkez, eksen] listesi. Mesh köşeleri merkeze göredir.
func part_meshes() -> Array:
	var out: Array = []
	for name in _parts:
		var p: Array = _parts[name]
		out.append([name, _build(p[0]), p[1], p[2]])
	return out


# ---------------------------------------------------------------- parçalar

## Kutu: size boyutlarında, pos merkezli, rot derece döndürülmüş.
func box(s: String, size: Vector3, pos: Vector3, rot := Vector3.ZERO) -> void:
	var h := size * 0.5
	push(pos, rot)
	loft(s, [
		[Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(-h.x, h.y, -h.z)],
		[Vector3(-h.x, -h.y, h.z), Vector3(h.x, -h.y, h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)],
	])
	pop()


## Kesitleri sırayla birleştirir ve iki ucu kapatır. Kesitler aynı sayıda köşeli, aynı sırada dolaşılan
## dışbükey çokgenlerdir; bütün cisim de dışbükey olmalıdır. smooth: kesit çevresinde normaller yumuşatılır.
## round: kesitler arasında da yumuşatılır (gövde, kanopi gibi kesintisiz yüzeyler).
func loft(s: String, rings: Array, smooth := false, round := false) -> void:
	_vary()
	var ctr := Vector3.ZERO
	var cnt := 0
	for r in rings:
		for p in r:
			ctr += p
			cnt += 1
	ctr /= float(cnt)
	var m: int = rings[0].size()
	var bands: Array = []
	for i in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var fns: Array = []
		for j in m:
			var a: Vector3 = r0[j]
			var b: Vector3 = r0[(j + 1) % m]
			var c: Vector3 = r1[(j + 1) % m]
			var d: Vector3 = r1[j]
			var fn := (c - a).cross(d - b)
			if fn.length_squared() < 1e-14:
				fn = (b - a).cross(d - a)
			fn = fn.normalized()
			if fn.dot((a + b + c + d) * 0.25 - ctr) < 0.0:
				fn = -fn
			fns.append(fn)
		bands.append(fns)
	for i in rings.size() - 1:
		var r0: Array = rings[i]
		var r1: Array = rings[i + 1]
		var fns: Array = bands[i]
		for j in m:
			var a: Vector3 = r0[j]
			var b: Vector3 = r0[(j + 1) % m]
			var c: Vector3 = r1[(j + 1) % m]
			var d: Vector3 = r1[j]
			var na: Vector3 = fns[j]
			var nb: Vector3 = fns[j]
			var nc: Vector3 = fns[j]
			var nd: Vector3 = fns[j]
			if round:
				na = _vnorm(bands, i, j, m)
				nb = _vnorm(bands, i, j + 1, m)
				nc = _vnorm(bands, i + 1, j + 1, m)
				nd = _vnorm(bands, i + 1, j, m)
			elif smooth:
				na = (fns[(j - 1 + m) % m] + fns[j]).normalized()
				nb = (fns[j] + fns[(j + 1) % m]).normalized()
				nc = nb
				nd = na
			_emit(s, [a, b, c], [na, nb, nc], [])
			_emit(s, [a, c, d], [na, nc, nd], [])
	_cap(s, rings[0], ctr)
	_cap(s, rings[rings.size() - 1], ctr)


## Kesit ri'deki j köşesinin normali: çevresindeki dört yüzün ortalaması.
func _vnorm(bands: Array, ri: int, j: int, m: int) -> Vector3:
	var n := Vector3.ZERO
	for b in [ri - 1, ri]:
		if b >= 0 and b < bands.size():
			var f: Array = bands[b]
			n += f[(j - 1 + m) % m] + f[j % m]
	return n.normalized()


## Döner cisim: profil noktaları (yarıçap, yükseklik), alttan üste dış yüzey boyunca sıralı.
## Yerel Y ekseni etrafında döndürülür; rot ile eksen istenen yöne çevrilir.
func lathe(s: String, prof: Array, pos: Vector3, rot := Vector3.ZERO, sides := 10) -> void:
	push(pos, rot)
	_vary()
	var rmax := 0.0
	for p in prof:
		rmax = maxf(rmax, p.x)
	for i in prof.size() - 1:
		var p0: Vector2 = prof[i]
		var p1: Vector2 = prof[i + 1]
		var dn := Vector2(p1.y - p0.y, p0.x - p1.x).normalized()
		for j in sides:
			var a0 := TAU * j / sides
			var a1 := TAU * (j + 1) / sides
			var c0 := Vector3(cos(a0), 0.0, sin(a0))
			var c1 := Vector3(cos(a1), 0.0, sin(a1))
			var v00 := c0 * p0.x + Vector3(0.0, p0.y, 0.0)
			var v01 := c1 * p0.x + Vector3(0.0, p0.y, 0.0)
			var v11 := c1 * p1.x + Vector3(0.0, p1.y, 0.0)
			var v10 := c0 * p1.x + Vector3(0.0, p1.y, 0.0)
			var n0 := c0 * dn.x + Vector3(0.0, dn.y, 0.0)
			var n1 := c1 * dn.x + Vector3(0.0, dn.y, 0.0)
			var u0 := a0 * rmax * _scale
			var u1 := a1 * rmax * _scale
			var t00 := Vector2(u0, p0.y * _scale)
			var t01 := Vector2(u1, p0.y * _scale)
			var t11 := Vector2(u1, p1.y * _scale)
			var t10 := Vector2(u0, p1.y * _scale)
			_emit(s, [v00, v01, v11], [n0, n1, n1], [t00, t01, t11])
			_emit(s, [v00, v11, v10], [n0, n1, n0], [t00, t11, t10])
	pop()


## Palet bandı. path: (z, y) noktalarından kapalı yol; alt kol öne (+z) doğru gidecek sırada verilir.
## x: bandın orta çizgisi, w: genişlik, t: kalınlık, link: bir baklanın boyu.
func belt(s: String, path: Array, x: float, w: float, t: float, link: float) -> void:
	var m := path.size()
	var nrm: Array = []
	for i in m:
		var p0: Vector2 = path[(i - 1 + m) % m]
		var p1: Vector2 = path[i]
		var p2: Vector2 = path[(i + 1) % m]
		var d0 := (p1 - p0).normalized()
		var d1 := (p2 - p1).normalized()
		nrm.append((Vector2(d0.y, -d0.x) + Vector2(d1.y, -d1.x)).normalized())
	var x0 := x - w * 0.5
	var x1 := x + w * 0.5
	var u := 0.0
	var rep := link * 8.0     # texture'da 8 bakla var
	for i in m:
		var j := (i + 1) % m
		var a: Vector2 = path[i]
		var b: Vector2 = path[j]
		var na: Vector2 = nrm[i]
		var nb: Vector2 = nrm[j]
		var sd := (b - a).normalized()
		var sn := Vector3(0.0, -sd.x, sd.y)
		var ao := a + na * t * 0.5
		var ai := a - na * t * 0.5
		var bo := b + nb * t * 0.5
		var bi := b - nb * t * 0.5
		var u0 := u / rep
		var u1 := (u + a.distance_to(b)) / rep
		u += a.distance_to(b)
		# dış yüz (zemine basan yüz), iç yüz, iki yan
		_quad_uv(s, Vector3(x0, ao.y, ao.x), Vector3(x0, bo.y, bo.x), Vector3(x1, bo.y, bo.x), Vector3(x1, ao.y, ao.x),
			sn, Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 1.0), Vector2(u0, 1.0))
		_quad_uv(s, Vector3(x0, ai.y, ai.x), Vector3(x0, bi.y, bi.x), Vector3(x1, bi.y, bi.x), Vector3(x1, ai.y, ai.x),
			-sn, Vector2(u0, 0.3), Vector2(u1, 0.3), Vector2(u1, 0.7), Vector2(u0, 0.7))
		for e in [[x0, -1.0], [x1, 1.0]]:
			var ex: float = e[0]
			_quad_uv(s, Vector3(ex, ao.y, ao.x), Vector3(ex, bo.y, bo.x), Vector3(ex, bi.y, bi.x), Vector3(ex, ai.y, ai.x),
				Vector3(e[1], 0.0, 0.0), Vector2(u0, 0.0), Vector2(u1, 0.0), Vector2(u1, 0.06), Vector2(u0, 0.06))


# ---------------------------------------------------------------- iç işler

## Her parçaya biraz farklı boya tonu (tekrarlanabilir sözde rastgele).
func _vary() -> void:
	_seed = (_seed * 1103515245 + 12345) % 2147483648
	_tint = 0.93 + 0.12 * float(_seed) / 2147483648.0


func _quad_uv(s: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3,
		ta: Vector2, tb: Vector2, tc: Vector2, td: Vector2) -> void:
	_emit(s, [a, b, c], [n, n, n], [ta, tb, tc])
	_emit(s, [a, c, d], [n, n, n], [ta, tc, td])


func _cap(s: String, ring: Array, ctr: Vector3) -> void:
	var m := ring.size()
	var nn := Vector3.ZERO
	var mid := Vector3.ZERO
	for i in m:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % m]
		nn += a.cross(b)
		mid += a
	mid /= float(m)
	if nn.length_squared() < 1e-12:
		return
	nn = nn.normalized()
	if nn.dot(mid - ctr) < 0.0:
		nn = -nn
	for i in range(1, m - 1):
		_emit(s, [ring[0], ring[i], ring[i + 1]], [nn, nn, nn], [])


## Üçgeni dönüşümden geçirip yuvanın malzeme grubuna ekler. uv boşsa kutu izdüşümüyle üretilir.
func _emit(s: String, p: Array, n: Array, uv: Array) -> void:
	var sl: Array = _slots[s]
	var kind: String = sl[0]
	var w: Array = []
	var wn: Array = []
	for i in 3:
		w.append(_xf * (p[i] as Vector3))
		wn.append((_nb * (n[i] as Vector3)).normalized())
	var a: Vector3 = w[0]
	var face: Vector3 = (w[1] - a).cross(w[2] - a)
	if face.length_squared() < 1e-14:
		return
	if not _surf.has(kind):
		_surf[kind] = [[], [], [], []]
	var dst: Array = _surf[kind]
	var avg: Vector3 = wn[0] + wn[1] + wn[2]
	var fn := face.normalized()
	# Godot'da ön yüz saat yönünde sıralanır.
	var order := [0, 1, 2]
	if fn.dot(avg) > 0.0:
		order = [0, 2, 1]
	else:
		fn = -fn
	var ax := absf(fn.x)
	var ay := absf(fn.y)
	var az := absf(fn.z)
	for i in order:
		var q: Vector3 = w[i]
		dst[0].append(q - _pivot)
		dst[1].append(wn[i])
		dst[2].append(_shade(sl, q, wn[i]))
		if not uv.is_empty():
			dst[3].append(uv[i])
		elif ax >= ay and ax >= az:
			dst[3].append(Vector2(q.z, -q.y))
		elif ay >= az:
			dst[3].append(Vector2(q.z, q.x))
		else:
			dst[3].append(Vector2(q.x, -q.y))


## Köşe rengi: parça tonu, alt kısımlarda koyu çamur, üste bakan yüzeylerde açık toz, aşağı doğru gölge.
func _shade(sl: Array, q: Vector3, n: Vector3) -> Color:
	var c: Color = sl[1]
	var k: float = sl[2]
	var top := clampf(n.y, 0.0, 1.0)
	if sl[0] == "emit":
		return c
	if not grounded:
		var lit := (0.88 + 0.12 * top - 0.3 * clampf(-n.y, 0.0, 1.0)) * _tint
		if soot.z > 0.0:
			var sk := clampf((soot.x - q.z) / (soot.x - soot.y), 0.0, 1.0)
			sk *= 1.0 - smoothstep(soot.z * 0.6, soot.z, absf(q.x))
			lit *= 1.0 - 0.55 * sk * sk
		return Color(c.r * lit, c.g * lit, c.b * lit)
	var low := 1.0 - smoothstep(0.0, 0.62, q.y)
	var mud := Color(dust.r * 0.5, dust.g * 0.43, dust.b * 0.34)
	c = Color(c.r * _tint, c.g * _tint, c.b * _tint)
	c = c.lerp(mud, clampf(k * low * 1.25, 0.0, 1.0))
	c = c.lerp(dust, clampf(k * top * top * 0.55 * (1.0 - low), 0.0, 1.0))
	# gökyüzünü gören üst yüzeyler açık, yanlar biraz, alta bakanlar çok koyu; gövdenin altı gölgede
	var ao := lerpf(0.48, 1.0, smoothstep(0.0, 0.9, q.y))
	ao *= 0.86 + 0.14 * top - 0.32 * clampf(-n.y, 0.0, 1.0)
	return Color(c.r * ao, c.g * ao, c.b * ao)


func is_empty() -> bool:
	return _surf.is_empty()


## Birikmiş üçgenlerden mesh üretir; malzeme türü başına bir yüzey.
func mesh() -> ArrayMesh:
	return _build(_surf)


func _build(surf: Dictionary) -> ArrayMesh:
	var am := ArrayMesh.new()
	for kind in surf:
		var src: Array = surf[kind]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = PackedVector3Array(src[0])
		arr[Mesh.ARRAY_NORMAL] = PackedVector3Array(src[1])
		arr[Mesh.ARRAY_COLOR] = PackedColorArray(src[2])
		arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array(src[3])
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		am.surface_set_material(am.get_surface_count() - 1, material(kind))
	return am


static func material(kind: String) -> StandardMaterial3D:
	if _mats.has(kind):
		return _mats[kind]
	var d: Array = MATS[kind]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	var tex: String = d[0]
	if kind == "emit":
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	elif tex != "":
		var k: float = 1.0 / float(d[1])
		m.albedo_texture = Tex.texture(tex)
		m.uv1_scale = Vector3(k, k, 1.0)
	m.roughness = d[2]
	m.metallic = d[3]
	_mats[kind] = m
	return m
