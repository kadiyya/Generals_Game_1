class_name Sfx
extends Node
## Kodla sentezlenen sesler ve müzik: ses dosyası yoktur. Her ses ilk kullanıldığında üç farklı çeşitle bir kez
## üretilir (aynı ses art arda hep aynı duyulmasın). Sesler katmanlıdır: keskin çatırtı, gövde (gümbürtü),
## kuyruk (uzayan yankı) ve açık arazi yankısı. Kameraya uzaklığa göre kısılır, uzaktakiler boğuklaşır (daha az
## çatırtı), aynı ses çok sık çalınmaz.
## Müzik: "menu" (giriş ekranı, marş havası) ya da "battle" (maç, gergin). Arka planda üretilir ve user:// altına
## kaydedilir; sonraki açılışlarda anında çalar.

const RATE := 22050
const MRATE := 16000
const POOL := 16
const VARIANTS := 3
const MUSIC_VER := 3
const SOFT_HZ := 2500.0    # efektlerin üst frekans sınırı: tiz, cızırtılı kısımlar kısılır
const MUSIC_SOFT_HZ := 3000.0

static var _cache := {}
static var _music_cache := {}
var players: Array = []
var _last := {}
var music: AudioStreamPlayer
var theme := "battle"
var _music_task := -1
var _music_data: PackedByteArray

