class_name Region
extends Node3D
## Bölge: haritada adı olan, ele geçirilecek geniş alan. Başta bağımsız kuvvetler (Defs.IND takımı) tutar; onlar
## gelen her iki orduya da saldırır, yerlerinden ayrılmaz. Bölgedeki bağımsız askerlerin hepsi ölünce RESPAWN saniye
## sonra daha zayıf bir grup yeniden belirir (bölgeyi kim tutuyorsa onunla çarpışır).
## Ele geçirme: alanda tek bir ordunun kara birliği varsa ve bağımsız kuvvet kalmadıysa CAP_TIME saniyede o tarafın olur.
## Sahibinin birliği yokken alanı yalnızca bağımsızlar tutarsa bölge yeniden tarafsızlaşır.

const RADIUS := 16.0
const CAP_TIME := 20.0
const RESPAWN := 110.0
const FIRST := ["inf", "inf", "inf", "at", "at", "ifv", "spaag", "tank"]
const WAVE := ["inf", "inf", "at"]
const WAVE_HP := 0.6

var rname := ""
var owner_side := -1
var cap_side := -1
var cap_t := 0.0
var respawn_t := -1.0       # < 0: bağımsız kuvvet var (sayılmıyor)
var waves := 0
var contested := false
var ind_n := 0
var ring: MeshInstance3D
var flag: MeshInstance3D
var _tick := 0.0


func setup_region(p: Vector3, nm: String) -> void:
	position = p
	rname = nm
	ring = Models.ring(RADIUS, Color(1.0, 1.0, 1.0))
	ring.position.y = 0.12
	add_child(ring)
	Models.cyl(self, 0.09, 0.09, 6.0, Vector3(0, 3.0, 0), Models.DARK)
	flag = Models.box(self, Vector3(2.2, 1.3, 0.06), Vector3(1.15, 5.3, 0), Color.WHITE)
	var lb := Label3D.new()
	lb.text = nm
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.font_size = 64
	lb.pixel_size = 0.02
	lb.outline_size = 14
	lb.position = Vector3(0, 7.4, 0)
	lb.no_depth_test = true
	add_child(lb)
	_paint()


## İlk savunucular: siper kazmış piyade, tanksavar, hava savunma ve zırhlı.
func garrison(first: bool) -> void:
	var g := Game.I
	var list: Array = FIRST if first else WAVE.duplicate()
	if not first and waves % 2 == 1:
		list.append("ifv")
	for i in list.size():
		var uid := g.unit_of(Defs.IND, list[i])
		if uid == "":
			uid = g.unit_of(Defs.IND, "at")
		if uid == "":
			continue
		var ang := i * TAU / list.size() + 0.3
		var r := RADIUS * (0.35 if list[i] in ["inf", "at"] else 0.6)
		var u = g.spawn_unit(uid, Defs.IND, g.terrain.nearest_free(position + Vector3(cos(ang), 0, sin(ang)) * r))
		u.guard = true
		if not first:
			u.max_hp *= WAVE_HP
			u.hp = u.max_hp
		if u.armor == "inf" and first:
			u.do_task("dig")


func _paint() -> void:
	var c := Color(0.92, 0.8, 0.3)    # bağımsız: kum sarısı
	if owner_side >= 0:
		c = Defs.TEAM_COLORS[Defs.leader(owner_side)]
	elif ind_n == 0:
		c = Color(0.9, 0.9, 0.9)
	flag.material_override = Models.mat(c)
	ring.material_override = Models.glow(c)


## Bölgeyi tutan taraf (yoksa -1).
func held_by() -> int:
	return owner_side


func _process(dt: float) -> void:
	var g := Game.I
	if g == null or g.over:
		return
	_tick -= dt
	if _tick > 0.0:
		return
	var step := 0.5 - _tick
	_tick = 0.5
	var sides := {}
	ind_n = 0
	var ind_alive := 0
	for e in g.nearby(position, RADIUS + 26.0):
		if not e.alive or e.is_air or e.is_building:
			continue
		var dd := Entity.flat(e.global_position, position)
		if e.team == Defs.IND:
			if dd <= RADIUS + 24.0:
				ind_alive += 1
			if dd <= RADIUS:
				ind_n += 1
		elif dd <= RADIUS and e.has_weapon():
			sides[Defs.SIDE[e.team]] = true
	# yeniden doğma: bölgenin bağımsız kuvveti tükenince sayaç başlar
	if ind_alive == 0:
		if respawn_t < 0.0:
			respawn_t = 0.0
		respawn_t += step
		if respawn_t >= RESPAWN:
			respawn_t = -1.0
			waves += 1
			garrison(false)
			if g.fog.sees(Defs.PLAYER, position):
				g.hud.toast("%s: bağımsız kuvvetler yeniden toplandı." % rname, 5.0)
	else:
		respawn_t = -1.0
	var before := owner_side
	contested = ind_n > 0 and not sides.is_empty() or sides.size() > 1
	if ind_n == 0 and sides.size() == 1:
		var s: int = sides.keys()[0]
		if s != owner_side:
			if cap_side != s:
				cap_side = s
				cap_t = 0.0
			cap_t += step
			if cap_t >= CAP_TIME:
				owner_side = s
				cap_t = 0.0
				cap_side = -1
	elif ind_n > 0 and sides.is_empty() and owner_side >= 0:
		# sahibi yokken bağımsızlar geri aldı
		cap_side = -2
		cap_t += step
		if cap_t >= CAP_TIME:
			owner_side = -1
			cap_t = 0.0
			cap_side = -1
	elif sides.is_empty():
		cap_t = maxf(0.0, cap_t - step)
	if owner_side != before:
		g.on_region_changed(self, before)
	_paint()


## Ele geçirme ilerlemesi (0..1) ve ilerleyen taraf.
func progress() -> float:
	return clampf(cap_t / CAP_TIME, 0.0, 1.0)
