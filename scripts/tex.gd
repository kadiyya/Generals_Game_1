class_name Tex
extends RefCounted
## Kodla üretilen, kenarları birbirine oturan (döşenebilir) texture'lar. Dosya yok; açılışta bir kez üretilir.
## Hepsi gri tonlamalıdır ve malzemenin rengiyle çarpılır; böylece tek texture her ülke ve harita rengine uyar.
## Yüzeylere triplanar eşlemeyle uygulanır, bu yüzden modellerin UV açılımına gerek kalmaz.

const SIZE := 128

static var _tex := {}
static var _mats := {}
static var _wear_img: Image = null


static func texture(kind: String) -> ImageTexture:
	if _tex.has(kind):
		return _tex[kind]
	var n := FastNoiseLite.new()
	n.seed = kind.hash() % 1000
	var img: Image
	match kind:
		"camo":
			# üç tonlu kamuflaj lekeleri
			n.frequency = 0.022
			img = _levels(n, [[0.42, 0.55], [0.58, 0.78], [1.0, 1.0]])
		"rock":
			n.frequency = 0.06
			n.fractal_octaves = 4
			img = _range(n, 0.55, 1.0, 0.0)
		"water":
			n.frequency = 0.03
			n.fractal_octaves = 2
			img = _range(n, 0.82, 1.0, 0.0)
		"armor":
			img = _armor(n)
		"steel":
			# çıplak / kirli metal: lekeli, benekli
			n.frequency = 0.07
			n.fractal_octaves = 3
			img = _range(n, 0.6, 1.0, 0.06)
		"track":
			img = _track(n)
		"air_ru":
			img = _air_camo(n, [Color(0.64, 0.7, 0.76), Color(0.47, 0.55, 0.66), Color(0.56, 0.62, 0.7)], 0.028, false)
		"air_desert":
			img = _air_camo(n, [Color(0.74, 0.64, 0.47), Color(0.52, 0.4, 0.27), Color(0.58, 0.58, 0.42)], 0.03, false)
		"air_il":
			img = _air_camo(n, [Color(0.77, 0.68, 0.5), Color(0.56, 0.44, 0.3), Color(0.55, 0.56, 0.4)], 0.032, false)
		"air_split":
			img = _air_camo(n, [Color(0.6, 0.65, 0.7), Color(0.36, 0.4, 0.46), Color(0.5, 0.58, 0.66)], 0.035, true)
		"concrete":
			# beton: lekeler, kalıp derzleri, akıntı izleri
			n.frequency = 0.045
			n.fractal_octaves = 4
			img = _range(n, 0.74, 1.0, 0.05)
			for y in SIZE:
				for x in SIZE:
					if y % 42 == 0 or (x + (y / 42) * 21) % 64 == 0:
						img.set_pixel(x, y, img.get_pixel(x, y) * 0.8)
		"corrug":
			# oluklu sac: dalga sırtları ve hafif pas lekeleri
			n.frequency = 0.05
			img = _range(n, 0.82, 1.0, 0.03)
			for y in SIZE:
				for x in SIZE:
					var wave := 0.8 + 0.2 * absf(sin(x * PI / 8.0))
					img.set_pixel(x, y, img.get_pixel(x, y) * wave)
		"skin":
			# uçak boyası: hafif lekeler ve eskitme (kir, akıntı izi, boya sıyrığı)
			n.frequency = 0.04
			img = _range(n, 0.88, 1.0, 0.02)
			for y in SIZE:
				for x in SIZE:
					img.set_pixel(x, y, img.get_pixel(x, y) * _wear().get_pixel(x, y).r)
		"fabric":
			# branda ve tanıma örtüsü: hafif leke ve ince dokuma
			n.frequency = 0.09
			img = _range(n, 0.84, 1.0, 0.04)
			for y in SIZE:
				for x in SIZE:
					if (x + y) % 4 == 0:
						img.set_pixel(x, y, img.get_pixel(x, y) * 0.92)
		"panel":
			# beton ve gövde sacı: hafif leke + panel çizgileri
			n.frequency = 0.05
			img = _range(n, 0.86, 1.0, 0.0)
			for y in SIZE:
				for x in SIZE:
					if x % 32 == 0 or y % 32 == 0:
						var c := img.get_pixel(x, y)
						img.set_pixel(x, y, c * 0.72)
		_:
			# arazi: yumuşak leke + ince benek
			n.frequency = 0.035
			n.fractal_octaves = 3
			img = _range(n, 0.78, 1.0, 0.07)
	img.generate_mipmaps()
	_tex[kind] = ImageTexture.create_from_image(img)
	return _tex[kind]


