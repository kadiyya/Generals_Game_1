class_name EnemyAI
extends Node
## Yapay zekâ ordusu. Her yapay zekâ takımı (düşman ya da müttefik) için bir tane çalışır; T takımı yönetir.
## Kendi tarafının dışındaki herkes düşmandır; düşman karargâhları, noktaları ve madenleri hedeftir.
##
## Ekonomi: inşa sırası, enerji dengesi, vinç; kaynak yataklarına korumalı Maden Ocağı kurar (zorluğa göre 1-3),
## madenleri ve noktaları korumaya birlik bırakır, hasarlıların yanına onarım için birlik gönderir.
## Lojistik: ordu ileri toplanma yerinde ikmal dışındaysa İleri Harekât Üssü kurar.
## Üretim: doktrinine göre ordu kurar (ucuz birimleri çok, cezalıları az alır) ve düşmanın gördüğü
## bileşimine karşılık verir: hava gücüne hava savunma, zırha tanksavar ve İHA, dronlara EH ve lazer.
## Saldırı: ileri toplanma yerinde dalga biriktirir, görev noktası ya da en zayıf savunulan hedefe yürür;
## odaklı ateşle en zayıf düşmanı birlikte vurur; uçaklarla önce hava savunmasını susturur.
## Baskın (Orta/Zor): küçük hızlı gruplarla düşman madenlerini ve noktalarını tahrip eder.
## Yaralı birlikleri ve çöken dalgaları geri çeker; keşif yapar, füze ve doktrin yeteneği kullanır.

var T := Defs.ENEMY
const ARMY := ["tank", "at", "ifv", "spaag", "arty", "mlrs", "laser", "ew", "inf"]
const FAST := ["ifv", "tank"]
# Doktrine göre hedeflenen ordu (orta oyun): sınıf -> adet.
const MIX := {
	"iha": {inf = 4, at = 2, sdrone_fpv = 6, sdrone_bomb = 3, loiter = 4, ifv = 2, tank = 0, arty = 1, mlrs = 1, spaag = 2,
		uav_strike = 3, uav_heavy = 1, uav_kami = 3, fighter = 1, striker = 0, stealth = 0},
	"zirh": {inf = 5, at = 2, sdrone_fpv = 1, sdrone_bomb = 0, loiter = 1, ifv = 3, tank = 8, arty = 3, mlrs = 2, spaag = 2,
		uav_strike = 1, uav_heavy = 0, uav_kami = 0, fighter = 2, striker = 1, stealth = 1},
	"hava": {inf = 3, at = 2, sdrone_fpv = 0, sdrone_bomb = 0, loiter = 2, ifv = 2, tank = 3, arty = 1, mlrs = 0, spaag = 2,
		uav_strike = 2, uav_heavy = 1, uav_kami = 2, fighter = 4, striker = 3, stealth = 2},
	"fuze": {inf = 5, at = 3, sdrone_fpv = 3, sdrone_bomb = 0, loiter = 2, ifv = 2, tank = 3, arty = 2, mlrs = 3, spaag = 2,
		uav_strike = 2, uav_heavy = 1, uav_kami = 4, fighter = 2, striker = 0, stealth = 0},
	"denge": {inf = 10, at = 4, sdrone_fpv = 0, sdrone_bomb = 0, loiter = 2, ifv = 3, tank = 5, arty = 2, mlrs = 1, spaag = 2,
		uav_strike = 1, uav_heavy = 1, uav_kami = 1, fighter = 3, striker = 1, stealth = 1},
}

var acc := 0.0
var wave := 0
var claims := {}        # SupplyPoint -> piyade
var home := Vector3.ZERO
var fwd := 1.0          # üsten düşmana doğru x yönü
var mine_t := 120.0
var P: Dictionary = {}
var doc := ""
var scout = null
var scout_t := 0.0
var scout_i := 0
var wave_size := 0
var regroup_t := 0.0
var attacking := false
var goal := Vector3.INF
var stage := Vector3.ZERO
var roles := {}         # birim -> "guard" / "raid" / "escort"
var guard_at := {}      # birim -> korunan yer
var expand_dep = null   # maden kurulacak yatak
var raid_t := 150.0
var raid_target = null
var fob_t := 0.0
var stats := {kesif = 0, zayif_nokta = 0, hs_once = 0, geri_cekilme = 0, dalga_cekilme = 0, maden = 0, ileri = 0, baskin = 0, onarim = 0, odak = 0}
var _foe_seen := {}     # sınıf -> görülen düşman sayısı (her düşünmede yenilenir)


