class_name EnemyAI
extends Node
## Basit yapay zekâ rakip. Ülkesinin envanterinden sınıfa göre birim seçer:
## sırayla bina kurar, noktaları ele geçirir, dalga dalga saldırır, hava gücü ve füze kullanır.
## Piyade tuttuğu noktada siper kazar, yakın eve girer, yollara mayın döşer; EH aracı ve doktrin yeteneği kullanır.
## Görevi "tut" olan senaryoda saldırıları görev noktasına yöneltir.
## Zorluğa göre: düzenli keşif yapar, en zayıf savunulan hedefi seçer, hava savunmasını önce vurur,
## yaralı birlikleri ve çöken dalgaları geri çeker. Ülkesinin doktrinine uygun ordu kurar.

var T := Defs.ENEMY
const EXPAND_TIME := 420.0   # bu süreden önce oyuncunun yarısındaki noktalara gitmez
const ARMY := ["tank", "at", "ifv", "spaag", "arty", "mlrs", "laser", "ew"]
# Doktrine göre ordu yapısı: piyade sayısı, erken drone, İHA, avcı, bombacı, obüs ve roketatar sayıları.
const MIX := {
	"iha": {inf = 4, drones = true, uav = 3, fighter = 0, bomber = 0, arty = 1, mlrs = 1},
	"zirh": {inf = 4, drones = false, uav = 1, fighter = 2, bomber = 1, arty = 3, mlrs = 2},
	"hava": {inf = 3, drones = false, uav = 2, fighter = 3, bomber = 2, arty = 1, mlrs = 1},
	"fuze": {inf = 4, drones = false, uav = 2, fighter = 2, bomber = 0, arty = 1, mlrs = 2},
	"denge": {inf = 7, drones = false, uav = 1, fighter = 2, bomber = 1, arty = 2, mlrs = 1},
}

var acc := 0.0
var wave := 0
var claims := {}   # SupplyPoint -> piyade
var home := Vector3.ZERO
var fwd := 1.0     # üsten haritanın ortasına doğru x yönü
var mine_t := 120.0
var P: Dictionary = {}       # zorluk ayarları
var doc := ""                # doktrin
var scout = null
var scout_t := 0.0
var scout_i := 0
var wave_size := 0
var regroup_t := 0.0
var stats := {kesif = 0, zayif_nokta = 0, hs_once = 0, geri_cekilme = 0, dalga_cekilme = 0}


func _ready() -> void:
	P = Defs.DIFFS[Scenarios.difficulty]
	doc = Scenarios.country(T).doctrine


func _process(dt: float) -> void:
	acc += dt
	if acc < 1.5:
		return
	acc = 0.0
	var g := Game.I
	if g.over or g.tutorial_on:
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
	_fieldcraft(g, ts)
	_ability(g, ts)
	_scout(g)
	_retreat(g)


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
		if Defs.foe(T, e.team) and e.is_air:
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
	if ts.tier < Defs.MAX_TIER and g.time > float(P.tier) * ts.tier and g.can_upgrade(T) == "":
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
	var saving: bool = ts.tier < Defs.MAX_TIER and not ts.upgrading and g.time > float(P.tier) * ts.tier and tanks + at >= 3
	var W: Dictionary = MIX.get(doc, MIX.zirh)
	for k in _blds(g, "kisla"):
		if inf < (3 if g.time < 300.0 else int(W.inf)):
			_queue(g, k, "inf")
		elif not saving and at < tanks / 2 + 1:
			_queue(g, k, "at")
		elif not saving and W.drones and g.time > 120.0 and ts.money > 400.0 and _units(g, "sdrone_fpv").size() + _units(g, "sdrone_bomb").size() < 6:
			# İHA doktrini: drone'lar baştan ordunun parçası
			if randf() < 0.5 or not _queue(g, k, "sdrone_bomb"):
				_queue(g, k, "sdrone_fpv")
		elif not saving and wave > 0 and ts.money > 900.0:
			# saldırıya eşlik edecek küçük İHA'lar
			if not _queue(g, k, "sdrone_fpv"):
				_queue(g, k, "loiter")
	if saving:
		return
	var p_small := 0
	for e in g.entities:
		if Defs.foe(T, e.team) and e.is_air and e.d.get("small", false):
			p_small += 1
	for f in _blds(g, "fabrika"):
		if p_small >= 2 and _units(g, "ew").size() < 1:
			_queue(g, f, "ew")
		elif p_air > 0 and _units(g, "spaag").size() < 2:
			_queue(g, f, "spaag")
		elif ts.tier >= 2 and tanks >= 3 and _units(g, "arty").size() < int(W.arty):
			_queue(g, f, "arty")
		elif ts.tier >= 2 and tanks >= 4 and _units(g, "mlrs").size() < int(W.mlrs):
			_queue(g, f, "mlrs")
		elif tanks >= 2 and _units(g, "ifv").size() < 2:
			_queue(g, f, "ifv")
		else:
			_queue(g, f, "tank")
	for a in _blds(g, "havaalani"):
		if _units(g, "uav_strike").size() + _units(g, "uav_heavy").size() < int(W.uav):
			if not _queue(g, a, "uav_strike"):
				_queue(g, a, "uav_heavy")
		elif _units(g, "fighter").size() < int(W.fighter):
			_queue(g, a, "fighter")
		elif _units(g, "striker").size() + _units(g, "stealth").size() < int(W.bomber) and ts.money > 2200.0:
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
			if Defs.ally(T, p.owner_team) or claims.has(p):
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
	var p_hq = _foe_hq(g)
	if p_hq == null:
		return
	# Üs savunması
	var threat = null
	for e in g.entities:
		if Defs.foe(T, e.team) and not e.is_air and not e.is_building and Entity.flat(e.position, home) < 42.0:
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
	var goal: Vector3 = p_hq.position
	var o := Scenarios.objective(T)
	if o.get("type", "") == "hold" and not Defs.ally(T, g.points[o.point].owner_team):
		goal = g.points[o.point].position
	if P.smart and goal == p_hq.position:
		goal = _weak_spot(g, p_hq.position)
	regroup_t -= 1.5
	if g.time > float(P.first) and regroup_t <= 0.0 and at_home.size() >= mini(int(P.wave) + wave * 2, 12):
		wave += 1
		wave_size = army.size()
		if goal != p_hq.position:
			stats.zayif_nokta += 1
		g.order_move(army, goal, true)
		_strike_air(g, goal)
		return
	if not away_idle.is_empty():
		g.order_move(away_idle, goal, true)
	if wave == 0:
		_air(g, home + Vector3(fwd * 24.0, 0, 0))
	elif not away_idle.is_empty():
		_strike_air(g, away_idle[0].position + Vector3(fwd * 10.0, 0, 0))