static func _noise(n: FastNoiseLite) -> Image:
	var img := n.get_seamless_image(SIZE, SIZE)
	img.convert(Image.FORMAT_RGB8)
	return img


static func _range(n: FastNoiseLite, lo: float, hi: float, speckle: float) -> Image:
	var img := _noise(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for y in SIZE:
		for x in SIZE:
			var v := lerpf(lo, hi, img.get_pixel(x, y).r)
			if speckle > 0.0:
				v = clampf(v + rng.randf_range(-speckle, speckle), 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	return img


## Boyalı zırh: yumuşak kenarlı iki tonlu leke, ince kir, dikey akıntı izleri ve boya sıyrıkları.
## Rengi köşe renginden gelir; bu yalnızca açık-koyu deseni verir.
static func _armor(n: FastNoiseLite) -> Image:
	n.frequency = 0.03
	var blot := _noise(n)
	var g := FastNoiseLite.new()
	g.seed = 77
	g.frequency = 0.11
	g.fractal_octaves = 3
	var grime := _noise(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# akıntı izleri: sütun başına rastgele şiddet, komşularla yumuşatılmış
	var col: Array = []
	for x in SIZE:
		col.append(rng.randf())
	var streak: Array = []
	for x in SIZE:
		var v: float = (col[(x - 1 + SIZE) % SIZE] + col[x] * 2.0 + col[(x + 1) % SIZE]) * 0.25
		streak.append(maxf(0.0, v - 0.55) * 0.4)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var b := blot.get_pixel(x, y).r
			var gr := grime.get_pixel(x, y).r
			var v := 0.93
			v = lerpf(v, 0.74, 1.0 - smoothstep(0.33, 0.4, b))
			v = lerpf(v, 1.0, smoothstep(0.62, 0.69, b))
			v *= lerpf(0.84, 1.05, gr)
			v -= float(streak[x]) * (0.5 + gr)
			img.set_pixel(x, y, Color(v, v, v))
	# boya sıyrıkları: açık ve koyu küçük lekeler
	for i in 160:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		var c := img.get_pixel(x, y)
		var k := 1.18 if i % 3 == 0 else 0.6
		img.set_pixel(x, y, Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0)))
		img.set_pixel((x + 1) % SIZE, y, Color(minf(c.r * k, 1.0), minf(c.g * k, 1.0), minf(c.b * k, 1.0)))
	return img


## Palet: u yönünde 8 bakla, v yönünde bant genişliği. Baklalar arası boşluk, tırnak, ortada kılavuz dişi.
static func _track(n: FastNoiseLite) -> Image:
	n.frequency = 0.08
	var mud := _noise(n)
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		for x in SIZE:
			var lx := x % 16
			var v := 0.6
			if lx < 2:
				v = 0.16
			elif lx < 5:
				v = 0.9
			elif lx > 13:
				v = 0.42
			if absf(y - 63.5) < 9.0:
				v = 0.95 if lx >= 4 and lx < 12 else 0.3
			if y < 5 or y > 122:
				v *= 0.65
			v *= lerpf(0.72, 1.05, mud.get_pixel(x, y).r)
			img.set_pixel(x, y, Color(v, v, v))
	return img


## Uçak kamuflajı (renkli): üç tonlu yumuşak ya da keskin (splinter) lekeler, panel çizgileri ve perçin sıraları.
static func _air_camo(n: FastNoiseLite, cols: Array, freq: float, sharp: bool) -> Image:
	n.frequency = freq
	n.fractal_octaves = 2 if sharp else 3
	var a := _noise(n)
	var g := FastNoiseLite.new()
	g.seed = 31
	g.frequency = freq * 1.3
	var b := _noise(g)
	var w := _wear()
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var e := 0.005 if sharp else 0.035
	for y in SIZE:
		for x in SIZE:
			var va := a.get_pixel(x, y).r
			var vb := b.get_pixel(x, y).r
			var c: Color = cols[0]
			c = c.lerp(cols[1], smoothstep(0.55 - e, 0.55 + e, va))
			c = c.lerp(cols[2], smoothstep(0.6 - e, 0.6 + e, vb) * (1.0 - smoothstep(0.5, 0.56, va)))
			var k := (0.95 + 0.05 * vb) * w.get_pixel(x, y).r
			img.set_pixel(x, y, Color(c.r * k, c.g * k, c.b * k))
	return img


## Uçak sacı eskitmesi (çarpan): ince kir, büyük lekeler, akış yönünde (u = gövde boyu) akıntı izleri ve boya
## sıyrıkları. Panel çizgisi yok. Bir kez üretilir, gri boya ve kamuflaj dokuları bununla çarpılır.
static func _wear() -> Image:
	if _wear_img != null:
		return _wear_img
	var g := FastNoiseLite.new()
	g.seed = 91
	g.frequency = 0.09
	g.fractal_octaves = 3
	var grime := _noise(g)
	var b := FastNoiseLite.new()
	b.seed = 92
	b.frequency = 0.025
	var blot := _noise(b)
	var rng := RandomNumberGenerator.new()
	rng.seed = 17
	var row: Array = []
	for y in SIZE:
		row.append(rng.randf())
	var img := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	for y in SIZE:
		var r: float = (row[(y - 1 + SIZE) % SIZE] + row[y] * 2.0 + row[(y + 1) % SIZE]) * 0.25
		var streak := maxf(0.0, r - 0.5) * 0.5
		for x in SIZE:
			var gr := grime.get_pixel(x, y).r
			var bl := blot.get_pixel(x, y).r
			var v := lerpf(0.86, 1.03, gr)
			v *= 1.0 - 0.14 * smoothstep(0.55, 0.75, bl)
			v -= streak * (0.3 + 0.7 * gr)
			img.set_pixel(x, y, Color(v, v, v))
	# boya sıyrıkları: küçük açık (çıplak metal) ve koyu lekeler
	for i in 260:
		var x := rng.randi_range(0, SIZE - 1)
		var y := rng.randi_range(0, SIZE - 1)
		var v := img.get_pixel(x, y).r * (1.2 if i % 3 == 0 else 0.6)
		var c := Color(minf(v, 1.0), minf(v, 1.0), minf(v, 1.0))
		img.set_pixel(x, y, c)
		img.set_pixel((x + 1) % SIZE, y, c)
	_wear_img = img
	return img


## Gürültüyü eşiklere göre düz tonlara ayırır: [[eşik, ton], ...]
static func _levels(n: FastNoiseLite, steps: Array) -> Image:
	var img := _noise(n)
	for y in SIZE:
		for x in SIZE:
			var v := img.get_pixel(x, y).r
			var tone := 1.0
			for s in steps:
				if v <= s[0]:
					tone = s[1]
					break
			img.set_pixel(x, y, Color(tone, tone, tone))
	return img


## kind texture'ı ile c rengini çarpan malzeme. scale: birim başına tekrar; world: dünya koordinatına göre döşe.
static func mat(kind: String, c: Color, scale: float, world := false) -> StandardMaterial3D:
	var k := "%s|%s|%s|%s" % [kind, c.to_html(), scale, world]
	if not _mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.albedo_texture = texture(kind)
		m.roughness = 0.9
		m.uv1_triplanar = true
		m.uv1_world_triplanar = world
		m.uv1_scale = Vector3.ONE * scale
		_mats[k] = m
	return _mats[k]