func _ready() -> void:
	P = Defs.DIFFS[Scenarios.difficulty]
	doc = Scenarios.country(T).doctrine
	raid_t = 240.0 if P.raid else 1e9


func _process(dt: float) -> void:
	acc += dt
	if acc < float(P.think):
		return
	var step := acc
	acc = 0.0
	var g := Game.I
	if g.over or g.tutorial_on:
		return
	var ts = g.teams[T]
	if ts.hq == null or not is_instance_valid(ts.hq) or not ts.hq.alive:
		return
	home = ts.hq.position
	var fh = _foe_hq(g)
	if fh != null:
		fwd = signf(fh.position.x - home.x)
		if fwd == 0.0:
			fwd = 1.0
	_census(g)
	_prune_roles()
	_build(g, ts)
	_expand(g, ts)
	_produce(g, ts)
	_capture(g)
	_guards(g)
	_army(g, ts, step)
	_raid(g, step)
	_fob(g, ts, step)
	_missiles(g, ts)
	_fieldcraft(g, ts, step)
	_ability(g, ts)
	_scout(g, step)
	_retreat(g)


# ---------------------------------------------------------------- yardımcılar

func _foe(t: int) -> bool:
	return Defs.foe(T, t)


func _units(g: Game, cls: String) -> Array:
	var out: Array = []
	for e in g.entities:
		if e.team == T and not e.is_building and e.cls == cls and e.alive:
			out.append(e)
	return out


func _count(g: Game, cls: String) -> int:
	var n := 0
	for e in g.entities:
		if e.team == T and not e.is_building and e.cls == cls and e.alive:
			n += 1
	for e in g.entities:
		if e.team == T and e.is_building:
			for id in e.queue:
				if Defs.UNITS[id].cls == cls:
					n += 1
	return n


func _blds(g: Game, kind: String) -> Array:
	var out: Array = []
	for e in g.entities:
		if e.team == T and e.is_building and e.kind == kind and e.built and e.alive:
			out.append(e)
	return out


## Düşmanın görülen birliklerinin sınıf sayımı (karşılık üretimi için).
func _census(g: Game) -> void:
	_foe_seen = {}
	for e in g.entities:
		if e.alive and not e.is_building and _foe(e.team) and g.fog.sees(T, e.global_position):
			_foe_seen[e.cls] = int(_foe_seen.get(e.cls, 0)) + 1


func _seen(classes: Array) -> int:
	var n := 0
	for c in classes:
		n += int(_foe_seen.get(c, 0))
	return n


func _prune_roles() -> void:
	for u in roles.keys():
		if not is_instance_valid(u) or not u.alive:
			roles.erase(u)
			guard_at.erase(u)


## En yakın ayakta düşman karargâhı.
func _foe_hq(g: Game):
	var best = null
	var bd := 1e9
	for t in Defs.N:
		var h = g.teams[t].hq
		if _foe(t) and h != null and is_instance_valid(h) and h.alive:
			var dd := Entity.flat(h.position, home)
			if dd < bd:
				bd = dd
				best = h
	return best


func _player_air(g: Game) -> int:
	var n := 0
	for e in g.entities:
		if _foe(e.team) and e.is_air:
			n += 1
	return n


func _site(g: Game, kind: String) -> Vector3:
	# Karargâhın çevresinde, halkalar hâlinde boş bir yer ara; düşmana bakan tarafı tercih etme (arka taraf önce).
	for r in [15.0, 24.0, 33.0, 40.0]:
		for k in 12:
			var ang: float = k * TAU / 12.0 + r * 0.07
			var p: Vector3 = home + Vector3(cos(ang), 0, sin(ang)) * r
			if kind != "sam" and (p.x - home.x) * fwd > 20.0:
				continue
			if g.can_place(T, kind, p):
				return p
	for r in [24.0, 33.0, 40.0]:
		for k in 12:
			var p: Vector3 = home + Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * r
			if g.can_place(T, kind, p):
				return p
	return Vector3.INF