func _air(g: Game, pos: Vector3) -> void:
	for e in g.entities:
		if e.team == T and e is AirUnit and e.alive and e != scout and Entity.flat(e.patrol, pos) > 8.0:
			e.set_patrol(pos)


## Saldırıda hava gücü: önce görülen düşman hava savunmasını uçaklar ve topçu vurur; İHA'lar
## hava savunması susana kadar geride bekler. Akıllı değilse hepsi doğrudan hedefe gider.
func _strike_air(g: Game, pos: Vector3) -> void:
	if not P.smart:
		_air(g, pos)
		return
	var aa = _nearest_aa(g, pos)
	for e in g.entities:
		if e.team != T or not e.alive or e == scout:
			continue
		if e is AirUnit:
			if aa == null:
				e.set_patrol(pos)
			elif e.cls in Defs.PLANE_CLASSES:
				g.order_attack([e], aa)
				stats.hs_once += 1
			elif not e.d.get("small", false):
				e.set_patrol(home + (pos - home) * 0.45)
			else:
				e.set_patrol(pos)
		elif aa != null and e.cls in ["arty", "mlrs"] and e is Unit and e.can_hit(aa):
			e.attack(aa)


func _nearest_aa(g: Game, pos: Vector3):
	var best = null
	var bd := 50.0
	for e in g.entities:
		if not Defs.foe(T, e.team) or not e.alive or not g.fog.sees(T, e.global_position):
			continue
		var is_aa: bool = (e.is_building and e.kind == "sam") or e.cls in ["spaag", "laser"]
		if is_aa:
			var dd := Entity.flat(e.global_position, pos)
			if dd < bd:
				bd = dd
				best = e
	return best


## En zayıf savunulan değerli hedef: görülen oyuncu noktaları ve binaları arasında,
## çevresindeki oyuncu birliklerinin gücüne göre en az savunulanı seçer.
func _weak_spot(g: Game, fallback: Vector3) -> Vector3:
	var best := fallback
	var bs := 1e9
	var cands: Array = []
	for p in g.points:
		if Defs.foe(T, p.owner_team):
			cands.append([p.position, 1.0 + p.income * 0.1])
	for e in g.entities:
		if Defs.foe(T, e.team) and e.is_building and e.discovered and e.kind != "engel":
			cands.append([e.global_position, 2.0 if e.kind in ["fabrika", "havaalani", "fuze", "santral"] else 1.2])
	for c in cands:
		var def := 0.0
		for e in g.entities:
			if Defs.foe(T, e.team) and e.alive and not e.is_building and e.has_weapon() and Entity.flat(e.global_position, c[0]) < 22.0:
				def += float(e.d.get("cost", 200))
		var score: float = (def + 300.0) / c[1] + Entity.flat(c[0], home) * 2.0
		if score < bs:
			bs = score
			best = c[0]
	return best


