class_name Tex
extends RefCounted
## Kodla üretilen, kenarları birbirine oturan (döşenebilir) texture'lar. Dosya yok; açılışta bir kez üretilir.
## Hepsi gri tonlamalıdır ve malzemenin rengiyle çarpılır; böylece tek texture her ülke ve harita rengine uyar.
## Yüzeylere triplanar eşlemeyle uygulanır, bu yüzden modellerin UV açılımına gerek kalmaz.

const SIZE := 128

static var _tex := {}
static var _mats := {}


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