func _try_build(g: Game, ts, kind: String) -> bool:
	var bd: Dictionary = Defs.BUILDINGS[Defs.bid(T, kind)]
	if ts.money < float(bd.cost) or ts.tier < int(bd.get("tier", 1)):
		return false
	var p := _site(g, kind)
	if p != Vector3.INF:
		return g.place_building(T, kind, p)
	return false


# ---------------------------------------------------------------- ekonomi ve inşa

func _build(g: Game, ts) -> void:
	# Enerji açığı varsa önce santral.
	if ts.power_used >= ts.power_prod and g.count_kind(T, "santral", false) == g.count_kind(T, "santral"):
		if _try_build(g, ts, "santral"):
			return
	var plan: Array = [["kisla", 1], ["santral", 1], ["fabrika", 1]]
	if ts.tier >= 2:
		plan += [["havaalani", 1], ["santral", 2], ["teknoloji", 1]]
		if _player_air(g) > 0 or P.smart:
			plan += [["sam", 1]]
		if int(Defs.BUILDINGS[Defs.bid(T, "fuze")].tier) <= ts.tier:
			plan += [["santral", 3], ["fuze", 1]]
	if ts.tier >= 3:
		plan += [["fabrika", 2], ["sam", 2], ["santral", 4]]
		if doc in ["hava", "iha"]:
			plan += [["havaalani", 2]]
		if doc == "denge":
			plan += [["kisla", 2]]
	for item in plan:
		if g.count_kind(T, item[0], false) < item[1]:
			_try_build(g, ts, item[0])
			return
	if ts.tier < Defs.MAX_TIER and g.time > float(P.tier) * ts.tier and g.can_upgrade(T) == "":
		g.start_tier_upgrade(T)
		return
	if ts.cranes < 2 and ts.tier >= 2 and ts.money > 1500.0:
		g.buy_crane(T)
	for b in _blds(g, "teknoloji"):
		if b.research_id == "" and ts.money > 1400.0:
			for r in _research_order():
				if g.can_research(T, r.id):
					g.start_research(b, r)
					break


## Doktrine uygun araştırma sırası.
func _research_order() -> Array:
	var first: Array = {
		"iha": ["fiber", "yz", "kafes"], "zirh": ["aps", "gudum", "kafes"], "hava": ["aesa", "yz", "eh"],
		"fuze": ["gudum", "yz", "eh"], "denge": ["kafes", "aps", "gudum"],
	}.get(doc, [])
	var out: Array = []
	for id in first:
		for r in Scenarios.RESEARCH:
			if r.id == id:
				out.append(r)
	for r in Scenarios.RESEARCH:
		if not out.has(r):
			out.append(r)
	return out


## Kaynak yataklarına maden: koruma grubu gönderir, varınca Maden Ocağını kurar.
func _expand(g: Game, ts) -> void:
	var mines := g.count_kind(T, "maden", false)
	if expand_dep != null and (not is_instance_valid(expand_dep) or not expand_dep.free_for(T) or expand_dep.depleted()):
		expand_dep = null
	if expand_dep == null:
		if mines >= int(P.expand) or g.time < 60.0:
			return
		var best = null
		var bs := 1e9
		for dp in g.deposits:
			if not is_instance_valid(dp) or not dp.free_for(T) or dp.depleted():
				continue
			var danger := 0.0
			for e in g.nearby(dp.position, 40.0):
				if e.alive and _foe(e.team) and not e.is_air and e.has_weapon():
					danger += 1.0
			var s: float = Entity.flat(dp.position, home) + danger * 80.0 - dp.rich * 10.0
			# Düşman karargâhına çok yakın yataklar riskli.
			var fh = _foe_hq(g)
			if fh != null and Entity.flat(dp.position, fh.position) < 120.0:
				s += 200.0
			if s < bs:
				bs = s
				best = dp
		expand_dep = best
		if best == null:
			return
	var dp = expand_dep
	var escort: Array = []
	for u in roles.keys():
		if roles[u] == "escort":
			escort.append(u)
	if escort.size() < 2 and _free_army(g).size() >= 3:
		for u in _free_army(g):
			if u.cls in ["ifv", "tank", "inf", "at"]:
				roles[u] = "escort"
				escort.append(u)
				if escort.size() >= 3:
					break
	for u in escort:
		if Entity.flat(u.position, dp.position) > 12.0 and u.order == "idle":
			u.go(dp.position + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), true)
	var bd: Dictionary = Defs.BUILDINGS[Defs.bid(T, "maden")]
	if ts.money >= float(bd.cost) and g.presence(T, dp.position, Defs.PRESENCE_R):
		if g.place_building(T, "maden", dp.position):
			stats.maden += 1
			# Koruma grubundan biri madenin bekçisi olur, diğerleri orduya döner.
			for i in escort.size():
				if i == 0:
					roles[escort[i]] = "guard"
					guard_at[escort[i]] = dp.position
				else:
					roles.erase(escort[i])
			expand_dep = null


