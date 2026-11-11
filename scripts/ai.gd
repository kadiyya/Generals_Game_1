class_name EnemyAI
extends Node
## Basit yapay zekâ rakip. Ülkesinin envanterinden sınıfa göre birim seçer:
## sırayla bina kurar, noktaları ele geçirir, dalga dalga saldırır, hava gücü ve füze kullanır.

const T := Defs.ENEMY
const FIRST_ATTACK := 450.0
const TIER_TIME := 260.0
const EXPAND_TIME := 420.0   # bu süreden önce oyuncunun yarısındaki noktalara gitmez
const ARMY := ["tank", "at", "ifv", "spaag", "arty", "mlrs", "laser"]

var acc := 0.0
var wave := 0
var claims := {}   # SupplyPoint -> piyade
var home := Vector3.ZERO
var fwd := 1.0     # üsten haritanın ortasına doğru x yönü


func _process(dt: float) -> void:
	acc += dt
	if acc < 1.5:
		return
	acc = 0.0
	var g := Game.I
	if g.over:
		return
	var ts = g.teams[T]
	if ts.hq == null or not is_instance_valid(ts.hq) or not ts.hq.alive:
		return
	home = ts.hq.position
	fwd = -signf(home.x)
	_build(g, ts)
	_produce(g, ts)
	_capture(g)
	_army(g, ts)
	_missiles(g, ts)


func _units(g: Game, cls: String) -> Array:
	var out: Array = []
	for e in g.entities:
		if e.team == T and not e.is_building and e.cls == cls and e.alive:
			out.append(e)
	return out


func _blds(g: Game, kind: String) -> Array:
	var out: Array = []
	for e in g.entities:
		if e.team == T and e.is_building and e.kind == kind and e.built and e.alive:
			out.append(e)
	return out


func _player_air(g: Game) -> int:
	var n := 0
	for e in g.entities:
		if e.team == Defs.PLAYER and e.is_air:
			n += 1
	return n


func _site(g: Game, kind: String) -> Vector3:
	# Karargâhın çevresinde, halkalar hâlinde boş bir yer ara.
	for r in [15.0, 24.0, 33.0, 40.0]:
		for k in 10:
			var ang: float = k * TAU / 10.0 + r * 0.07
			var p: Vector3 = home + Vector3(cos(ang), 0, sin(ang)) * r
			if g.can_place(T, kind, p):
				return p
	return Vector3.INF


func _try_build(g: Game, ts, kind: String) -> void:
	var bd: Dictionary = Defs.BUILDINGS[Defs.bid(T, kind)]
	if ts.money < float(bd.cost) or ts.tier < int(bd.get("tier", 1)):
		return
	var p := _site(g, kind)
	if p != Vector3.INF:
		g.place_building(T, kind, p)


func _build(g: Game, ts) -> void:
	var plan: Array = [["kisla", 1], ["santral", 1], ["fabrika", 1], ["maden", 1]]
	if ts.tier >= 2:
		plan += [["santral", 2], ["havaalani", 1], ["teknoloji", 1], ["maden", 2]]
		if int(Defs.BUILDINGS[Defs.bid(T, "fuze")].tier) <= ts.tier:
			plan += [["santral", 3], ["fuze", 1]]
	if ts.tier >= 3:
		plan += [["fabrika", 2]]
	for item in plan:
		if g.count_kind(T, item[0], false) < item[1]:
			_try_build(g, ts, item[0])
			return
	if ts.tier < Defs.MAX_TIER and g.time > TIER_TIME * ts.tier and g.can_upgrade(T) == "":
		g.start_tier_upgrade(T)
		return
	if ts.tier >= 2 and g.count_kind(T, "sam", false) == 0 and _player_air(g) > 0:
		_try_build(g, ts, "sam")
	if ts.cranes < 2 and ts.tier >= 2 and ts.money > 1500.0:
		g.buy_crane(T)
	# araştırma: parası varsa sıradakini başlat
	for b in _blds(g, "teknoloji"):
		if b.research_id == "" and ts.money > 1400.0:
			for r in Scenarios.RESEARCH:
				if g.can_research(T, r.id):
					g.start_research(b, r)
					break


func _queue(g: Game, b: Building, cls: String) -> bool:
	var id := g.unit_of(T, cls)
	if id == "" or not b.queue.is_empty():
		return false
	if g.teams[T].tier < int(Defs.UNITS[id].get("tier", 1)):
		return false
	if g.teams[T].money < g.unit_cost(T, id):
		return false
	return g.queue_unit(b, id)


