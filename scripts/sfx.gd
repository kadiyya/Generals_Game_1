class_name Sfx
extends Node
## Kodla sentezlenen sesler ve müzik: ses dosyası yoktur. Her ses ilk kullanıldığında bir kez üretilir.
## Sesler kameraya uzaklığa göre kısılır, aynı ses çok sık çalınmaz (makineli tüfek seli olmasın).

const RATE := 22050
const POOL := 14

static var _cache := {}
var players: Array = []
var _last := {}
var music: AudioStreamPlayer
var _music_task := -1
var _music_data: PackedByteArray

# ad -> [taban ses (dB), en kısa tekrar aralığı (sn)]
const LEVEL := {
	rifle = [-15.0, 0.07], cannon = [-6.0, 0.12], arty = [-5.0, 0.15], missile = [-9.0, 0.12],
	beam = [-12.0, 0.15], boom_s = [-9.0, 0.08], boom_l = [-3.0, 0.15], click = [-14.0, 0.03],
	alert = [-8.0, 1.0], capture = [-8.0, 0.5], rank = [-9.0, 0.5], jam = [-16.0, 0.3], jet = [-12.0, 0.6],
}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	music = AudioStreamPlayer.new()
	music.volume_db = -17.0
	add_child(music)
	if Settings.get_v("music"):
		# Müzik arka planda üretilir; hazır olunca çalmaya başlar.
		_music_task = WorkerThreadPool.add_task(_make_music)


func _process(_dt: float) -> void:
	if _music_task >= 0 and WorkerThreadPool.is_task_completed(_music_task):
		WorkerThreadPool.wait_for_task_completion(_music_task)
		_music_task = -1
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = 11025
		w.data = _music_data
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = _music_data.size() / 2
		music.stream = w
		music.play()


func _exit_tree() -> void:
	if _music_task >= 0:
		WorkerThreadPool.wait_for_task_completion(_music_task)


## Sesi çalar. pos verilirse kameraya uzaklığa göre kısılır; çok uzaktaysa hiç çalmaz.
func play(name: String, pos := Vector3.INF) -> void:
	if not Settings.get_v("sound"):
		return
	var now := Time.get_ticks_msec() / 1000.0
	var lv: Array = LEVEL.get(name, [-10.0, 0.05])
	if now - float(_last.get(name, -10.0)) < lv[1]:
		return
	var vol: float = lv[0]
	if pos != Vector3.INF and Game.I != null:
		var cam := Game.I.cam
		var d := Vector2(pos.x - cam.focus.x, pos.z - cam.focus.z).length()
		var reach := cam.dist * 1.3
		if d > reach:
			return
		vol -= d / reach * 14.0 + (cam.dist - 40.0) * 0.08
	_last[name] = now
	for p in players:
		if not p.playing:
			p.stream = stream(name)
			p.volume_db = vol
			p.pitch_scale = randf_range(0.92, 1.08)
			p.play()
			return


static func stream(name: String) -> AudioStreamWAV:
	if _cache.has(name):
		return _cache[name]
	var s: PackedFloat32Array
	match name:
		"rifle":
			s = _noise_burst(0.12, 55.0, 0.6)
		"cannon":
			s = _mix(_noise_burst(0.5, 9.0, 0.35), _thump(0.55, 70.0, 38.0, 7.0))
		"arty":
			s = _mix(_noise_burst(0.9, 5.0, 0.2), _thump(0.9, 55.0, 30.0, 4.5))
		"missile":
			s = _whoosh(0.8)
		"beam":
			s = _sweep(0.35, 1500.0, 500.0, 0.4)
		"boom_s":
			s = _mix(_noise_burst(0.6, 7.0, 0.15), _thump(0.6, 60.0, 30.0, 6.0))
		"boom_l":
			s = _mix(_noise_burst(1.5, 2.8, 0.08), _thump(1.4, 45.0, 22.0, 2.6))
		"click":
			s = _tone([1400.0], 0.035, 0.3, 90.0)
		"alert":
			s = _concat(_tone([880.0], 0.14, 0.35, 8.0), _silence(0.07), _tone([880.0], 0.14, 0.35, 8.0))
		"capture":
			s = _concat(_tone([523.0], 0.1, 0.3, 10.0), _tone([659.0], 0.1, 0.3, 10.0), _tone([784.0], 0.22, 0.3, 6.0))
		"rank":
			s = _concat(_tone([784.0, 1175.0], 0.12, 0.25, 9.0), _tone([1047.0, 1568.0], 0.3, 0.25, 5.0))
		"jam":
			s = _mix(_noise_burst(0.3, 3.0, 0.9), _tone([180.0], 0.3, 0.2, 3.0))
		"jet":
			s = _whoosh(1.6)
		_:
			s = _silence(0.05)
	_cache[name] = _wav(s, RATE)
	return _cache[name]


