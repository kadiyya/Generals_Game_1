class_name Scenery
extends RefCounted
## Doğa görselleri: arazi, su, bitki ve kuş shader'ları ile kodla üretilen ağaç, çalı, ot ve kuş modelleri.
## Dosya yok; hepsi açılışta bir kez üretilir. Oynanışa etkisi yoktur.

## Arazi: maske dokusundan (R yol, G orman zemini, B kum/kıyı, A kaya) ve eğimden renk üretir.
## Gürültüyle maske kenarları bozulur; böylece 1 m çözünürlüklü maske keskin ve doğal görünür.
const TERRAIN_SHADER := """
shader_type spatial;
uniform sampler2D mask_tex : filter_linear, repeat_disable;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D bump_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 grass : source_color;
uniform vec3 lush : source_color;
uniform vec3 dry : source_color;
uniform vec3 dirt : source_color;
uniform vec3 floor_col : source_color;
uniform vec3 sand : source_color;
uniform vec3 earth : source_color;
uniform vec3 rock : source_color;
uniform vec2 map_size;
uniform float water_y;
varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = VERTEX;
	wn = NORMAL;
}

void fragment() {
	vec2 uv = wp.xz;
	float big = texture(noise_tex, uv * 0.0045).r;
	float mid = texture(noise_tex, uv * 0.021 + vec2(0.37, 0.11)).r;
	float fine = texture(noise_tex, uv * 0.13 + vec2(0.7, 0.2)).r;
	float grain = texture(rock_tex, uv * 0.45).r * 2.0 - 1.0;
	grain = clamp(grain, 0.0, 1.0);
	vec2 muv = (uv + map_size * 0.5 + (vec2(fine, mid) - 0.5) * 1.6) / map_size;
	vec4 m = texture(mask_tex, muv);
	vec3 n = normalize(wn);
	float slope = 1.0 - n.y;

	// çayır: iri lekeler hâlinde gür, olağan ve kuru ot
	vec3 c = mix(lush, grass, smoothstep(0.32, 0.6, big));
	c = mix(c, dry, smoothstep(0.52, 0.74, mid * 0.65 + big * 0.35) * 0.6);
	c *= (0.74 + 0.36 * fine) * (0.72 + 0.56 * grain) * 0.8;
	c = mix(c, vec3(dot(c, vec3(0.3, 0.5, 0.2))), 0.12);
	// orman zemini
	c = mix(c, floor_col * (0.85 + 0.3 * fine), smoothstep(0.25, 0.75, m.g + (fine - 0.5) * 0.5));
	// tepe üstü biraz daha kuru ve açık
	float up = smoothstep(0.25, 1.6, wp.y) * (1.0 - m.a);
	c = mix(c, dry * (0.8 + 0.3 * fine), up * 0.5);
	// toprak yol: ortası açık, kenarı otla karışık
	float road = smoothstep(0.3, 0.62, m.r + (fine - 0.5) * 0.55);
	c = mix(c, dirt * (0.82 + 0.36 * mid) * (0.9 + 0.2 * grain), road);
	// kıyı kumu ve ıslak çamur
	float shore = smoothstep(0.3, 0.7, m.b + (fine - 0.5) * 0.4);
	c = mix(c, sand * (0.88 + 0.24 * fine), shore);
	c *= mix(1.0, 0.6, smoothstep(0.02, -0.3, wp.y - water_y - 0.12));
	// yamaç: çıplak toprak; dağda kaya
	float bare = smoothstep(0.07, 0.2, slope + (fine - 0.5) * 0.08) * (1.0 - m.a);
	c = mix(c, earth * (0.85 + 0.3 * fine), bare * 0.55);
	float rk = texture(rock_tex, uv * 0.11 + wp.y * 0.09).r;
	float crag = smoothstep(0.3, 0.6, m.a + slope * 1.2 + (mid - 0.5) * 0.3) * smoothstep(0.1, 0.5, m.a);
	vec3 rc = rock * (0.5 + 0.55 * rk) * (0.75 + 0.5 * mid) * mix(0.75, 1.05, smoothstep(2.0, 6.5, wp.y));
	rc = mix(rc, c * 0.85, smoothstep(0.3, 0.1, slope + (fine - 0.5) * 0.2) * 0.7);
	c = mix(c, rc, crag);
	// harita dışı: koyu ve soluk
	float outd = max(abs(wp.x) - map_size.x * 0.5, abs(wp.z) - map_size.y * 0.5);
	float o = smoothstep(0.0, 6.0, outd);
	c = mix(c, vec3(dot(c, vec3(0.33))) * 0.8, o * 0.35) * mix(1.0, 0.66, o);
	ALBEDO = c;
	ROUGHNESS = 0.95;
	SPECULAR = 0.08;
	vec3 bm = texture(bump_tex, uv * 0.085).xyz * 2.0 - 1.0;
	vec3 bn = normalize(n + vec3(bm.x, 0.0, bm.y) * mix(0.3, 0.6, crag));
	NORMAL = normalize((VIEW_MATRIX * vec4(bn, 0.0)).xyz);
}
"""

