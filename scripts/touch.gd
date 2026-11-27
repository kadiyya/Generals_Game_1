class_name TouchScroll
extends Node
## Parmakla kaydırma: kayıtlı ScrollContainer'lar, içlerindeki düğmelerin üstünden başlayan sürüklemeyle de kayar.
## Sürükleme eşiği aşılınca parmağın altındaki düğme o dokunuş için kapatılır (yanlışlıkla basılmasın); bırakınca
## kayma bir süre ataletle sürer. Fare ile de çalışır (proje dokunmayı fareden taklit eder).
## safe_insets(): telefonun çentik / kamera deliği gibi kesintilerinden kaçınmak için ekran kenar boşlukları.

const SLOP := 12.0

var scrolls: Array = []
var _active: ScrollContainer = null
var _start := Vector2.ZERO
var _dragging := false
var _vel := 0.0
var _coast: ScrollContainer = null
var _blocked: Array = []
var _last_t := 0


func watch(sc: ScrollContainer) -> void:
	scrolls.append(sc)


func _vertical(sc: ScrollContainer) -> bool:
	return sc.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED


func _input(ev: InputEvent) -> void:
	if ev is InputEventScreenTouch:
		if ev.index != 0:
			return
		if ev.pressed:
			_active = null
			_coast = null
			_vel = 0.0
			for sc in scrolls:
				if is_instance_valid(sc) and sc.is_visible_in_tree() and sc.get_global_rect().has_point(ev.position):
					_active = sc
					_start = ev.position
					_dragging = false
					_last_t = Time.get_ticks_msec()
		else:
			if _dragging:
				_coast = _active
				# düğmeler bu bırakma işlendikten sonra yeniden açılır
				_unblock.call_deferred()
			_active = null
			_dragging = false
	elif ev is InputEventScreenDrag and _active != null and ev.index == 0:
		if not is_instance_valid(_active):
			_active = null
			return
		var vert := _vertical(_active)
		var moved: float = (ev.position - _start).y if vert else (ev.position - _start).x
		if not _dragging and absf(moved) > SLOP:
			_dragging = true
			_block(_active, _start)
		if _dragging:
			var dlt: float = ev.relative.y if vert else ev.relative.x
			_scroll(_active, -dlt)
			var now := Time.get_ticks_msec()
			var dtm := maxf(1.0, float(now - _last_t))
			_vel = lerpf(_vel, -dlt / dtm * 1000.0, 0.5)
			_last_t = now


func _process(dt: float) -> void:
	if _coast == null or not is_instance_valid(_coast) or absf(_vel) < 20.0:
		_coast = null
		return
	_scroll(_coast, _vel * dt)
	_vel *= pow(0.04, dt)


func _scroll(sc: ScrollContainer, d: float) -> void:
	if _vertical(sc):
		sc.scroll_vertical += int(round(d))
	else:
		sc.scroll_horizontal += int(round(d))


## Sürüklemenin başladığı noktadaki düğmeleri bu dokunuş için kapatır.
func _block(sc: Control, p: Vector2) -> void:
	for b in _buttons(sc):
		if b.is_visible_in_tree() and not b.disabled and b.get_global_rect().has_point(p):
			b.disabled = true
			_blocked.append(b)


func _unblock() -> void:
	for b in _blocked:
		if is_instance_valid(b):
			b.disabled = false
	_blocked.clear()


func _buttons(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is BaseButton:
			out.append(c)
		out.append_array(_buttons(c))
	return out


## Güvenli alan dışında kalan kenar payları (görüntü birimiyle): x sol, y üst, z sağ, w alt.
static func safe_insets(vp: Viewport) -> Vector4:
	var extra := 52.0 if Settings.get_v("notch") else 0.0
	var screen := Vector2(DisplayServer.screen_get_size())
	var safe := DisplayServer.get_display_safe_area()
	if screen.x <= 0.0 or safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4(extra, 0.0, extra, 0.0)
	var vs := vp.get_visible_rect().size
	var kx := vs.x / screen.x
	var ky := vs.y / screen.y
	return Vector4(
		maxf(extra, maxf(0.0, safe.position.x) * kx),
		maxf(0.0, safe.position.y) * ky,
		maxf(extra, maxf(0.0, screen.x - safe.end.x) * kx),
		maxf(0.0, screen.y - safe.end.y) * ky)