## Keşif: bir keşif dronu ya da İHA'sı oyuncunun noktaları ve üssü arasında dolaşır.
func _scout(g: Game) -> void:
	if g.time < 60.0:
		return
	if scout == null or not is_instance_valid(scout) or not scout.alive:
		scout = null
		for e in g.entities:
			if e.team == T and e is AirUnit and e.alive and e.cls in ["uav_recon", "sdrone_recon"]:
				scout = e
				break
		if scout == null:
			for k in _blds(g, "kisla"):
				_queue(g, k, "sdrone_recon")
				break
			return
	scout_t -= 1.5
	if scout_t > 0.0:
		return
	scout_t = float(P.scout)
	var fh = _foe_hq(g)
	var spots: Array = [fh.position if fh != null else home]
	for p in g.points:
		if p.owner_team != T:
			spots.append(p.position)
	scout_i = (scout_i + 1) % spots.size()
	scout.set_patrol(spots[scout_i])
	stats.kesif += 1


## Geri çekilme: canı eşiğin altına düşen birlik geri çekilir; dalga yarıdan fazla erirse
## ileri birliklerin hepsi üsse döner ve bir süre yeniden toplanır.
func _retreat(g: Game) -> void:
	var away: Array = []
	for c in ARMY:
		for u in _units(g, c):
			if u.retreating or u.entrenched or u.garrison != null:
				continue
			if Entity.flat(u.position, home) > 45.0:
				away.append(u)
				if u.hp < u.max_hp * float(P.retreat):
					g.order_retreat([u])
					stats.geri_cekilme += 1
	if wave > 0 and wave_size >= 4 and away.size() > 0 and away.size() < wave_size * 0.4:
		g.order_retreat(away)
		stats.dalga_cekilme += 1
		wave_size = 0
		regroup_t = 60.0


func _missiles(g: Game, ts) -> void:
	for b in _blds(g, "fuze"):
		for i in b.missile_ready.size():
			var m := g.missile_info(T, i)
			if b.missile_ready[i] > 0.0 or ts.tier < int(m.tier) or ts.money < float(m.cost) + 600.0:
				continue
			# Gördüğü en değerli hedef: hava gücü varsa önce hava savunması, sonra üretim binaları.
			var best = null
			var bs := -1.0
			for e in g.entities:
				if not Defs.foe(T, e.team) or not e.is_building or not g.fog.sees(T, e.position):
					continue
				var s := 1.0
				if e.kind == "sam" and P.smart and _air_count(g) > 0:
					s = 4.0
				elif e.kind in ["havaalani", "fabrika", "fuze"]:
					s = 3.0
				elif e.kind in ["santral", "teknoloji", "sam"]:
					s = 2.0
				if s > bs:
					bs = s
					best = e
			if best != null:
				g.launch_missile(b, i, best.position)
				return


## Piyade: tuttuğu noktada siper kazar ya da yakındaki eve girer; ara sıra yola mayın döşer.
func _fieldcraft(g: Game, ts) -> void:
	mine_t -= 1.5
	for m in _units(g, "inf") + _units(g, "at"):
		if m.order != "idle" or m.target != null or m.entrenched or m.garrison != null or claims.values().has(m):
			continue
		var near_point := false
		for p in g.points:
			if p.owner_team == T and Entity.flat(p.position, m.position) < 10.0:
				near_point = true
		if not near_point:
			continue
		var house = null
		for h in g.houses:
			if h.has_room(T) and Entity.flat(h.position, m.position) < 16.0:
				house = h
		if house != null and randf() < 0.5:
			m.enter(house)
		elif mine_t <= 0.0 and ts.money > 700.0 and g.team_mines(T) < 6:
			mine_t = 60.0
			m.rotation.y = PI * 0.5 * fwd
			m.do_task("mine")
		else:
			m.do_task("dig")


## Doktrin yeteneği: saldırı başladıktan sonra, hazır olunca kullanır.
func _ability(g: Game, ts) -> void:
	if wave == 0 or g.ability_ready(T) != "":
		return
	var a := g.ability(T)
	if not a.target:
		if a.id == "ikmal" and _units(g, "fighter").size() + _units(g, "striker").size() + _units(g, "stealth").size() == 0:
			return
		g.use_ability(T, Vector3.INF)
		return
	# Hedef: görülen oyuncu birliklerinin en kalabalık olduğu yer, yoksa görülen bir bina.
	var best = null
	var bn := 0
	for e in g.entities:
		if not Defs.foe(T, e.team) or e.is_air or not g.fog.sees(T, e.global_position):
			continue
		var n := 0
		for o in g.entities:
			if Defs.foe(T, o.team) and not o.is_air and Entity.flat(o.global_position, e.global_position) < 10.0:
				n += 1
		if e.is_building:
			n += 1
		if n > bn:
			bn = n
			best = e
	if best != null and bn >= 3:
		g.use_ability(T, best.global_position)


## En yakın ayakta düşman karargâhı.
func _foe_hq(g: Game):
	var best = null
	var bd := 1e9
	for t in Defs.N:
		var h = g.teams[t].hq
		if Defs.foe(T, t) and h != null and is_instance_valid(h) and h.alive:
			var dd := Entity.flat(h.position, home)
			if dd < bd:
				bd = dd
				best = h
	return best


func _air_count(g: Game) -> int:
	var n := 0
	for e in g.entities:
		if e.team == T and e is AirUnit and not e.d.get("small", false):
			n += 1
	return n