# ad -> [taban ses (dB), en kısa tekrar aralığı (sn)]
const LEVEL := {
	rifle = [-14.0, 0.06], autocannon = [-11.0, 0.08], cannon = [-5.0, 0.12], arty = [-4.0, 0.15], missile = [-8.0, 0.12],
	beam = [-13.0, 0.15], boom_s = [-7.0, 0.08], boom_l = [-2.0, 0.15], click = [-15.0, 0.03],
	alert = [-14.0, 1.0], capture = [-8.0, 0.5], rank = [-11.0, 0.5], jam = [-15.0, 0.3], jet = [-10.0, 0.6],
	build = [-11.0, 0.4], intercept = [-7.0, 0.1], drone = [-13.0, 0.25],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -14.0 if theme == "menu" else -17.0
	add_child(music)
	if Settings.get_v("music"):
		if _music_cache.has(theme):
			_start_music(_music_cache[theme])
		else:
			var path := _music_path()
			if FileAccess.file_exists(path):
				var f := FileAccess.open(path, FileAccess.READ)
				var data := f.get_buffer(f.get_length())
				if data.size() > 1000:
					_music_cache[theme] = data
					_start_music(data)
					return
			# Müzik arka planda üretilir; hazır olunca çalmaya başlar.
			_music_task = WorkerThreadPool.add_task(_make_music.bind(theme))


func _music_path() -> String:
	return "user://muzik_%s_%d.bin" % [theme, MUSIC_VER]


func _process(_dt: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		_music_cache[theme] = _music_data
		var f := FileAccess.open(_music_path(), FileAccess.WRITE)
		if f != null:
			f.store_buffer(_music_data)
			f.close()
		_start_music(_music_data)


func _start_music(data: PackedByteArray) -> void:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = MRATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_end = data.size() / 2
	music.stream = w
	music.play()


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)


## Sesi çalar. pos verilirse kameraya uzaklığa göre kısılır ve boğuklaşır; çok uzaktaysa hiç çalmaz.
func play(name: String, pos := Vector3.INF) -> void:
	if not Settings.get_v("sound"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var lv: Array = LEVEL.get(name, [-10.0, 0.05])
	if now - float(_last.get(name, -10.0)) < lv[1]:
		return
	var vol: float = lv[0]
	var pitch := randf_range(0.92, 1.0)
	if pos != Vector3.INF and Game.I != null:
		var cam := Game.I.cam
		var d := Vector2(pos.x - cam.focus.x, pos.z - cam.focus.z).length()
		var reach := cam.dist * 1.4
		if d > reach:
			return
		var far := d / reach
		vol -= far * 13.0 + maxf(0.0, cam.dist - 40.0) * 0.07
		# uzaktaki ses biraz pes ve yavaş duyulur (boğuk)
		pitch *= 1.0 - far * 0.1
	_last[name] = now
	for p in players:
		if not p.playing:
			p.stream = stream(name)
			p.volume_db = vol
			p.pitch_scale = pitch
			p.play()
			return


static func stream(name: String) -> AudioStreamWAV:
	if not _cache.has(name):
		var list: Array = []
		for v in VARIANTS:
			seed(hash(name) + v * 7919)
			list.append(_wav(_normalize(_soften(_make(name), RATE, SOFT_HZ), 0.92), RATE))
		randomize()
		_cache[name] = list
	var l: Array = _cache[name]
	return l[randi() % l.size()]


static func _make(name: String) -> PackedFloat32Array:
	match name:
		"rifle":
			# keskin çatırtı + kısa gövde + açık arazi yankısı
			var s := _mix([_hp(_burst(0.05, 120.0), 0.6), _lp(_burst(0.12, 38.0), 0.25), _thump(0.08, 180.0, 90.0, 40.0, 0.4)])
			return _echo(s, [[0.09, 0.22], [0.21, 0.1]])
		"autocannon":
			var s := _mix([_hp(_burst(0.06, 90.0), 0.5), _lp(_burst(0.25, 18.0), 0.18), _thump(0.25, 140.0, 60.0, 16.0, 0.8)])
			return _echo(s, [[0.11, 0.25], [0.26, 0.12]])
		"cannon":
			var s := _mix([_hp(_burst(0.08, 70.0), 0.45), _thump(0.7, 85.0, 34.0, 6.5, 1.1), _lp(_burst(1.4, 3.2), 0.05), _lp(_burst(0.3, 14.0), 0.3)])
			return _echo(s, [[0.14, 0.3], [0.33, 0.16], [0.6, 0.08]])
		"arty":
			var s := _mix([_hp(_burst(0.07, 60.0), 0.35), _thump(1.0, 62.0, 26.0, 4.0, 1.2), _lp(_burst(2.0, 2.2), 0.035)])
			return _echo(s, [[0.2, 0.32], [0.45, 0.18], [0.8, 0.1]])
		"missile":
			# ateşleme + yükselen kükreme
			return _mix([_lp(_burst(0.15, 25.0), 0.4), _roar(1.3, 0.04, 0.35, 0.9)])
		"beam":
			return _mix([_saw_sweep(0.4, 450.0, 200.0, 0.35, 35.0), _lp(_burst(0.4, 6.0), 0.3, 0.1)])
		"boom_s":
			var s := _mix([_hp(_burst(0.06, 80.0), 0.5), _thump(0.6, 70.0, 30.0, 6.0, 1.0), _lp(_burst(1.1, 3.5), 0.06), _debris(1.0, 40, 0.25)])
			return _echo(s, [[0.15, 0.25], [0.36, 0.12]])
		"boom_l":
			var s := _mix([_hp(_burst(0.09, 50.0), 0.45), _thump(1.6, 55.0, 22.0, 2.4, 1.3), _lp(_burst(2.4, 1.6), 0.03), _debris(2.0, 90, 0.3)])
			return _echo(s, [[0.22, 0.3], [0.5, 0.16], [0.9, 0.08]])
		"click":
			return _mix([_tone([700.0], 0.035, 0.35, 120.0), _lp(_burst(0.012, 300.0), 0.3, 0.2)])
		"alert":
			# iki kez yükselip alçalan uyarı sireni
			return _concat([_siren(0.32, 330.0, 520.0), _silence(0.05), _siren(0.32, 330.0, 520.0)])
		"capture":
			return _echo(_concat([_pluck(261.63, 0.16), _pluck(329.63, 0.16), _pluck(392.0, 0.4)]), [[0.12, 0.25]])
		"rank":
			return _echo(_concat([_brass(293.66, 0.14), _brass(392.0, 0.14), _brass(493.88, 0.42)]), [[0.13, 0.22]])
		"jam":
			return _mix([_lp(_burst(0.4, 2.0), 0.6, 0.5), _warble(0.4, 220.0, 0.2)])
		"jet":
			return _flyby(2.4)
		"build":
			# iki metal vuruş ve perçin tıkırtısı
			return _echo(_concat([_metal(0.18), _silence(0.06), _metal(0.3)]), [[0.1, 0.2]])
		"intercept":
			return _echo(_mix([_hp(_burst(0.05, 90.0), 0.6), _thump(0.4, 120.0, 50.0, 9.0, 0.6), _debris(0.5, 25, 0.2)]), [[0.18, 0.2]])
		"drone":
			return _buzz(0.8, 170.0, 260.0)
	return _silence(0.05)


# ---------------------------------------------------------------- sentez yardımcıları

static func _wav(s: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize(s.size() * 2)
	for i in s.size():
		b.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = b
	return w


static func _normalize(s: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m := 0.0001
	for v in s:
		m = maxf(m, absf(v))
	var k := peak / m
	for i in s.size():
		s[i] *= k
	return s


## İki kademeli alçak geçiren süzgeç (hz üstü kısılır): bütün efektler ve müzik bundan geçer, tiz sesler yormasın.
static func _soften(s: PackedFloat32Array, rate: int, hz: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * hz / float(rate))
	var y1 := 0.0
	var y2 := 0.0
	for i in s.size():
		y1 += (s[i] - y1) * a
		y2 += (y1 - y2) * a
		s[i] = y2
	return s


## Beyaz gürültü patlaması: hızlı atak, üstel sönüm.
static func _burst(secs: float, decay: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		s[i] = randf_range(-1.0, 1.0) * exp(-t * decay) * minf(1.0, t * 900.0)
	return s


## Tek kutuplu alçak geçiren süzgeç (a: 0..1, küçük = daha boğuk). gain: çıkış kazancı.
static func _lp(s: PackedFloat32Array, a: float, gain := 1.0) -> PackedFloat32Array:
	var y := 0.0
	for i in s.size():
		y += (s[i] - y) * a
		s[i] = y * gain / sqrt(a)
	return s


## Yüksek geçiren: keskin çatırtı için.
static func _hp(s: PackedFloat32Array, a: float, gain := 1.0) -> PackedFloat32Array:
	var y := 0.0
	for i in s.size():
		y += (s[i] - y) * a
		s[i] = (s[i] - y) * gain
	return s


## Alçak frekanslı darbe: f0'dan f1'e inen sinüs, biraz doyurulmuş (gümbürtü).
static func _thump(secs: float, f0: float, f1: float, decay: float, amp: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(f0, f1, sqrt(t / secs)) / RATE
		s[i] = tanh(sin(ph) * 1.6) * exp(-t * decay) * amp * minf(1.0, t * 600.0)
	return s


## Moloz ve kıvılcım çıtırtısı: seyrek, sönen tıkırtılar.
static func _debris(secs: float, count: int, amp: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for c in count:
		var at := int(pow(randf(), 1.8) * n * 0.9)
		var k := randf_range(0.3, 1.0) * amp * (1.0 - float(at) / n)
		var len := int(RATE * randf_range(0.004, 0.015))
		for j in len:
			if at + j < n:
				s[at + j] += randf_range(-1.0, 1.0) * k * (1.0 - float(j) / len)
	return s


## Roket kükremesi: süzgeci açılıp kapanan gürültü.
static func _roar(secs: float, a0: float, a1: float, amp: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / n
		var a := lerpf(a0, a1, sin(PI * minf(1.0, t * 1.4)))
		y += (randf_range(-1.0, 1.0) - y) * a
		s[i] = y * amp * minf(1.0, t * 30.0) * (1.0 - t) * 3.0
	return s


## Uçak geçişi: yaklaşırken tizleşen, uzaklaşırken pesleşen gürültü ve türbin ıslığı.
static func _flyby(secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var y := 0.0
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		var near := exp(-pow((t - 0.45) * 4.0, 2.0))
		y += (randf_range(-1.0, 1.0) - y) * lerpf(0.05, 0.4, near)
		ph += TAU * lerpf(1900.0, 1100.0, smoothstep(0.3, 0.6, t)) / RATE
		s[i] = (y * 2.2 + sin(ph) * 0.12) * (0.15 + near) * minf(1.0, t * 8.0) * minf(1.0, (1.0 - t) * 6.0)
	return s


static func _saw_sweep(secs: float, f0: float, f1: float, amp: float, trem: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph = fmod(ph + lerpf(f0, f1, t / secs) / RATE, 1.0)
		s[i] = (ph * 2.0 - 1.0) * amp * (1.0 - t / secs) * (0.7 + 0.3 * sin(TAU * trem * t))
	return _lp(s, 0.35)


static func _tone(freqs: Array, secs: float, amp: float, decay: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var t := float(i) / RATE
		var v := 0.0
		for f in freqs:
			v += sin(TAU * float(f) * t)
		s[i] = v / freqs.size() * amp * exp(-t * decay) * minf(1.0, t * 300.0)
	return s


## Siren: yükselip alçalan kare dalga, yumuşatılmış.
static func _siren(secs: float, f0: float, f1: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph = fmod(ph + lerpf(f0, f1, sin(PI * t)) / RATE, 1.0)
		s[i] = (1.0 if ph < 0.5 else -1.0) * 0.35 * minf(1.0, t * 20.0) * minf(1.0, (1.0 - t) * 20.0)
	return _lp(s, 0.25)


## Telli çalgı tınısı (Karplus-Strong).
static func _pluck(f: float, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var p := maxi(2, int(RATE / f))
	var buf := PackedFloat32Array()
	buf.resize(p)
	for i in p:
		buf[i] = randf_range(-1.0, 1.0)
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		var k := i % p
		var v := buf[k]
		buf[k] = (v + buf[(k + 1) % p]) * 0.498
		s[i] = v * 0.6
	return s


## Bakır nefesli tınısı: süzgeci açılan testere dalga, hafif titreşim.
static func _brass(f: float, secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		ph = fmod(ph + f * (1.0 + 0.004 * sin(TAU * 5.5 * t)) / RATE, 1.0)
		var env := minf(1.0, t * 25.0) * minf(1.0, (secs - t) * 12.0)
		y += ((ph * 2.0 - 1.0) - y) * (0.08 + 0.25 * env)
		s[i] = y * env * 0.5
	return s


## Metal vuruş: uyumsuz kısmi tonlar.
static func _metal(secs: float) -> PackedFloat32Array:
	var base := randf_range(380.0, 460.0)
	return _mix([_tone([base, base * 2.76, base * 5.4, base * 8.93], secs, 0.6, 18.0), _hp(_burst(0.02, 200.0), 0.6, 0.5)])


static func _warble(secs: float, f: float, amp: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * f * (1.0 + 0.3 * sin(TAU * 13.0 * t)) / RATE
		s[i] = sin(ph) * amp * (1.0 - t / secs)
	return s


## Dron vızıltısı: tizleşen testere dalga, pervane titreşimi.
static func _buzz(secs: float, f0: float, f1: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / n
		ph = fmod(ph + lerpf(f0, f1, t) / RATE, 1.0)
		s[i] = (ph * 2.0 - 1.0) * 0.4 * (0.6 + 0.4 * sin(TAU * 31.0 * t * secs)) * minf(1.0, t * 10.0) * minf(1.0, (1.0 - t) * 8.0)
	return _lp(s, 0.3)


## Açık arazi yankısı: [gecikme sn, kazanç] dokunuşları; dokunuşlar giderek boğuklaşır.
static func _echo(s: PackedFloat32Array, taps: Array) -> PackedFloat32Array:
	var last: float = taps[taps.size() - 1][0]
	var out := s.duplicate()
	out.resize(s.size() + int(last * RATE))
	for i in range(s.size(), out.size()):
		out[i] = 0.0
	for tp in taps:
		var off := int(float(tp[0]) * RATE)
		var g: float = tp[1]
		var y := 0.0
		for i in s.size():
			y += (s[i] - y) * 0.3
			out[i + off] += y * g
	return out


static func _silence(secs: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(secs * RATE))
	return s


static func _mix(list: Array) -> PackedFloat32Array:
	var n := 0
	for a in list:
		n = maxi(n, a.size())
	var s := PackedFloat32Array()
	s.resize(n)
	for a in list:
		for i in a.size():
			s[i] += a[i]
	return s


static func _concat(list: Array) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	for a in list:
		s.append_array(a)
	return s


# ---------------------------------------------------------------- müzik

## midi nota numarası -> Hz
static func _hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


## Pad (yaylılar): iki hafif akortsuz testere, yumuşak süzgeç, yavaş atak ve bırakış.
static func _add_pad(buf: PackedFloat32Array, at: float, dur: float, f: float, amp: float) -> void:
	var i0 := int(at * MRATE)
	var n := int((dur + 0.6) * MRATE)
	var p1 := 0.0
	var p2 := 0.37
	var y := 0.0
	for j in n:
		var i := i0 + j
		if i >= buf.size():
			break
		var t := float(j) / MRATE
		p1 = fmod(p1 + f * 1.003 / MRATE, 1.0)
		p2 = fmod(p2 + f * 0.997 / MRATE, 1.0)
		var env := minf(1.0, t / 0.5) * (1.0 if t < dur else maxf(0.0, 1.0 - (t - dur) / 0.6))
		y += ((p1 + p2 - 1.0) - y) * 0.06
		buf[i] += y * env * amp


## Nefesli melodi: süzgeci açılan testere, vibrato.
static func _add_lead(buf: PackedFloat32Array, at: float, dur: float, f: float, amp: float) -> void:
	var i0 := int(at * MRATE)
	var n := int((dur + 0.15) * MRATE)
	var ph := 0.0
	var y := 0.0
	for j in n:
		var i := i0 + j
		if i >= buf.size():
			break
		var t := float(j) / MRATE
		ph = fmod(ph + f * (1.0 + 0.005 * sin(TAU * 5.0 * t) * minf(1.0, t * 2.0)) / MRATE, 1.0)
		var env := minf(1.0, t * 14.0) * (1.0 if t < dur else maxf(0.0, 1.0 - (t - dur) / 0.15))
		y += ((ph * 2.0 - 1.0) - y) * (0.07 + 0.12 * env)
		buf[i] += y * env * amp


## Bas: yumuşak üçgen dalga, kısa nota.
static func _add_bass(buf: PackedFloat32Array, at: float, dur: float, f: float, amp: float) -> void:
	var i0 := int(at * MRATE)
	var n := int(dur * MRATE)
	var ph := 0.0
	for j in n:
		var i := i0 + j
		if i >= buf.size():
			break
		var t := float(j) / MRATE
		ph = fmod(ph + f / MRATE, 1.0)
		var tri := 4.0 * absf(ph - 0.5) - 1.0
		buf[i] += tri * amp * minf(1.0, t * 60.0) * exp(-t * 2.5)


## Davullar: timpani (inen sinüs) ve trampet (süzülmüş gürültü).
static func _add_kick(buf: PackedFloat32Array, at: float, amp: float) -> void:
	var i0 := int(at * MRATE)
	var ph := 0.0
	for j in int(0.6 * MRATE):
		var i := i0 + j
		if i >= buf.size():
			break
		var t := float(j) / MRATE
		ph += TAU * lerpf(95.0, 48.0, minf(1.0, t * 5.0)) / MRATE
		buf[i] += sin(ph) * exp(-t * 6.0) * amp


static func _add_snare(buf: PackedFloat32Array, rng: RandomNumberGenerator, at: float, amp: float) -> void:
	var i0 := int(at * MRATE)
	var y := 0.0
	for j in int(0.18 * MRATE):
		var i := i0 + j
		if i >= buf.size():
			break
		var t := float(j) / MRATE
		var x := rng.randf_range(-1.0, 1.0)
		y += (x - y) * 0.5
		buf[i] += (x - y) * exp(-t * 22.0) * amp + sin(TAU * 190.0 * t) * exp(-t * 30.0) * amp * 0.5


## Arka plan iş parçacığında çalışır: tema müziğini üretip 16 bit veriye çevirir.
func _make_music(which: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var bpm := 92.0 if which == "menu" else 76.0
	var beat := 60.0 / bpm
	var bar := beat * 4.0
	# akorlar (kök midi, akor tonları ofset). menü: Dm Bb F C | Dm Bb Gm A ; maç: Am F Dm E
	var prog: Array
	if which == "menu":
		prog = [[50, [0, 3, 7]], [46, [0, 4, 7]], [53, [0, 4, 7]], [48, [0, 4, 7]], [50, [0, 3, 7]], [46, [0, 4, 7]], [43, [0, 3, 7]], [45, [0, 4, 7]]]
	else:
		prog = [[45, [0, 3, 7]], [41, [0, 4, 7]], [38, [0, 3, 7]], [40, [0, 4, 7]], [45, [0, 3, 7]], [41, [0, 4, 7]], [43, [0, 4, 7]], [40, [0, 4, 7]]]
	var bars := prog.size() * 2
	var total := bar * bars
	var buf := PackedFloat32Array()
	buf.resize(int(total * MRATE) + MRATE)
	for b in bars:
		var c: Array = prog[b % prog.size()]
		var root: int = c[0]
		var at := b * bar
		# yaylılar
		for o in c[1]:
			_add_pad(buf, at, bar, _hz(root + 12 + int(o)), 0.05)
		_add_pad(buf, at, bar, _hz(root), 0.045)
		# bas: menüde sekizlik ostinato, maçta dörtlük
		var step := beat * (0.5 if which == "menu" else 1.0)
		var k := 0
		var t := 0.0
		while t < bar - 0.01:
			_add_bass(buf, at + t, step * 0.9, _hz(root - 12 + (7 if k % 4 == 3 else 0)), 0.16)
			t += step
			k += 1
		# davullar: menüde marş trampeti, maçta yavaş timpani nabzı
		if which == "menu":
			_add_kick(buf, at, 0.5)
			_add_kick(buf, at + beat * 2.0, 0.4)
			for s16 in 16:
				var acc := s16 % 4 == 0
				if s16 in [0, 2, 3, 4, 6, 8, 10, 11, 12, 13, 14, 15] and b >= 2:
					_add_snare(buf, rng, at + s16 * beat * 0.25, 0.14 if acc else 0.06)
		else:
			_add_kick(buf, at, 0.45)
			_add_kick(buf, at + beat * 2.5, 0.3)
			if b % 2 == 1:
				_add_snare(buf, rng, at + beat * 3.5, 0.08)
	# melodi (ikinci yarıda): nota [vuruş, süre(vuruş), midi]
	var mel: Array
	if which == "menu":
		mel = [[0, 1.5, 62], [1.5, 0.5, 65], [2, 2, 69], [4, 1.5, 70], [5.5, 0.5, 69], [6, 2, 65],
			[8, 1.5, 65], [9.5, 0.5, 69], [10, 2, 72], [12, 3, 67], [15, 1, 64],
			[16, 1.5, 62], [17.5, 0.5, 65], [18, 2, 69], [20, 1.5, 70], [21.5, 0.5, 72], [22, 2, 74],
			[24, 2, 70], [26, 2, 67], [28, 4, 69]]
	else:
		mel = [[0, 3, 69], [3, 1, 67], [4, 4, 65], [8, 2, 62], [10, 2, 64], [12, 4, 64],
			[16, 3, 69], [19, 1, 71], [20, 4, 72], [24, 2, 71], [26, 2, 67], [28, 4, 68]]
	var half := bar * prog.size()
	for m in mel:
		_add_lead(buf, half + float(m[0]) * beat, float(m[1]) * beat * 0.95, _hz(float(m[2])), 0.09 if which == "menu" else 0.06)
	# salon yankısı: birkaç gecikmeli, boğuk kopya
	var out := buf.duplicate()
	for tp in [[0.083, 0.18], [0.157, 0.14], [0.241, 0.1], [0.37, 0.07]]:
		var off := int(float(tp[0]) * MRATE)
		var y := 0.0
		for i in range(buf.size() - off):
			y += (buf[i] - y) * 0.25
			out[i + off] += y * float(tp[1])
	# döngü: sondaki taşmayı başa ekle (dikişsiz)
	var n := int(total * MRATE)
	for i in range(n, out.size()):
		out[i - n] += out[i]
	out = _soften(out, MRATE, MUSIC_SOFT_HZ)
	var peak := 0.001
	for i in n:
		peak = maxf(peak, absf(out[i]))
	var b2 := PackedByteArray()
	b2.resize(n * 2)
	for i in n:
		b2.encode_s16(i * 2, int(clampf(out[i] / peak * 0.85, -1.0, 1.0) * 30000.0))
	_music_data = b2