## Su: iki yönde kayan dalga, derinliğe göre renk, kıyıda köpük ve güneş parıltısı. Derinlik köşe renginde.
const WATER_SHADER := """
shader_type spatial;
render_mode cull_back, shadows_disabled;
uniform sampler2D noise_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D bump_tex : filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color;
uniform vec3 shallow : source_color;
uniform vec3 bank : source_color;
uniform vec2 map_size;
varying vec3 wp;

void vertex() {
	wp = VERTEX;
}

void fragment() {
	vec2 uv = wp.xz;
	float t = TIME;
	float n1 = texture(noise_tex, uv * 0.035 + vec2(t * 0.011, t * 0.017)).r;
	float n2 = texture(noise_tex, uv * 0.071 + vec2(-t * 0.019, t * 0.008)).r;
	float depth = COLOR.r;
	vec3 c = mix(shallow, deep, smoothstep(0.1, 0.85, depth + (n1 - 0.5) * 0.25));
	c *= 0.86 + 0.28 * n2;
	// sığ kıyıda dip görünür
	c = mix(bank, c, smoothstep(0.0, 0.3, depth + (n2 - 0.5) * 0.08));
	// kıyıya vuran köpük
	float lap = sin(t * 0.9 + n1 * 12.0) * 0.5 + 0.5;
	float foam = smoothstep(0.2 + lap * 0.1, 0.06, depth + (n2 - 0.5) * 0.14) * smoothstep(0.0, 0.05, depth);
	c = mix(c, vec3(0.86, 0.9, 0.9), foam * 0.55);
	// parıltı: iki gürültünün tepeleri çakışınca
	float g1 = texture(noise_tex, uv * 0.21 + vec2(t * 0.045, -t * 0.03)).r;
	float g2 = texture(noise_tex, uv * 0.17 + vec2(-t * 0.038, t * 0.05)).r;
	float glint = smoothstep(0.5, 0.62, g1 * g2) * smoothstep(0.15, 0.5, depth);
	float outd = max(abs(wp.x) - map_size.x * 0.5, abs(wp.z) - map_size.y * 0.5);
	float o = mix(1.0, 0.66, smoothstep(0.0, 6.0, outd));
	ALBEDO = c * o;
	EMISSION = vec3(0.75, 0.85, 0.9) * glint * 0.3 * o;
	ROUGHNESS = 0.22;
	SPECULAR = 0.6;
	vec3 b1 = texture(bump_tex, uv * 0.06 + vec2(t * 0.02, t * 0.013)).xyz * 2.0 - 1.0;
	vec3 b2 = texture(bump_tex, uv * 0.11 - vec2(t * 0.016, t * 0.024)).xyz * 2.0 - 1.0;
	vec3 wnrm = normalize(vec3((b1.x + b2.x) * 0.35, 1.0, (b1.y + b2.y) * 0.35));
	NORMAL = normalize((VIEW_MATRIX * vec4(wnrm, 0.0)).xyz);
}
"""

