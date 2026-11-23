extends Node
## Geliştirme aracı: denge için sınıf düelloları. Aynı bütçeyle ($2400) iki tarafı açık arazide çarpıştırır
## ve her tarafın elinde kalan değeri (bütçenin yüzdesi, cana göre) yazar.
## Kullanım: godot --headless --path . --fixed-fps 30 -- --duel --scn=0 [--hepsi | --cift=ifv,tank]
##   varsayılan: kara sınıfları birbirine karşı (aynı ülke, sınıfın temel fiyatı)
##   --hepsi: ayrıca hava savunma araçları, hava birimleri kara birimlerine karşı, ve ayna düellolar
##            (aynı sınıf, iki ülkenin kendi birimi, doktrin fiyatıyla). Satırlar "DUEL", "HAVA", "AYNA" ile başlar.

const BUDGET := 2400.0
const CLASSES := ["inf", "at", "ifv", "tank", "arty", "mlrs"]
const CLASSES_ALL := ["inf", "at", "ifv", "tank", "arty", "mlrs", "spaag", "ads"]
const AIR := ["sdrone_fpv", "loiter", "sdrone_bomb", "uav_strike", "uav_kami", "fighter", "striker"]
const AIR_VS := ["inf", "at", "ifv", "tank", "spaag", "ads"]


func _ready() -> void:
	_run.call_deferred()


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		if is_instance_valid(u) and u.alive:
			v += float(u.get_meta("price", u.d.cost)) * u.hp / u.max_hp
	return v


func _run() -> void:
	var g := Game.I
	for c in g.get_children():
		if c is EnemyAI:
			c.set_process(false)
	for p in g.points:
		p.set_process(false)
	# Düello haritanın ortasında olur: bir takım ikmal hattında, öbürü dışında kalmasın.
	g.no_supply_rules = true
	# Karargâhlar düellodan etkilenmesin (uzağa giden dron vurup maçı bitirmesin).
	for t in Defs.N:
		var hq = g.teams[t].hq
		if hq != null:
			hq.max_hp = 1e12
			hq.hp = 1e12
	# --cift=a,b: yalnızca bu iki sınıfın düellosu (hızlı deneme)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--cift="):
			var pr: PackedStringArray = arg.trim_prefix("--cift=").split(",")
			var rp := await _duel(g, pr[0], pr[1])
			if not rp.is_empty():
				print("DUEL  %-5s vs %-5s  ->  %4d%% / %4d%%" % [pr[0], pr[1], int(rp[0] * 100), int(rp[1] * 100)])
			get_tree().quit()
			return
	var all := OS.get_cmdline_user_args().has("--hepsi")
	# kontrol: iki tarafta birebir aynı birim; sonuç eşit çıkmalı (düzenek adil mi)
	for c in ["inf", "ifv"]:
		var cid := _id(g, c)
		var rc := await _duel(g, c, c, false, cid)
		print("KONTROL  %-5s (%s) iki tarafta  ->  %4d%% / %4d%%" % [c, Defs.UNITS[cid].name, int(rc[0] * 100), int(rc[1] * 100)])
	var cl: Array = CLASSES_ALL if all else CLASSES
	for i in cl.size():
		for j in range(i + 1, cl.size()):
			var res := await _duel(g, cl[i], cl[j])
			if res.is_empty():
				continue
			print("DUEL  %-5s vs %-5s  ->  %4d%% / %4d%%" % [cl[i], cl[j], int(res[0] * 100), int(res[1] * 100)])
	if all:
		for a in AIR:
			for b in AIR_VS:
				var r2 := await _duel(g, a, b)
				if r2.is_empty():
					continue
				print("HAVA  %-11s vs %-5s  ->  %4d%% / %4d%%" % [a, b, int(r2[0] * 100), int(r2[1] * 100)])
		for c in CLASSES_ALL + AIR:
			var ia := g.unit_of(0, c)
			var ib := g.unit_of(1, c)
			if ia == "" or ib == "":
				continue
			var r3 := await _duel(g, c, c, true)
			print("AYNA  %-11s %s(%s $%d) vs %s(%s $%d)  ->  %4d%% / %4d%%" % [c, Defs.COUNTRY[0], Defs.UNITS[ia].name, g.unit_cost(0, ia),
				Defs.COUNTRY[1], Defs.UNITS[ib].name, g.unit_cost(1, ib), int(r3[0] * 100), int(r3[1] * 100)])
	get_tree().quit()