# ---------------------------------------------------------------- sentez

static func _wav(s: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var b := PackedByteArray()
	b.resize(s.size() * 2)
	for i in s.size():
		b.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = b
	return w


## Gürültü patlaması: decay üstel sönüm hızı, tone > 0 ise basit alçak geçiren (boğuk) süzgeç.
static func _noise_burst(secs: float, decay: float, tone: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / RATE
		var x := randf_range(-1.0, 1.0)
		prev = lerpf(prev, x, tone)
		s[i] = prev * exp(-t * decay) * minf(1.0, t * 400.0)
	return s


## Alçak frekanslı darbe: f0'dan f1'e inen sinüs (patlama ve top gümbürtüsü).
static func _thump(secs: float, f0: float, f1: float, decay: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := lerpf(f0, f1, t / secs)
		ph += TAU * f / RATE
		s[i] = sin(ph) * exp(-t * decay) * 0.9
	return s


static func _whoosh(secs: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var prev := 0.0
	for i in n:
		var t := float(i) / secs / RATE
		var env := sin(PI * t) * (1.0 - t * 0.5)
		prev = lerpf(prev, randf_range(-1.0, 1.0), 0.05 + t * 0.25)
		s[i] = prev * env * 1.6
	return s


static func _sweep(secs: float, f0: float, f1: float, amp: float) -> PackedFloat32Array:
	var n := int(secs * RATE)
	var s := PackedFloat32Array()
	s.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		ph += TAU * lerpf(f0, f1, t / secs) / RATE
		s[i] = sin(ph) * amp * (1.0 - t / secs)
	return s


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


static func _silence(secs: float) -> PackedFloat32Array:
	var s := PackedFloat32Array()
	s.resize(int(secs * RATE))
	return s


static func _mix(a: PackedFloat32Array, b: PackedFloat32Array) -> PackedFloat32Array:
	var n := maxi(a.size(), b.size())
	var s := PackedFloat32Array()
	s.resize(n)
	for i in n:
		s[i] = (a[i] if i < a.size() else 0.0) + (b[i] if i < b.size() else 0.0)
	return s


static func _concat(a: PackedFloat32Array, b: PackedFloat32Array, c := PackedFloat32Array()) -> PackedFloat32Array:
	var s := a.duplicate()
	s.append_array(b)
	s.append_array(c)
	return s


## Müzik: 32 saniyelik döngü; düşük, gergin bir pad (Am - F - Dm - E) ve yavaş bir davul nabzı.
## 11 kHz mono; arka plan iş parçacığında üretilir.
func _make_music() -> void:
	var rate := 11025
	var chords := [[110.0, 130.81, 164.81], [87.31, 110.0, 130.81], [73.42, 87.31, 110.0], [82.41, 103.83, 123.47]]
	var bar := 8.0
	var n := int(bar * chords.size() * rate)
	var b := PackedByteArray()
	b.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var lp := 0.0
	for i in n:
		var t := float(i) / rate
		var ci := int(t / bar) % chords.size()
		var tb := fmod(t, bar)
		var env := minf(1.0, tb / 2.0) * minf(1.0, (bar - tb) / 1.5)
		var v := 0.0
		for f in chords[ci]:
			v += sin(TAU * f * t) * 0.5 + sin(TAU * f * 2.003 * t) * 0.12
		v *= env * 0.16
		# yavaş nabız: her 2 saniyede bir boğuk davul
		var tp := fmod(t, 2.0)
		v += sin(TAU * 55.0 * tp) * exp(-tp * 6.0) * 0.35
		# rüzgâr gibi hafif gürültü
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.02)
		v += lp * 0.25
		b.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 26000.0))
	_music_data = b