## Bitki: rüzgârda salınır (yükseklikle artan eğilme + yaprak titremesi) ve savaş sisinde kararır.
## Köşe rengi: rgb renk, a titreme ağırlığı. Örnek rengi tonu değiştirir.
const PLANT_SHADER := """
shader_type spatial;
render_mode world_vertex_coords, cull_disabled;
uniform sampler2D vis : hint_default_white, filter_linear, repeat_disable;
uniform vec2 map_size;
uniform float wind = 1.0;
varying float shade;

void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	float ph = org.x * 0.31 + org.z * 0.23;
	float hh = max(VERTEX.y - org.y, 0.0);
	float gust = 0.35 + sin(TIME * 0.8 + ph) * 0.65 + sin(TIME * 2.1 + ph * 1.7) * 0.25;
	float bend = hh * sqrt(hh) * 0.022 * wind;
	VERTEX.x += gust * bend;
	VERTEX.z += sin(TIME * 1.1 + ph * 0.6) * bend * 0.5;
	float fl = COLOR.a * wind * 0.045;
	VERTEX.x += sin(TIME * 3.1 + VERTEX.z * 2.3 + ph) * fl;
	VERTEX.y += sin(TIME * 2.6 + VERTEX.x * 2.1 + ph) * fl * 0.6;
	vec2 muv = (org.xz + map_size * 0.5) / map_size;
	float outd = max(abs(org.x) - map_size.x * 0.5, abs(org.z) - map_size.y * 0.5);
	shade = outd > 0.0 ? 0.66 : mix(0.42, 1.0, textureLod(vis, muv, 0.0).r);
}

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2)) * shade;
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
	// yaprak ve ot iki yüzlüdür; arka yüzde de ışık üstten gelsin
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
"""

## Kuş: kanat ucu ağırlığı köşe renginin a kanalında. Örnek verisi: x faz, y süzülme (0..1), z kanat hızı.
const BIRD_SHADER := """
shader_type spatial;
render_mode cull_disabled;

void vertex() {
	float beat = sin(TIME * INSTANCE_CUSTOM.z + INSTANCE_CUSTOM.x);
	float amp = mix(0.5, 0.06, INSTANCE_CUSTOM.y);
	VERTEX.y += COLOR.a * (beat * amp + 0.12);
	VERTEX.x *= 1.0 - COLOR.a * abs(beat) * amp * 0.25;
}

void fragment() {
	ALBEDO = pow(COLOR.rgb, vec3(2.2));
	ROUGHNESS = 0.9;
	if (!FRONT_FACING) {
		NORMAL = -NORMAL;
	}
}
"""

static var _meshes := {}
static var _shaders := {}


static func shader_mat(code: String) -> ShaderMaterial:
	if not _shaders.has(code):
		var sh := Shader.new()
		sh.code = code
		_shaders[code] = sh
	var m := ShaderMaterial.new()
	m.shader = _shaders[code]
	return m


## Köşe renkli, yumuşak normalli küçük model kurucusu.
class Builder:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	func _add(p: Vector3, nr: Vector3, col: Color) -> int:
		v.append(p)
		n.append(nr.normalized())
		c.append(col)
		return v.size() - 1

	## Kesik koni yüzeyi: (y0, r0) tabanından (y1, r1) tepesine. off: eksenin tepede kayması.
	func cone(y0: float, r0: float, y1: float, r1: float, sides: int, c0: Color, c1: Color, off := Vector3.ZERO, base := Vector3.ZERO, spin := 0.0) -> void:
		var s := v.size()
		var tilt := (r0 - r1) / maxf(0.01, y1 - y0)
		for i in sides + 1:
			var a := TAU * i / sides + spin
			var d := Vector3(cos(a), 0, sin(a))
			var nr := d + Vector3(0, tilt, 0)
			_add(base + d * r0 + Vector3(0, y0, 0), nr, c0)
			_add(base + off + d * r1 + Vector3(0, y1, 0), nr, c1)
		for i in sides:
			var a := s + i * 2
			idx.append_array(PackedInt32Array([a, a + 2, a + 1, a + 2, a + 3, a + 1]))

	## Yumru: bozuk küre. Yaprak kümesi, çalı ve kaya için.
	func blob(ctr: Vector3, r: Vector3, c_top: Color, c_bot: Color, sd: int, rough := 0.18, seg := 7, rings := 4) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = sd
		var s := v.size()
		for j in rings + 1:
			var lat := PI * j / rings
			for i in seg + 1:
				var lon := TAU * (i % seg) / seg
				var d := Vector3(sin(lat) * cos(lon), cos(lat), sin(lat) * sin(lon))
				var k := 1.0
				if j > 0 and j < rings and i < seg:
					k += rng.randf_range(-rough, rough)
				var col := c_bot.lerp(c_top, clampf(d.y * 0.6 + 0.5 + rng.randf_range(-0.08, 0.08), 0.0, 1.0))
				_add(ctr + d * r * k, d / r, col)
			# dikiş: son köşe ilkinin aynısı olmalı
			v[v.size() - 1] = v[s + j * (seg + 1)]
			c[c.size() - 1] = c[s + j * (seg + 1)]
		for j in rings:
			for i in seg:
				var a := s + j * (seg + 1) + i
				var b := a + seg + 1
				idx.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))

	## Tek üçgen (iki yüzü de çizilir; bitki malzemesi cull_disabled).
	func tri(a: Vector3, b: Vector3, d: Vector3, ca: Color, cb: Color, cd: Color, nr := Vector3.UP) -> void:
		var s := v.size()
		_add(a, nr, ca)
		_add(b, nr, cb)
		_add(d, nr, cd)
		idx.append_array(PackedInt32Array([s, s + 1, s + 2]))

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, c0: Color, c1: Color, nr := Vector3.UP) -> void:
		tri(a, b, d, c0, c0, c1, nr)
		tri(a, d, e, c0, c1, c1, nr)

	func mesh() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = idx
		var am := ArrayMesh.new()
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return am