## Bekçiler korudukları yerde durur; hasarlı kendi kaynaklarına onarım için birlik gönderilir.
func _guards(g: Game) -> void:
	for u in roles.keys():
		if roles[u] == "guard" and guard_at.has(u) and u.order == "idle" and u.target == null:
			if Entity.flat(u.position, guard_at[u]) > 14.0:
				u.go(guard_at[u] + Vector3(randf_range(-5, 5), 0, randf_range(-5, 5)), true)
	# onarım: hasarlı nokta ve madenler
	var hurt: Array = []
	for p in g.points:
		if p.owner_team == T and p.hp < p.max_hp * 0.75:
			hurt.append(p.position)
	for b in _blds(g, "maden"):
		if b.hp < b.max_hp * 0.75:
			hurt.append(b.position)
	var guards := 0
	for u in roles:
		if roles[u] == "guard":
			guards += 1
	for pos in hurt:
		if g.presence(T, pos, 14.0) or guards >= 2 + g.count_kind(T, "maden"):
			continue
		guards += 1
		var free := _free_army(g)
		var best = null
		var bd := 1e9
		for u in free:
			var dd := Entity.flat(u.position, pos)
			if dd < bd:
				bd = dd
				best = u
		if best != null and bd < 220.0:
			roles[best] = "guard"
			guard_at[best] = pos
			best.go(pos, true)
			stats.onarim += 1


## Görevi olmayan (ana ordudaki) kara birlikleri.
func _free_army(g: Game) -> Array:
	var out: Array = []
	for e in g.entities:
		if e.team == T and e is Unit and e.alive and not roles.has(e) and not claims.values().has(e) and e.cls in ARMY and e.cls != "inf":
			out.append(e)
	return out


# ---------------------------------------------------------------- üretim

func _queue(g: Game, b: Building, cls: String) -> bool:
	var id := g.unit_of(T, cls)
	if id == "" or b.queue.size() >= 2:
		return false
	if g.teams[T].tier < int(Defs.UNITS[id].get("tier", 1)):
		# Deneysel sürüm kilitliyse aynı sınıftan başka birim dene.
		id = ""
		for uid in b.d.get("produces", []):
			if Defs.UNITS[uid].cls == cls and g.teams[T].tier >= int(Defs.UNITS[uid].get("tier", 1)):
				id = uid
		if id == "":
			return false
	else:
		# Kademe izin veriyorsa en güçlü sürümü al (deneysel dahil), parası yetiyorsa.
		for uid in b.d.get("produces", []):
			var ud: Dictionary = Defs.UNITS[uid]
			if ud.cls == cls and g.teams[T].tier >= int(ud.get("tier", 1)) and int(ud.get("tier", 1)) > int(Defs.UNITS[id].get("tier", 1)) and g.teams[T].money > g.unit_cost(T, uid) + 800.0:
				id = uid
	if g.teams[T].money < g.unit_cost(T, id):
		return false
	return g.queue_unit(b, id)


