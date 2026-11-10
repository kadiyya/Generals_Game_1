class_name EnemyAI
extends Node
## Basit yapay zekâ rakip: sırayla bina kurar, noktaları ele geçirir, dalga dalga saldırır.

const T := Defs.ENEMY
const FIRST_ATTACK := 210.0
const EXPAND_TIME := 300.0   # bu süreden önce oyuncunun yarısındaki noktalara gitmez

var acc := 0.0
var wave := 0
var claims := {}   # SupplyPoint -> manga


func _process(dt: float) -> void:
	acc += dt
	if acc < 1.0:
		return
	acc = 0.0
	var g := Game.I
	if g.over:
		return
	var ts = g.teams[T]
	if ts.hq == null or not is_instance_valid(ts.hq) or not ts.hq.alive:
		return
	_build(g, ts)
	_produce(g, ts)
	_capture(g)
	_army(g, ts)


func _mine(g: Game, id: String, built_only := false) -> Array:
	var out: Array = []
	for e in g.entities:
		if e.team == T and e.def_id == id and e.alive:
			if built_only and e.is_building and not e.built:
				continue
			out.append(e)
	return out


func _player_air(g: Game) -> int:
	var n := 0
	for e in g.entities:
		if e.team == Defs.PLAYER and e.is_air:
			n += 1
	return n


func _free_pad(g: Game):
	for p in g.pads:
		if p.team == T and p.building == null:
			return p
	return null


func _build(g: Game, ts) -> void:
	var plan: Array = [["kisla", 1], ["santral", 1], ["fabrika", 1]]
	if ts.tier >= 2:
		plan += [["santral", 2], ["iha", 1], ["fabrika", 2]]
	for item in plan:
		if _mine(g, item[0]).size() < item[1]:
			var pad = _free_pad(g)
			if pad != null and ts.supply >= float(Defs.BUILDINGS[item[0]].cost):
				g.build_on_pad(pad, item[0])
			return
	if ts.tier == 1 and not ts.upgrading and g.time > 110.0 and ts.supply >= Defs.TIER2_COST:
		g.start_tier_upgrade(T)
		return
	if ts.tier >= 2 and _mine(g, "hisar").is_empty() and _player_air(g) > 0 and ts.supply >= 450.0:
		for off in [Vector3(-9, 0, 18), Vector3(-9, 0, -18), Vector3(-20, 0, 6), Vector3(8, 0, 19)]:
			if g.place_free(T, "hisar", ts.hq.position + off):
				break


func _produce(g: Game, ts) -> void:
	var mangas := _mine(g, "manga").size()
	var tanks := _mine(g, "tank").size()
	var at := _mine(g, "tanksavar").size()
	# Kademe 2'ye geçmek için biraz biriktir.
	var saving: bool = ts.tier == 1 and not ts.upgrading and g.time > 110.0 and tanks + at >= 3
	for k in _mine(g, "kisla", true):
		if not k.queue.is_empty():
			continue
		if mangas < (3 if g.time < 200.0 else 4):
			g.queue_unit(k, "manga")
		elif not saving and at < tanks / 2 + 1:
			g.queue_unit(k, "tanksavar")
	if saving:
		return
	for f in _mine(g, "fabrika", true):
		if not f.queue.is_empty():
			continue
		if _player_air(g) > 0 and _mine(g, "korkut").size() < 2:
			g.queue_unit(f, "korkut")
		elif ts.tier >= 2 and tanks >= 3 and _mine(g, "obus").size() < 2:
			g.queue_unit(f, "obus")
		else:
			g.queue_unit(f, "tank")
	for s in _mine(g, "iha", true):
		if s.queue.is_empty() and _mine(g, "tb2").size() < 2:
			g.queue_unit(s, "tb2")


func _capture(g: Game) -> void:
	for p in claims.keys():
		var u = claims[p]
		if not is_instance_valid(u) or not u.alive or p.owner_team == T:
			claims.erase(p)
	var hq_pos: Vector3 = g.teams[T].hq.position
	for m in _mine(g, "manga"):
		if m.order != "idle" or claims.values().has(m):
			continue
		var best = null
		var bd := 1e9
		for p in g.points:
			if p.owner_team == T or claims.has(p):
				continue
			if g.time < EXPAND_TIME and p.position.x < -5.0:
				continue
			# Kendi tarafına yakın noktalara öncelik ver.
			var dd: float = Entity.flat(m.position, p.position) + Entity.flat(hq_pos, p.position) * 0.6
			if dd < bd:
				bd = dd
				best = p
		if best != null:
			claims[best] = m
			m.go(best.position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), true)


func _army(g: Game, ts) -> void:
	var hq_pos: Vector3 = ts.hq.position
	var army: Array = []
	for id in ["tank", "tanksavar", "korkut", "obus"]:
		army += _mine(g, id)
	# Üs savunması
	var threat = null
	for e in g.entities:
		if e.team == Defs.PLAYER and not e.is_air and not e.is_building and Entity.flat(e.position, hq_pos) < 34.0:
			threat = e
			break
	if threat != null:
		var idle: Array = []
		for u in army:
			if u.order == "idle" and u.target == null:
				idle.append(u)
		if not idle.is_empty():
			g.order_move(idle, threat.position, true)
		_air(g, threat.position)
		return
	var p_hq = g.teams[Defs.PLAYER].hq
	if p_hq == null or not is_instance_valid(p_hq):
		return
	var home: Array = []
	var away_idle: Array = []
	for u in army:
		if Entity.flat(u.position, hq_pos) < 32.0:
			home.append(u)
		elif u.order == "idle" and u.target == null:
			away_idle.append(u)
	if g.time > FIRST_ATTACK and home.size() >= mini(5 + wave * 2, 12):
		wave += 1
		g.order_move(army, p_hq.position, true)
		_air(g, p_hq.position + Vector3(14, 0, 0))
		return
	if not away_idle.is_empty():
		g.order_move(away_idle, p_hq.position, true)
	if wave == 0:
		_air(g, hq_pos + Vector3(-22, 0, 0))


func _air(g: Game, pos: Vector3) -> void:
	for u in _mine(g, "tb2"):
		if Entity.flat(u.patrol, pos) > 8.0:
			u.set_patrol(pos)