static func _a(col: Color, a: float) -> Color:
	return Color(col.r, col.g, col.b, a)


## Bitki ve kaya modelleri. Hepsi yaklaşık birim ölçekte; taban y = 0.
static func mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var b := Builder.new()
	var bark := Color(0.3, 0.23, 0.16, 0.0)
	var bark2 := Color(0.24, 0.18, 0.13, 0.0)
	match kind:
		"conifer":
			# çam / ladin: gövde ve üst üste dört etek
			b.cone(0.0, 0.14, 1.3, 0.1, 5, bark2, bark)
			var tiers := [[0.7, 1.05, 1.9], [1.5, 0.86, 1.7], [2.3, 0.64, 1.5], [3.05, 0.42, 1.35]]
			for i in tiers.size():
				var t: Array = tiers[i]
				var dark := Color(0.09, 0.2, 0.11).lerp(Color(0.13, 0.27, 0.14), i / 3.0)
				var lite := Color(0.2, 0.37, 0.19).lerp(Color(0.27, 0.45, 0.22), i / 3.0)
				b.cone(t[0], t[1], t[0] + t[2], 0.02, 7, _a(dark, 1.0), _a(lite, 0.6), Vector3.ZERO, Vector3.ZERO, i * 0.45)
		"leafy":
			# yapraklı ağaç: gövde, iki dal ve yaprak yumruları
			b.cone(0.0, 0.2, 1.7, 0.12, 5, bark2, bark)
			b.cone(1.5, 0.1, 2.3, 0.05, 4, bark, bark, Vector3(0.55, 0, 0.2))
			b.cone(1.4, 0.1, 2.2, 0.05, 4, bark, bark, Vector3(-0.5, 0, -0.3))
			var top := Color(0.36, 0.5, 0.2, 1.0)
			var bot := Color(0.14, 0.27, 0.11, 0.7)
			b.blob(Vector3(0, 2.9, 0), Vector3(1.2, 1.0, 1.2), top, bot, 3)
			b.blob(Vector3(0.75, 2.4, 0.3), Vector3(0.85, 0.7, 0.85), top, bot, 4)
			b.blob(Vector3(-0.7, 2.3, -0.4), Vector3(0.9, 0.72, 0.9), top, bot, 5)
			b.blob(Vector3(-0.1, 2.5, 0.75), Vector3(0.75, 0.62, 0.75), top, bot, 6)
		"poplar":
			# kavak: rüzgâr perdesi ağacı, uzun ve ince
			b.cone(0.0, 0.15, 1.6, 0.09, 5, bark2, bark)
			b.blob(Vector3(0, 3.0, 0), Vector3(0.62, 2.2, 0.62), Color(0.35, 0.5, 0.2, 1.0), Color(0.13, 0.26, 0.11, 0.6), 8, 0.14, 6, 5)
		"palm":
			# hurma: eğri gövde ve sarkan yapraklar
			var lean := Vector3.ZERO
			for i in 4:
				var nx := Vector3(0.12 * (i + 1) * (i + 1) * 0.3, 0, 0.04 * i)
				b.cone(i * 0.9, 0.17 - i * 0.02, (i + 1) * 0.9, 0.15 - i * 0.02, 5,
					Color(0.36, 0.29, 0.2, 0.0), Color(0.42, 0.34, 0.23, 0.0), nx - lean, lean)
				lean = nx
			var crown := lean + Vector3(0, 3.6, 0)
			for i in 8:
				var a := TAU * i / 8.0 + 0.2
				var d := Vector3(cos(a), 0, sin(a))
				var s := d.cross(Vector3.UP) * 0.3
				var p1 := crown + d * 0.9 + Vector3(0, 0.35, 0)
				var p2 := crown + d * 1.9 + Vector3(0, -0.25 - 0.15 * (i % 2), 0)
				var g0 := Color(0.2, 0.34, 0.14, 0.4)
				var g1 := Color(0.34, 0.46, 0.2, 1.0)
				var nr := Vector3.UP + d * 0.4
				b.quad(crown - s * 0.4, crown + s * 0.4, p1 + s, p1 - s, g0, g1, nr)
				b.tri(p1 - s, p1 + s, p2, g1, g1, Color(0.4, 0.48, 0.22, 1.0), nr + d * 0.5)
			b.blob(crown, Vector3(0.25, 0.22, 0.25), Color(0.3, 0.26, 0.14, 0.0), Color(0.25, 0.2, 0.12, 0.0), 2, 0.1, 5, 3)
		"bush":
			var top := Color(0.36, 0.48, 0.21, 1.0)
			var bot := Color(0.13, 0.24, 0.1, 0.5)
			b.blob(Vector3(0, 0.42, 0), Vector3(0.75, 0.55, 0.7), top, bot, 21, 0.22, 6, 3)
			b.blob(Vector3(0.5, 0.3, 0.2), Vector3(0.5, 0.4, 0.5), top, bot, 22, 0.22, 6, 3)
			b.blob(Vector3(-0.4, 0.28, -0.3), Vector3(0.45, 0.36, 0.5), top, bot, 23, 0.22, 6, 3)
		"tuft":
			# ot öbeği: dışa açılan yedi yaprak
			var rng := RandomNumberGenerator.new()
			rng.seed = 5
			for i in 9:
				var a := TAU * i / 9.0 + rng.randf_range(-0.3, 0.3)
				var d := Vector3(cos(a), 0, sin(a))
				var s := d.cross(Vector3.UP) * 0.14
				var root := d * rng.randf_range(0.02, 0.22)
				var tip := root + d * rng.randf_range(0.1, 0.3) + Vector3(0, rng.randf_range(0.5, 1.0), 0)
				b.tri(root - s, root + s, tip, Color(0.34, 0.45, 0.2, 0.0), Color(0.34, 0.45, 0.2, 0.0), Color(0.52, 0.62, 0.3, 1.0))
		"rock":
			b.blob(Vector3(0, 0.3, 0), Vector3(0.8, 0.55, 0.65), Color(0.95, 0.93, 0.9), Color(0.6, 0.58, 0.56), 31, 0.3, 6, 3)
		"bird":
			# gövde ve iki kanat; kanat ucunun a değeri 1 (shader çırpar)
			var dk := Color(0.3, 0.28, 0.25, 0.0)
			var lt := Color(0.6, 0.58, 0.54, 0.0)
			b.tri(Vector3(0, 0, -0.45), Vector3(0.09, 0, 0.1), Vector3(-0.09, 0, 0.1), lt, dk, dk)
			b.tri(Vector3(0.09, 0, 0.1), Vector3(-0.09, 0, 0.1), Vector3(0, 0, 0.5), dk, dk, dk)
			for sx in [-1.0, 1.0]:
				var tip := Color(0.2, 0.19, 0.18, 1.0)
				var midc := Color(0.36, 0.33, 0.3, 0.45)
				b.tri(Vector3(0, 0, -0.22), Vector3(0, 0, 0.16), Vector3(0.5 * sx, 0, -0.02), dk, dk, midc)
				b.tri(Vector3(0, 0, -0.22), Vector3(0.5 * sx, 0, -0.02), Vector3(0.55 * sx, 0, -0.26), dk, midc, midc)
				b.tri(Vector3(0.55 * sx, 0, -0.26), Vector3(0.5 * sx, 0, -0.02), Vector3(1.05 * sx, 0, 0.08), midc, midc, tip)
	_meshes[kind] = b.mesh()
	return _meshes[kind]