## Hedeflenen ordu: doktrin karışımı, zamana göre ölçeklenir ve düşmanın görülen bileşimine göre düzeltilir.
func _wants(g: Game) -> Dictionary:
	var W: Dictionary = MIX.get(doc, MIX.zirh).duplicate()
	var scale := clampf(0.4 + g.time / 600.0, 0.4, 1.4)
	for k in W:
		W[k] = float(W[k]) * scale
	var air := _seen(["fighter", "striker", "stealth", "uav_strike", "uav_heavy", "uav_kami"])
	var small := _seen(["sdrone_fpv", "sdrone_bomb", "loiter", "sdrone_recon"])
	var armor := _seen(["tank", "ifv"])
	var foot := _seen(["inf", "at"])
	W.spaag = maxf(float(W.spaag), 1.0 + air * 0.5 + small * 0.2)
	W.ew = 1.0 if small >= 3 else 0.0
	W.laser = 1.0 + small * 0.15 if small >= 4 else 0.0
	W.at = float(W.at) + armor * 0.5
	W.uav_strike = float(W.uav_strike) + armor * 0.2
	W.fighter = float(W.fighter) + air * 0.4
	W.mlrs = float(W.mlrs) + foot * 0.15
	W.inf = maxf(float(W.inf), 3.0)
	W.sdrone_recon = 1.0
	W.uav_recon = 1.0 if g.teams[T].tier >= 2 else 0.0
	# Doktrinin ucuzlattığı sınıflardan biraz daha fazla.
	for k in W.keys():
		var m := g.mod(T, "cost_" + k)
		if m < 0.95:
			W[k] = float(W[k]) * 1.25
		elif m > 1.25:
			W[k] = float(W[k]) * 0.6
	return W


func _produce(g: Game, ts) -> void:
	var saving: bool = ts.tier < Defs.MAX_TIER and not ts.upgrading and g.time > float(P.tier) * ts.tier and ts.money < Defs.TIER_COST[ts.tier] + 300
	var W := _wants(g)
	for kind in ["kisla", "fabrika", "havaalani"]:
		for b in _blds(g, kind):
			if b.queue.size() >= 2:
				continue
			# en büyük eksik oranına sahip sınıf
			var best := ""
			var bs := 0.0
			for id in b.d.get("produces", []):
				var cls: String = Defs.UNITS[id].cls
				var want := float(W.get(cls, 0.0))
				if want <= 0.0 or cls == best:
					continue
				var have := float(_count(g, cls))
				var s := (want - have) / want
				if cls == "inf" and have < 3:
					s += 1.0
				if s > bs and g.unit_of(T, cls) != "":
					bs = s
					best = cls
			if best == "":
				continue
			if saving and best not in ["inf", "spaag"]:
				continue
			if best in Defs.PLANE_CLASSES and g.plane_count(T) >= Defs.PLANES_PER_AIRFIELD * g.count_kind(T, "havaalani"):
				continue
			# Madene para ayırmak: genişleme bekleniyorsa ucuz birlikler dışında biriktir.
			if expand_dep != null and ts.money < float(Defs.BUILDINGS[Defs.bid(T, "maden")].cost) + 200.0 and best not in ["inf", "at", "ifv"]:
				continue
			_queue(g, b, best)


# ---------------------------------------------------------------- noktalar

func _capture(g: Game) -> void:
	for p in claims.keys():
		var u = claims[p]
		if not is_instance_valid(u) or not u.alive or Defs.ally(T, p.owner_team):
			claims.erase(p)
	for m in _units(g, "inf"):
		if m.order != "idle" or claims.values().has(m) or roles.has(m):
			continue
		var best = null
		var bd := 1e9
		for p in g.points:
			if Defs.ally(T, p.owner_team) or claims.has(p):
				continue
			# Düşman tarafındaki noktalara erken gitme.
			var fh = _foe_hq(g)
			if fh != null and g.time < 420.0 and Entity.flat(p.position, fh.position) < Entity.flat(p.position, home):
				continue
			var dd: float = Entity.flat(m.position, p.position) + Entity.flat(home, p.position) * 0.6 - p.income * 15.0
			if dd < bd:
				bd = dd
				best = p
		if best != null:
			claims[best] = m
			m.go(best.position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)), true)


# ---------------------------------------------------------------- ordu

func _army_units(g: Game) -> Array:
	var out: Array = []
	for e in g.entities:
		if e.team == T and e is Unit and e.alive and e.cls in ARMY and not roles.has(e) and not claims.values().has(e):
			if e.cls == "inf" and (e.entrenched or e.garrison != null):
				continue
			out.append(e)
	return out


