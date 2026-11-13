class_name SupplyPoint
extends Entity
## Ele geçirilebilir kaynak: ikmal noktası, kasaba ya da petrol/gaz tesisi. Yalnızca piyade ele geçirir.
## Düşman tarafından tahrip edilebilir: gelir, sağlamlığıyla orantılı düşer; sıfıra inince nokta kimsesiz kalır.
## Onarım yalnızca sahibinin askerî birlikleri yanındayken ve çevrede düşman yokken ilerler.
## Sahibinin tarafına ikmal (lojistik) sağlar.

const RADIUS := 6.0
const VISION := 10.0
const REPAIR_R := 16.0
const REPAIR_RATE := 0.02      # saniyede azami sağlamlığın oranı
const SUPPLY_R := 40.0         # ikmal yarıçapı

var owner_team := Defs.NEUTRAL
var income := 2.0
var cap_time := 12.0
var kind := "supply"
var pname := ""
var is_oil := false
var cap_team := Defs.NEUTRAL
var cap_t := 0.0
var flag: MeshInstance3D
var repairing := false
var _tick := 0.0
var _smoke_t := 0.0


func setup_point(p: Vector3, inc: float, ct: float, k: String, nm: String) -> void:
	position = p
	income = inc
	cap_time = ct
	kind = k
	pname = nm
	is_oil = k == "oil"
	team = Defs.NEUTRAL
	is_building = true
	armor = "bld"
	cls = "point"
	max_hp = 2200.0 if is_oil else (1800.0 if k == "town" else 1300.0)
	hp = max_hp
	radius = 3.0
	vision = VISION
	d = {name = nm if nm != "" else ("Petrol tesisi" if is_oil else "İkmal noktası"), cost = 300, hp = max_hp, armor = "bld"}
	seen = true
	discovered = true
	model = Models.supply_point(is_oil)
	add_child(model)
	flag = Models.box(self, Vector3(1.5, 0.9, 0.06), Vector3(-1.1, 3.5, 1.6), Color(0.9, 0.9, 0.9))
	ring = Models.ring(radius + 0.4)
	ring.visible = false
	add_child(ring)


func claim(t: int) -> void:
	owner_team = t
	team = t
	flag.material_override = Models.mat(Defs.TEAM_COLORS[t] if t >= 0 else Color(0.9, 0.9, 0.9))


## Sağlamlık oranı (0..1).
func integrity() -> float:
	return clampf(hp / max_hp, 0.0, 1.0)


func current_income() -> float:
	return 0.0 if owner_team < 0 else income * integrity()


func has_weapon() -> bool:
	return false


func aim_pos() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func take_damage(amount: float, attacker = null, _tag := "") -> void:
	if owner_team < 0 or amount <= 0.0 or hp <= 0.0:
		return
	hp = maxf(0.0, hp - amount)
	if attacker != null and is_instance_valid(attacker) and attacker.alive:
		attacker.gain_xp(amount * 0.5)
	var g := Game.I
	if owner_team == Defs.PLAYER:
		g.alert_base()
	if hp <= 0.0:
		var was := owner_team
		g.fx_explosion(aim_pos(), 3.0)
		g.fx_scorch(global_position, 3.0)
		claim(Defs.NEUTRAL)
		cap_t = 0.0
		cap_team = Defs.NEUTRAL
		if Defs.friendly(was):
			g.hud.toast("%s tahrip edildi! Geri al ve askerî birlikle koru ki onarılsın." % d.name, 6.0)
		elif g.fog.sees(Defs.PLAYER, global_position):
			g.hud.toast("Düşmanın %s kaynağı tahrip edildi." % d.name)


func _process(dt: float) -> void:
	var g := Game.I
	if g == null or g.over:
		return
	# Ele geçirme: yalnızca bir tarafın piyadesi varsa ilerler.
	var who := Defs.NEUTRAL
	var sides := {}
	for e in g.nearby(position, RADIUS + 2.0):
		if e.alive and not e.is_building and e.d.get("capture", false) and Entity.flat(e.position, position) <= RADIUS:
			var s: int = Defs.SIDE[e.team]
			if not sides.has(s):
				sides[s] = e.team
	if sides.size() == 1:
		who = sides.values()[0]
	var owner_side: int = Defs.SIDE[owner_team] if owner_team >= 0 else -1
	if who != Defs.NEUTRAL and Defs.SIDE[who] != owner_side:
		if cap_team != who:
			cap_team = who
			cap_t = 0.0
		cap_t += dt
		if cap_t >= cap_time:
			claim(who)
			cap_t = 0.0
			cap_team = Defs.NEUTRAL
			g.on_point_captured(self)
	elif sides.is_empty():
		cap_t = maxf(0.0, cap_t - dt)
	_tick -= dt
	if _tick <= 0.0:
		_tick = 1.0
		_repair()
	if hp < max_hp * 0.5 and seen and owner_team >= 0 or hp <= 0.0:
		_smoke_t -= dt
		if _smoke_t <= 0.0:
			_smoke_t = 0.8
			g.fx_puff(global_position + Vector3(randf_range(-1.5, 1.5), 2.0, randf_range(-1.5, 1.5)), Color(0.16, 0.15, 0.14), 1.8, 2.4, 4.0)


## Onarım: sahibinin silahlı kara birliği yanında ve çevrede düşman yoksa sağlamlık artar.
func _repair() -> void:
	repairing = false
	if owner_team < 0 or hp >= max_hp:
		return
	var friend := false
	for e in Game.I.nearby(position, REPAIR_R + 4.0):
		if not e.alive or e.is_air or e.is_building or Entity.flat(e.global_position, position) > REPAIR_R:
			continue
		if Defs.foe(owner_team, e.team):
			return
		if e.has_weapon() and Defs.ally(owner_team, e.team):
			friend = true
	if friend:
		repairing = true
		hp = minf(max_hp, hp + max_hp * REPAIR_RATE)