func _produce(g: Game, ts) -> void:
	var inf := _units(g, "inf").size()
	var tanks := _units(g, "tank").size()
	var at := _units(g, "at").size()
	var p_air := _player_air(g)
	# Kademe atlamak için biraz biriktir.
	var saving: bool = ts.tier < Defs.MAX_TIER and not ts.upgrading and g.time > TIER_TIME * ts.tier and tanks + at >= 3
	for k in _blds(g, "kisla"):
		if inf < (3 if g.time < 300.0 else 4):
			_queue(g, k, "inf")
		elif not saving and at < tanks / 2 + 1:
			_queue(g, k, "at")
		elif not saving and wave > 0 and ts.money > 900.0:
			# saldırıya eşlik edecek küçük İHA'lar
			if not _queue(g, k, "sdrone_fpv"):
				_queue(g, k, "loiter")
	if saving:
		return
	for f in _blds(g, "fabrika"):
		if p_air > 0 and _units(g, "spaag").size() < 2:
			_queue(g, f, "spaag")
		elif ts.tier >= 2 and tanks >= 3 and _units(g, "arty").size() < 2:
			_queue(g, f, "arty")
		elif ts.tier >= 2 and tanks >= 4 and _units(g, "mlrs").size() < 1:
			_queue(g, f, "mlrs")
		elif tanks >= 2 and _units(g, "ifv").size() < 2:
			_queue(g, f, "ifv")
		else:
			_queue(g, f, "tank")
	for a in _blds(g, "havaalani"):
		if _units(g, "uav_strike").size() + _units(g, "uav_heavy").size() < 1:
			if not _queue(g, a, "uav_strike"):
				_queue(g, a, "uav_heavy")
		elif _units(g, "fighter").size() < 2:
			_queue(g, a, "fighter")
		elif _units(g, "striker").size() + _units(g, "stealth").size() < 1 and ts.money > 2200.0:
			if not _queue(g, a, "stealth"):
				_queue(g, a, "striker")
		elif wave > 0 and ts.money > 1200.0:
			_queue(g, a, "uav_kami")


func _capture(g: Game) -> void:
	for p in claims.keys():
		var u = claims[p]
		if not is_instance_valid(u) or not u.alive or p.owner_team == T:
			claims.erase(p)
	for m in _units(g, "inf"):
		if m.order != "idle" or claims.values().has(m):
			continue
		var best = null
		var bd := 1e9
		for p in g.points:
			if p.owner_team == T or claims.has(p):
				continue
			# Oyuncunun yarısındaki noktalara erken gitme.
			if g.time < EXPAND_TIME and (p.position.x - 0.0) * fwd > 5.0:
				continue
			# Kendi tarafına yakın noktalara öncelik ver.
			var dd: float = Entity.flat(m.position, p.position) + Entity.flat(home, p.position) * 0.6
			if dd < bd:
				bd = dd
				best = p
		if best != null:
			claims[best] = m
			m.go(best.position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), true)


func _army(g: Game, ts) -> void:
	var army: Array = []
	for c in ARMY:
		army += _units(g, c)
	var p_hq = g.teams[Defs.PLAYER].hq
	if p_hq == null or not is_instance_valid(p_hq):
		return
	# Üs savunması
	var threat = null
	for e in g.entities:
		if e.team == Defs.PLAYER and not e.is_air and not e.is_building and Entity.flat(e.position, home) < 42.0:
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
	var at_home: Array = []
	var away_idle: Array = []
	for u in army:
		if Entity.flat(u.position, home) < 45.0:
			at_home.append(u)
		elif u.order == "idle" and u.target == null:
			away_idle.append(u)
	if g.time > FIRST_ATTACK and at_home.size() >= mini(5 + wave * 2, 12):
		wave += 1
		g.order_move(army, p_hq.position, true)
		_air(g, p_hq.position + Vector3(fwd * -18.0, 0, 0))
		return
	if not away_idle.is_empty():
		g.order_move(away_idle, p_hq.position, true)
	if wave == 0:
		_air(g, home + Vector3(fwd * 24.0, 0, 0))
	elif not away_idle.is_empty():
		_air(g, away_idle[0].position + Vector3(fwd * 10.0, 0, 0))


func _air(g: Game, pos: Vector3) -> void:
	for e in g.entities:
		if e.team == T and e is AirUnit and e.alive and Entity.flat(e.patrol, pos) > 8.0:
			e.set_patrol(pos)


func _missiles(g: Game, ts) -> void:
	for b in _blds(g, "fuze"):
		for i in b.missile_ready.size():
			var m := g.missile_info(T, i)
			if b.missile_ready[i] > 0.0 or ts.tier < int(m.tier) or ts.money < float(m.cost) + 600.0:
				continue
			# Gördüğü en değerli hedef: önce üretim binaları, yoksa karargâh.
			var best = null
			var bs := -1.0
			for e in g.entities:
				if e.team != Defs.PLAYER or not e.is_building or not g.fog.sees(T, e.position):
					continue
				var s := 1.0
				if e.kind in ["havaalani", "fabrika", "fuze"]:
					s = 3.0
				elif e.kind in ["santral", "teknoloji", "sam"]:
					s = 2.0
				if s > bs:
					bs = s
					best = e
			if best != null:
				g.launch_missile(b, i, best.position)
				return