func _army(g: Game, ts, step: float) -> void:
	var army := _army_units(g)
	# Üs savunması: üsse yakın düşman kara birliği varsa ordu oraya döner.
	var threat = null
	for e in g.nearby(home, 60.0):
		if _foe(e.team) and e.alive and not e.is_air and not e.is_building and Entity.flat(e.position, home) < 55.0:
			threat = e
			break
	if threat != null:
		var near: Array = []
		for u in army:
			if Entity.flat(u.position, home) < 120.0 and u.target == null:
				near.append(u)
		if not near.is_empty():
			g.order_move(near, threat.position, true)
		_air(g, threat.position)
		return
	goal = _goal(g)
	if goal == Vector3.INF:
		return
	# Karşı taraf tutma görevini bitirmek üzereyse: bütün ordu o noktaya.
	var their := Defs.leader(1 - Defs.SIDE[T])
	var to := Scenarios.objective(their)
	if to.get("type", "") == "hold" and g.objective_fraction(their) > 0.5 and not Defs.ally(T, g.points[to.point].owner_team) and army.size() >= 3:
		goal = g.points[to.point].position
		if not attacking:
			attacking = true
			wave += 1
			wave_size = army.size()
			g.order_move(army, goal, true)
	var to_goal := goal - home
	stage = home + to_goal.normalized() * minf(to_goal.length() * 0.35, 90.0)
	stage = g.terrain.nearest_free(stage)
	regroup_t -= step
	var at_stage: Array = []
	var away_idle: Array = []
	for u in army:
		if Entity.flat(u.position, stage) < 30.0:
			at_stage.append(u)
		elif u.order == "idle" and u.target == null:
			away_idle.append(u)
	var need := mini(int(P.wave) + wave * 2, 18)
	if OS.get_cmdline_user_args().has("--aidebug") and int(g.time) % 60 < int(P.think) + 1:
		var rc := {}
		for u in roles:
			rc[roles[u]] = int(rc.get(roles[u], 0)) + 1
		print("YZ%d t=%d ordu=%d toplanma=%d gerek=%d saldiri=%s hedef=%s rol=%s talep=%d" % [T, int(g.time), army.size(), at_stage.size(), need, attacking, goal, rc, claims.size()])
	if not attacking:
		# toplanma yerine yürü
		var go: Array = []
		for u in away_idle:
			if Entity.flat(u.position, stage) > 30.0:
				go.append(u)
		if not go.is_empty():
			g.order_move(go, stage, true)
		# Uzun süre tam dalga toplanamazsa eldekiyle saldır.
		var late: bool = g.time > float(P.first) + 150.0 + wave * 90.0 and at_stage.size() >= maxi(3, need / 2)
		if g.time > float(P.first) and regroup_t <= 0.0 and (at_stage.size() >= need or late):
			attacking = true
			wave += 1
			wave_size = army.size()
			if P.smart:
				stats.zayif_nokta += 1
			g.order_move(army, goal, true)
			_strike_air(g, goal)
		elif wave == 0:
			_air(g, stage + Vector3(fwd * 20.0, 0, 0))
		return
	# saldırı sürüyor
	if not away_idle.is_empty():
		g.order_move(away_idle, goal, true)
	if not army.is_empty():
		_strike_air(g, army[0].position + (goal - army[0].position).normalized() * 12.0)
	if P.smart:
		_focus(g, army)


## Saldırı hedefi: tutulacak görev noktası, akıllıysa en zayıf savunulan değerli hedef, yoksa düşman karargâhı.
func _goal(g: Game) -> Vector3:
	var fh = _foe_hq(g)
	if fh == null:
		return Vector3.INF
	var o := Scenarios.objective(T)
	if o.get("type", "") == "hold":
		var op = g.points[o.point]
		if not Defs.ally(T, op.owner_team):
			return op.position
		# Elimizdeyse ve düşman yaklaşıyorsa noktayı savun.
		for e in g.nearby(op.position, 45.0):
			if e.alive and _foe(e.team) and not e.is_air and not e.is_building:
				return op.position
	if P.smart:
		return _weak_spot(g, fh.position)
	return fh.position


## Odaklı ateş: grubun yakınındaki en zayıf düşmanı, ona ateş edebilen birlikler birlikte vurur.
func _focus(g: Game, army: Array) -> void:
	var c := Vector3.ZERO
	var n := 0
	for u in army:
		if Entity.flat(u.position, goal) < 80.0:
			c += u.position
			n += 1
	if n < 3:
		return
	c /= n
	var weak = null
	var ws := 1e9
	for e in g.nearby(c, 26.0):
		if e.alive and _foe(e.team) and not e.is_air and not e.is_building and g.fog.sees(T, e.global_position):
			var s: float = e.hp / e.max_hp + (0.0 if e.has_weapon() else 1.0)
			if s < ws:
				ws = s
				weak = e
	if weak == null:
		return
	var k := 0
	for u in army:
		if u.has_weapon() and u.can_hit(weak) and Entity.flat(u.position, weak.position) < u.wrange() + 6.0 and u.order != "attack":
			u.attack(weak)
			k += 1
	if k > 0:
		stats.odak += 1


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
		if not _foe(e.team) or not e.alive or not g.fog.sees(T, e.global_position):
			continue
		var is_aa: bool = (e.is_building and e.kind == "sam") or e.cls in ["spaag", "laser"]
		if is_aa:
			var dd := Entity.flat(e.global_position, pos)
			if dd < bd:
				bd = dd
				best = e
	return best