## Sınıfın birimi: önce oyuncunun ülkesinden, yoksa (ör. Ukrayna'nın tankı yok) rakibinkinden.
func _id(g: Game, cls: String) -> String:
	var id := g.unit_of(0, cls)
	return id if id != "" else g.unit_of(1, cls)


## Düello alanı: 60 x 16'lık açık düz arazi.
func _arena(g: Game) -> Vector3:
	var ter := g.terrain
	for rr in range(0, 300, 10):
		for k in 16:
			var c := Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0) * 0.6) * rr
			var ok := true
			for x in range(-32, 33, 2):
				for z in range(-8, 9, 2):
					var q := c + Vector3(x, 0, z)
					if ter.kind_at(q) != Terrain.LAND or ter.solid(q):
						ok = false
						break
				if not ok:
					break
			if ok:
				return c
	return Vector3.ZERO


var arena := Vector3.INF


## Taraf avantajını ve diziliş şansını azaltmak için her düello dört kez (iki yön × iki diziliş) oynanır; sonuç ortalamadır.
func _duel(g: Game, a: String, b: String, mirror := false, same := "") -> Array:
	var sum := [0.0, 0.0]
	for k in 4:
		var r := await _duel1(g, a, b, mirror, k % 2 == 1, same, 7.0 * (k / 2))
		if r.is_empty():
			return r
		sum[0] += r[0] * 0.25
		sum[1] += r[1] * 0.25
	return sum


## mirror: iki taraf kendi ülkesinin birimini doktrin fiyatıyla alır (ülke karşılaştırması).
## flip: A doğuda, B batıda başlar. same: iki tarafa da bu birim (kontrol düellosu).
func _duel1(g: Game, a: String, b: String, mirror: bool, flip: bool, same: String, dz := 0.0) -> Array:
	if g.over:
		print("UYARI  mac bitmis: ", g.end_reason)
		g.over = false
		get_tree().paused = false
	if arena == Vector3.INF:
		arena = _arena(g)
	var ida := g.unit_of(0, a) if mirror else _id(g, a)
	var idb := g.unit_of(1, b) if mirror else _id(g, b)
	if same != "":
		ida = same
		idb = same
	if ida == "" or idb == "":
		return []   # bu senaryodaki iki ülkede de o sınıf yok
	var pa := float(g.unit_cost(0, ida)) if mirror else float(Defs.UNITS[ida].cost)
	var pb := float(g.unit_cost(1, idb)) if mirror else float(Defs.UNITS[idb].cost)
	var sx := -1.0 if flip else 1.0
	var A := _buy(g, ida, 0, pa, arena + Vector3(-26 * sx, 0, dz))
	var B := _buy(g, idb, 1, pb, arena + Vector3(26 * sx, 0, -dz))
	for side in [[A, arena + Vector3(26 * sx, 0, 0)], [B, arena + Vector3(-26 * sx, 0, 0)]]:
		var ground: Array = []
		for u in side[0]:
			if u is AirUnit:
				u.set_patrol(side[1])
			else:
				ground.append(u)
		if not ground.is_empty():
			g.order_move(ground, side[1], true)
	var spent_a := _value(A)
	var spent_b := _value(B)
	var t := 0.0
	while t < 90.0 and _value(A) > 0.0 and _value(B) > 0.0:
		await _wait(1.0)
		t += 1.0
		g.fog.recompute()
	var res := [_value(A) / spent_a, _value(B) / spent_b]
	for u in A + B:
		if is_instance_valid(u) and u.alive:
			g.entities.erase(u)
			u.queue_free()
	await _wait(0.5)
	return res


## Bütçe kadar birim alır (paket birimler, ör. 3'lü FPV, adet kadar çıkar). Hava birimleri üstte belirir.
func _buy(g: Game, id: String, team: int, price: float, at: Vector3) -> Array:
	var d: Dictionary = Defs.UNITS[id]
	var n := maxi(1, int(round(BUDGET / price)))
	var per := int(d.get("count", 1))
	var out: Array = []
	for k in n:
		for c in per:
			var u = g.spawn_unit(id, team, at + Vector3(0, 0, -4 + (k % 4) * 3.0 + (k / 4) * 2.0 + c * 0.7))
			u.set_meta("price", price / per)
			out.append(u)
	return out
