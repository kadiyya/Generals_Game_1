extends Node
## Geliştirme aracı: denge için sınıf düelloları. Aynı bütçeyle ($2400) iki sınıfı açık arazide çarpıştırır
## ve kalan değerleri yazar. İki taraf da aynı ülkenin birimlerini kullanır; yalnızca sınıflar karşılaştırılır.
## Kullanım: godot --headless --path . --fixed-fps 30 -- --duel --scn=0

const BUDGET := 2400.0
const CLASSES := ["inf", "at", "ifv", "tank", "arty", "mlrs"]


func _ready() -> void:
	_run.call_deferred()


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout


func _value(list: Array) -> float:
	var v := 0.0
	for u in list:
		if is_instance_valid(u) and u.alive:
			v += float(u.d.cost) * u.hp / u.max_hp
	return v


func _run() -> void:
	var g := Game.I
	for c in g.get_children():
		if c is EnemyAI:
			c.set_process(false)
	for p in g.points:
		p.set_process(false)
	var rows: Array = []
	for i in CLASSES.size():
		for j in range(i + 1, CLASSES.size()):
			var res := await _duel(g, CLASSES[i], CLASSES[j])
			rows.append(res)
			print("DUEL  %-5s vs %-5s  ->  %4d%% / %4d%%" % [CLASSES[i], CLASSES[j], int(res[0] * 100), int(res[1] * 100)])
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


func _duel(g: Game, a: String, b: String) -> Array:
	if arena == Vector3.INF:
		arena = _arena(g)
	var ida := _id(g, a)
	var idb := _id(g, b)
	var na := maxi(1, int(round(BUDGET / float(Defs.UNITS[ida].cost))))
	var nb := maxi(1, int(round(BUDGET / float(Defs.UNITS[idb].cost))))
	var A: Array = []
	var B: Array = []
	for k in na:
		A.append(g.spawn_unit(ida, 0, arena + Vector3(-26, 0, -4 + (k % 4) * 3.0 + (k / 4) * 2.0)))
	for k in nb:
		B.append(g.spawn_unit(idb, 1, arena + Vector3(26, 0, -4 + (k % 4) * 3.0 + (k / 4) * 2.0)))
	g.order_move(A, arena + Vector3(26, 0, 0), true)
	g.order_move(B, arena + Vector3(-26, 0, 0), true)
	var t := 0.0
	while t < 90.0 and _value(A) > 0.0 and _value(B) > 0.0:
		await _wait(1.0)
		t += 1.0
		g.fog.recompute()
	var res := [_value(A) / (float(Defs.UNITS[ida].cost) * na), _value(B) / (float(Defs.UNITS[idb].cost) * nb)]
	for u in A + B:
		if is_instance_valid(u) and u.alive:
			g.entities.erase(u)
			u.queue_free()
	await _wait(0.5)
	return res