## En zayıf savunulan değerli hedef: görülen düşman noktaları, madenleri ve binaları arasında, çevresindeki
## düşman birliklerinin gücüne ve uzaklığa göre en uygununu seçer.
func _weak_spot(g: Game, fallback: Vector3) -> Vector3:
	var best := fallback
	var bs := 1e9
	var cands: Array = []
	for p in g.points:
		if _foe(p.owner_team):
			cands.append([p.position, 1.0 + p.income * 0.15])
	for e in g.entities:
		if _foe(e.team) and e.is_building and (e.discovered or g.fog.sees(T, e.global_position)) and e.kind != "engel":
			var v := 1.2
			if e.kind in ["fabrika", "havaalani", "fuze", "santral"]:
				v = 2.0
			elif e.kind in ["maden", "ileri"]:
				v = 2.4
			cands.append([e.global_position, v])
	for c in cands:
		var def := 0.0
		for e in g.nearby(c[0], 24.0):
			if _foe(e.team) and e.alive and not e.is_building and e.has_weapon() and Entity.flat(e.global_position, c[0]) < 22.0:
				def += float(e.d.get("cost", 200))
		var score: float = (def + 300.0) / c[1] + Entity.flat(c[0], home) * 2.0
		if score < bs:
			bs = score
			best = c[0]
	return best


# ---------------------------------------------------------------- baskın ve lojistik

## Baskın: küçük hızlı bir grup ya da dronlar düşmanın madenine ya da en zayıf noktasına saldırır.
func _raid(g: Game, step: float) -> void:
	raid_t -= step
	var raiders: Array = []
	for u in roles.keys():
		if roles[u] == "raid":
			raiders.append(u)
	if raid_target != null and (not is_instance_valid(raid_target) or not raid_target.alive or not _foe(raid_target.team)):
		raid_target = null
		for u in raiders:
			roles.erase(u)
		raiders.clear()
	if raid_t > 0.0 or not raiders.is_empty():
		return
	raid_t = 150.0 if Scenarios.difficulty >= 2 else 220.0
	# hedef: görülen ya da keşfedilmiş düşman madeni, yoksa düşman noktası
	var best = null
	var bs := 1e9
	for e in g.entities:
		if _foe(e.team) and e.is_building and e.kind == "maden" and (e.discovered or g.fog.sees(T, e.global_position)):
			var s := Entity.flat(e.position, home)
			if s < bs:
				bs = s
				best = e
	if best == null:
		for p in g.points:
			if _foe(p.owner_team) and p.hp > 0.0:
				var s := Entity.flat(p.position, home) + (0.0 if p.kind == "supply" else -40.0)
				if s < bs:
					bs = s
					best = p
	if best == null:
		return
	raid_target = best
	var n := 0
	for u in _free_army(g):
		if u.cls in FAST:
			roles[u] = "raid"
			u.go(best.global_position, true)
			n += 1
			if n >= 4:
				break
	# küçük dronlar da katılır
	for e in g.entities:
		if e.team == T and e is AirUnit and e.alive and e.d.get("kamikaze", false):
			e.set_patrol(best.global_position)
	if n > 0:
		stats.baskin += 1
		for u in roles.keys():
			if roles[u] == "raid" and u.can_hit(best):
				u.attack(best)


## İleri Harekât Üssü: ordu toplanma yeri ikmal hattının dışındaysa oraya kurulur.
func _fob(g: Game, ts, step: float) -> void:
	fob_t -= step
	if fob_t > 0.0 or stage == Vector3.ZERO:
		return
	fob_t = 20.0
	if g.supplied(T, stage) or g.count_kind(T, "ileri", false) >= 3:
		return
	var bd: Dictionary = Defs.BUILDINGS[Defs.bid(T, "ileri")]
	if ts.money < float(bd.cost) + 300.0:
		return
	for k in 8:
		var p := stage + Vector3(cos(k * TAU / 8.0), 0, sin(k * TAU / 8.0)) * (6.0 + k)
		if g.can_place(T, "ileri", p):
			if g.place_building(T, "ileri", p):
				stats.ileri += 1
			return


# ---------------------------------------------------------------- keşif ve geri çekilme

## Keşif: bir keşif dronu ya da İHA'sı düşman noktaları, madenleri ve üssü arasında dolaşır.
func _scout(g: Game, step: float) -> void:
	if g.time < 50.0:
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
	scout_t -= step
	if scout_t > 0.0:
		return
	scout_t = float(P.scout)
	var fh = _foe_hq(g)
	var spots: Array = [fh.position if fh != null else home]
	for p in g.points:
		if not Defs.ally(T, p.owner_team):
			spots.append(p.position)
	for dp in g.deposits:
		if is_instance_valid(dp) and not dp.depleted():
			spots.append(dp.position)
	scout_i = (scout_i + 1) % spots.size()
	scout.set_patrol(spots[scout_i])
	stats.kesif += 1


## Geri çekilme: canı eşiğin altına düşen birlik geri çekilir; dalga çok erirse ileri birlikler döner.
func _retreat(g: Game) -> void:
	var away: Array = []
	for u in _army_units(g):
		if u.retreating or u.entrenched or u.garrison != null:
			continue
		if Entity.flat(u.position, home) > 60.0:
			away.append(u)
			if u.hp < u.max_hp * float(P.retreat):
				g.order_retreat([u])
				stats.geri_cekilme += 1
	if attacking and wave_size >= 4 and away.size() < wave_size * 0.35:
		if not away.is_empty():
			g.order_retreat(away)
		stats.dalga_cekilme += 1
		wave_size = 0
		attacking = false
		regroup_t = 50.0 if Scenarios.difficulty >= 2 else 70.0


# ---------------------------------------------------------------- füze, saha işleri, yetenek

func _missiles(g: Game, ts) -> void:
	for b in _blds(g, "fuze"):
		for i in b.missile_ready.size():
			var m := g.missile_info(T, i)
			if b.missile_ready[i] > 0.0 or ts.tier < int(m.tier) or ts.money < float(m.cost) + 500.0:
				continue
			# Gördüğü en değerli hedef: hava gücü varsa önce hava savunması, sonra madenler ve üretim binaları.
			var best = null
			var bs := -1.0
			for e in g.entities:
				if not _foe(e.team) or not e.is_building or not g.fog.sees(T, e.position):
					continue
				var s := 1.0
				if e.kind == "sam" and P.smart and _air_count(g) > 0:
					s = 4.0
				elif e.kind == "maden":
					s = 3.5
				elif e.kind in ["havaalani", "fabrika", "fuze"]:
					s = 3.0
				elif e.kind in ["santral", "teknoloji", "sam", "ileri"]:
					s = 2.0
				if s > bs:
					bs = s
					best = e
			if best != null:
				g.launch_missile(b, i, best.position)
				return


## Piyade: tuttuğu noktada siper kazar ya da yakındaki eve girer; ara sıra yola mayın döşer.
func _fieldcraft(g: Game, ts, step: float) -> void:
	mine_t -= step
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
		elif mine_t <= 0.0 and ts.money > 900.0 and g.team_mines(T) < 6:
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
	# Hedef: görülen düşman birliklerinin en kalabalık olduğu yer, yoksa görülen bir bina.
	var best = null
	var bn := 0
	for e in g.entities:
		if not _foe(e.team) or e.is_air or not g.fog.sees(T, e.global_position):
			continue
		var n := 0
		for o in g.nearby(e.global_position, 10.0):
			if _foe(o.team) and not o.is_air and o.alive and Entity.flat(o.global_position, e.global_position) < 10.0:
				n += 1
		if e.is_building:
			n += 1
		if n > bn:
			bn = n
			best = e
	if best != null and bn >= 3:
		g.use_ability(T, best.global_position)


func _air_count(g: Game) -> int:
	var n := 0
	for e in g.entities:
		if e.team == T and e is AirUnit and not e.d.get("small", false):
			n += 1
	return n
