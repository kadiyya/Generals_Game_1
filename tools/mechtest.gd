extends Node
## Geliştirme aracı: oynanış mekaniklerini tek tek doğrular (arazi, EH, siper, ev, mayın, engel, rütbe,
## geri çekilme, görev, doktrin yeteneği, birim kartı). Harkiv haritası (1. senaryo, Ukrayna) gerekir.
## Kullanım: godot --headless --path . --fixed-fps 30 -- --mechtest --scn=0 --side=0

var fails := 0
var out_dir := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			out_dir = a.trim_prefix("--shots=")
	_run.call_deferred()


func _shot(name: String) -> void:
	if out_dir == "" or DisplayServer.get_name() == "headless":
		return
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))


func _check(name: String, ok: bool) -> void:
	print(("GECTI  " if ok else "KALDI  ") + name)
	if not ok:
		fails += 1


func _wait(secs: float) -> void:
	await get_tree().create_timer(secs, false).timeout


## Oyuncunun karargâhına en yakın, çevresi (r hücre) aynı türden olan hücrenin merkezi.
func _find(kind: int, r := 0, from := Vector3.INF) -> Vector3:
	var ter := Game.I.terrain
	if from == Vector3.INF:
		from = Game.I.teams[0].hq.position
	var best := Vector3.INF
	var bd := 1e9
	for y in range(r, ter.gh - r):
		for x in range(r, ter.gw - r):
			if ter.kind[y * ter.gw + x] != kind:
				continue
			var ok := true
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if ter.kind[(y + dy) * ter.gw + x + dx] != kind:
						ok = false
			if not ok:
				continue
			var w := ter.center(Vector2i(x, y))
			var dd := Entity.flat(w, from)
			if dd < bd:
				bd = dd
				best = w
	return best


## p'den başlayarak düz, boş kara bulur (yakındaki ilk uygun yer).
func _land(p: Vector3) -> Vector3:
	var ter := Game.I.terrain
	for rr in range(0, 60, 2):
		for k in 16:
			var q := p + Vector3(cos(k * TAU / 16.0), 0, sin(k * TAU / 16.0)) * rr
			var ok := true
			for off in [Vector3.ZERO, Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3)]:
				if ter.kind_at(q + off) != Terrain.LAND or ter.solid(q + off):
					ok = false
			if ok:
				return q
	return p


## Aradaki bütün hücreleri boş kara olan, aralarında d uzaklık bulunan iki nokta.
func _open_pair(d: float) -> Array:
	var ter := Game.I.terrain
	var hq: Vector3 = Game.I.teams[0].hq.position
	for rr in range(50, 200, 6):
		for k in 12:
			var a := hq + Vector3(cos(k * TAU / 12.0), 0, sin(k * TAU / 12.0)) * rr
			var b := a + Vector3(d, 0, 0)
			var ok := true
			for i in int(d) + 1:
				var q := a.lerp(b, float(i) / d)
				if ter.kind_at(q) != Terrain.LAND or ter.solid(q):
					ok = false
					break
			for e in Game.I.entities:
				if e.alive and e.team != 0 and (Entity.flat(e.global_position, a) < 30.0 or Entity.flat(e.global_position, b) < 30.0):
					ok = false
			if ok:
				return [a, b]
	return [hq, hq + Vector3(d, 0, 0)]


func _run() -> void:
	var g := Game.I
	for c in g.get_children():
		if c is EnemyAI:
			c.set_process(false)
	g.teams[0].money = 50000.0
	g.teams[1].money = 50000.0
	var ter := g.terrain
	var hq: Vector3 = g.teams[0].hq.position
	g.cam.focus = hq
	g.cam.dist = 95.0
	await _shot("arazi")

	# ---- arazi
	var tl := _find(Terrain.TREES)
	_check("agac hatti dogrudan atisi keser", not ter.los_clear(tl + Vector3(-7, 0, 0), tl + Vector3(7, 0, 0)) or not ter.los_clear(tl + Vector3(0, 0, -7), tl + Vector3(0, 0, 7)))
	var op := _open_pair(20.0)
	_check("acik arazide gorus hatti acik", ter.los_clear(op[0], op[1]))
	_check("yol hizlandirir", ter.speed_mult(_find(Terrain.ROAD), "heavy") > 1.2)
	var deep := _find(Terrain.FOREST, 3)
	_check("orman araci yavaslatir", ter.speed_mult(deep, "heavy") < 0.7)
	var hill := _find(Terrain.HILL, 2)
	var flat_v = g.spawn_unit(g.unit_of(0, "ifv"), 0, op[0])
	var hill_v = g.spawn_unit(g.unit_of(0, "ifv"), 0, hill)
	_check("tepede menzil artar", hill_v.wrange() > flat_v.wrange() * 1.1)
	_check("tepeden atis daha cok hasar verir", hill_v.damage_base() > flat_v.damage_base() * 1.1)
	_check("tepe yuksektir", ter.height(hill) > 0.5)
	hill_v.die()
	flat_v.die()
	_check("yol bulma yollari tercih eder", ter.astar.get_point_weight_scale(ter.cell(_find(Terrain.ROAD))) < 1.0)
	_check("haritada kopru, kasaba ve terk edilmis bina var", g.bridges.size() >= 3 and g.houses.size() >= 20)
	var kinds := {}
	for h in g.houses:
		kinds[h.tp] = true
	_check("ev, apartman ve fabrika harabesi turleri var", kinds.has("house") and kinds.has("block") and kinds.has("factory"))

	# ---- orman gizlenmesi
	var hider = g.spawn_unit(g.unit_of(1, "inf"), 1, deep)
	var watcher = g.spawn_unit(g.unit_of(0, "inf"), 0, _land(deep + Vector3(0, 0, 30)))
	g.fog.recompute()
	_check("ormandaki dusman piyadesi uzaktan gorulmez", not hider.seen and hider.concealed())
	watcher.position = deep + Vector3(0, 0, 6)
	g.fog.recompute()
	_check("ormandaki piyade yakindan gorulur", hider.seen)
	var hv_tank = g.spawn_unit(g.unit_of(1, "tank"), 1, deep + Vector3(4, 0, 0))
	await _wait(0.3)
	_check("ormanda duran arac da gizlenir", hv_tank.concealed())
	for e in [hider, watcher, hv_tank]:
		e.die()

	# ---- elektronik harp
	var ewp := _land(hq + Vector3(60, 0, 0))
	var ew = g.spawn_unit(g.unit_of(0, "ew"), 0, ewp)
	var fpv = g.spawn_unit(g.unit_of(1, "sdrone_fpv"), 1, ewp + Vector3(6, 0, 0))
	fpv.set_patrol(ewp + Vector3(6, 0, 0))
	var orion = g.spawn_unit(g.unit_of(1, "uav_strike"), 1, ewp + Vector3(4, 0, 4))
	orion.set_patrol(ewp + Vector3(4, 0, 4))
	await _wait(2.0)
	_check("EH kucuk dronu dusurur", not is_instance_valid(fpv) or not fpv.alive)
	_check("EH buyuk IHA'nin kilidini bozar", is_instance_valid(orion) and orion.jammed_t > 0.0)
	g.teams[1].researched.append("fiber")
	var fpv2 = g.spawn_unit(g.unit_of(1, "sdrone_fpv"), 1, ewp + Vector3(6, 0, 0))
	fpv2.set_patrol(ewp + Vector3(6, 0, 0))
	g._ew_tick(1.0)
	_check("fiber optik FPV EH'den etkilenmez", fpv2.alive and fpv2.hp >= fpv2.max_hp)
	for e in [ew, fpv2, orion]:
		if is_instance_valid(e) and e.alive:
			e.die()

	# ---- siper
	var a = g.spawn_unit(g.unit_of(0, "inf"), 0, _land(hq + Vector3(25, 0, 10)))
	var b = g.spawn_unit(g.unit_of(0, "inf"), 0, _land(hq + Vector3(25, 0, 22)))
	g.order_task([a], "dig")
	await _wait(Defs.DIG_TIME + 0.6)
	_check("piyade siper kazar", a.entrenched and a.trench != null)
	var ha: float = a.hp
	var hb: float = b.hp
	a.take_damage(100.0)
	b.take_damage(100.0)
	_check("siperdeki piyade yari hasar alir", is_equal_approx(ha - a.hp, 50.0) and is_equal_approx(hb - b.hp, 100.0))
	a.go(a.position + Vector3(5, 0, 0), false)
	_check("hareket edince siper bozulur", not a.entrenched)

	# ---- ev
	var house = null
	for h in g.houses:
		if h.tp == "house" and (house == null or Entity.flat(h.position, hq) < Entity.flat(house.position, hq)):
			house = h
	var c = g.spawn_unit(g.unit_of(0, "inf"), 0, house.position + Vector3(8, 0, 6))
	g.order_enter([c], house)
	await _wait(6.0)
	_check("piyade eve girer", c.garrison == house and house.owner_team() == 0)
	var hc: float = c.hp
	c.take_damage(100.0)
	_check("evdeki piyade %60 az hasar alir", is_equal_approx(hc - c.hp, 40.0))
	_check("evdeki piyadenin menzili artar", c.wrange() > float(c.d.range) + 2.0)
	_check("dolu eve dusman giremez", not house.has_room(1))

	# ---- mayın
	var mp := _land(hq + Vector3(50, 0, 30))
	_check("mayin dosenir", g.place_mine(0, mp) and g.team_mines(0) == 1)
	var victim = g.spawn_unit(g.unit_of(1, "tank"), 1, mp)
	var hv: float = victim.hp
	await _wait(0.6)
	_check("mayin dusman aracinda patlar", victim.hp < hv - 100.0 and g.team_mines(0) == 0)

	# ---- engel kurma emri kaldırıldı
	var eng_inf = g.spawn_unit(g.unit_of(0, "inf"), 0, _land(hq + Vector3(50, 0, -20)))
	_check("engel kur emri yok", g.order_task([eng_inf], "obstacle") == 0)
	eng_inf.die()

	# ---- rütbe ve geri çekilme
	var vet = g.spawn_unit(g.unit_of(0, "ifv"), 0, _land(hq + Vector3(30, 0, 30)))
	var base: float = vet.damage_base()
	vet.gain_xp(float(vet.d.cost) * Defs.RANK_XP[0] + 1.0)
	_check("hasar veren birim terfi eder", vet.rank == 1)
	_check("rutbe hasari artirir", vet.damage_base() > base * 1.1)
	g.order_retreat([vet])
	_check("geri cekilen birlik az hasar alir", vet.retreating and vet.damage_taken_mult() < 0.7)

	# ---- görev
	var o := Scenarios.objective(0)
	g.points[o.point].claim(0)
	g._objective(0, 150.0)
	_check("gorev noktasini tutmak ilerleme saglar", g.teams[0].obj_prog >= 150.0 and g.objective_fraction(0) > 0.2)
	g.points[o.point].claim(Defs.NEUTRAL)
	g.teams[0].obj_prog = 0.0

	# ---- doktrin yeteneği (Ukrayna: Sürü Saldırısı)
	var before := g.entities.size()
	var spot: Vector3 = g.teams[0].hq.position + Vector3(20, 0, 0)
	g.fog.recompute()
	_check("doktrin yetenegi kullanilir", g.use_ability(0, spot) and g.entities.size() >= before + 8)
	_check("yetenek beklemeye girer", g.ability_ready(0) != "")

	# ---- birim kartı
	var k := g.spawn_building(Defs.bid(0, "kisla"), 0, g.teams[0].hq.position + Vector3(14, 0, 14), true)
	g.select([k])
	await _wait(0.3)
	var card: Button = null
	for btn in g.hud.actions.get_children():
		if btn.has_node("flip"):
			card = btn
			break
	_check("uretim kartinda cevirme simgesi var", card != null)
	if card != null:
		card.get_node("flip").pressed.emit()
		await _wait(0.5)
		_check("kart arkaya doner ve ozellikleri gosterir", card.text.contains("Can") and card.text.contains("Kara gücü"))
		_check("ekranin altinda ipucu gorunur", g.hud.tip_panel.visible and g.hud.tip_lbl.text.length() > 20)
		g.cam.focus = g.teams[0].hq.position + Vector3(16, 0, 6)
		g.cam.dist = 50.0
		await _shot("kart")
		card.pressed.emit()
		await _wait(0.5)
		_check("karta tekrar basinca on yuze doner", not card.text.contains("Kara gücü") and not g.hud.tip_panel.visible)

	# ---- toplanma noktası: yeni birlik oraya gider ve üst üste yığılmaz
	var rp: Vector3 = k.position + Vector3(20, 0, -10)
	g.begin_rally(k)
	g.set_rally(rp)
	_check("toplanma noktasi kaydedilir", k.rally.distance_to(rp) < 0.1)
	for n in 3:
		k._spawn(g.unit_of(0, "inf"))
	await _wait(9.0)
	var near := 0
	var spots: Array = []
	for e in g.entities:
		if e.team == 0 and e.cls == "inf" and Entity.flat(e.position, rp) < 9.0:
			near += 1
			spots.append(e.position)
	var apart := true
	for x in spots.size():
		for y in range(x + 1, spots.size()):
			if Entity.flat(spots[x], spots[y]) < 1.0:
				apart = false
	_check("yeni birlikler toplanma noktasina gider", near >= 3)
	_check("birlikler ust uste yigilmaz", apart)

	# ---- devriye
	var pp := _open_pair(20.0)
	var pu = g.spawn_unit(g.unit_of(0, "ifv"), 0, pp[0])
	g.select([pu])
	g.set_patrol(pp[1])
	_check("devriye emri verilir", pu.order == "patrol")
	var turned := false
	for n in 24:
		await _wait(0.5)
		if pu.dest.distance_to(pu.patrol_a) < 1.0:
			turned = true
	_check("devriye noktasina varip geri doner", pu.order == "patrol" and turned)
	if not turned:
		print("  devriye: a=%s b=%s pos=%s dest=%s pa=%s pb=%s tgt=%s near=%s nav=%s sel=%s" % [pp[0], pp[1], pu.position, pu.dest, pu.patrol_a, pu.patrol_b, [pu.target.cls, pu.target.team, pu.target.position, pu.target.alive], pu.near_t, pu.nav_ok, g.selection.size()])

	# ---- yapay zekâ (Orta): keşif, zayıf nokta, önce hava savunması, geri çekilme
	var ai: EnemyAI = g.ais[0]
	ai.P = Defs.DIFFS[1]
	ai.home = g.teams[1].hq.position
	ai.fwd = -signf(ai.home.x)
	var p_hq: Vector3 = g.teams[0].hq.position
	# iki oyuncu noktası: biri korunuyor, biri boş (YZ'ye en yakın iki nokta)
	var by_d: Array = g.points.duplicate()
	by_d.sort_custom(func(x, y): return Entity.flat(x.position, ai.home) < Entity.flat(y.position, ai.home))
	var pa = by_d[0]
	var pb = by_d[1]
	pa.claim(0)
	pb.claim(0)
	var guards: Array = []
	for n in 4:
		guards.append(g.spawn_unit(g.unit_of(0, "ifv"), 0, pa.position + Vector3(n * 3.0, 0, 4)))
	g._rebuild_buckets()
	var weak: Vector3 = ai._weak_spot(g, p_hq)
	_check("YZ en zayif savunulan hedefi secer", Entity.flat(weak, pb.position) < 1.0)
	var sam := g.spawn_building(Defs.bid(0, "sam"), 0, _land(pb.position + Vector3(10, 0, 0)), true)
	var jet = g.spawn_unit(g.unit_of(1, "fighter"), 1, pb.position + Vector3(18, 0, 0))
	var uav = g.spawn_unit(g.unit_of(1, "uav_strike"), 1, pb.position + Vector3(18, 0, 6))
	g.fog.recompute()
	ai._strike_air(g, pb.position)
	_check("YZ ucaklarla once hava savunmasini vurur", jet.target == sam)
	_check("YZ IHA'lari hava savunmasi susana kadar geride tutar", Entity.flat(uav.patrol, pb.position) > 20.0)
	var hurt = g.spawn_unit(g.unit_of(1, "tank"), 1, _land(Vector3(0, 0, 0)))
	hurt.hp = hurt.max_hp * 0.2
	ai._retreat(g)
	_check("YZ yarali birligi geri ceker", hurt.retreating)
	ai._scout(g, 100.0)
	_check("YZ kesif birligi atar ya da uretir", ai.scout != null or g.nearest_building(1, "kisla", ai.home) == null)
	for e in [jet, uav, hurt, sam] + guards:
		if is_instance_valid(e) and e.alive:
			e.die()
	pa.claim(Defs.NEUTRAL)
	pb.claim(Defs.NEUTRAL)

	# ---- 4: uçak pistten kalkar, mühimmat bitince piste iner, silahlanıp yeniden kalkar
	var af := g.spawn_building(Defs.bid(0, "havaalani"), 0, g.teams[0].hq.position + Vector3(10, 0, -24), true)
	g.teams[0].tier = 3
	af._spawn(g.unit_of(0, "fighter"))
	var jet0 = g.entities[g.entities.size() - 1]
	_check("ucak pistte kalkisa baslar", jet0 is AirUnit and jet0.state == "takeoff" and jet0.position.y < 1.0)
	g.cam.focus = af.position + Vector3(4, 0, 4)
	g.cam.dist = 34.0
	await _wait(2.2)
	await _shot("kalkis")
	await _wait(4.6)
	_check("ucak tirmanip devriyeye gecer", jet0.state == "patrol" and jet0.position.y > float(jet0.alt) * 0.9)
	jet0.ammo = 0
	var seen_states := {}
	for n in 60:
		await _wait(0.5)
		seen_states[jet0.state] = true
		if jet0.state == "takeoff":
			break
	_check("mühimmati biten ucak piste iner ve park eder", seen_states.has("landing") and seen_states.has("parked"))
	_check("silahlanan ucak yeniden kalkar", jet0.state == "takeoff" and jet0.ammo == int(jet0.d.ammo))

	# ---- 4: enkaz ve yanan bina
	var wt = g.spawn_unit(g.unit_of(1, "tank"), 1, _land(hq + Vector3(40, 0, -30)))
	var wm: Node3D = wt.model
	wt.die()
	await _wait(1.5)
	_check("yok edilen arac enkaz birakir", is_instance_valid(wm) and wm.get_parent() == g)
	g.cam.dist = 30.0
	var burn := g.spawn_building(Defs.bid(0, "santral"), 0, g.teams[0].hq.position + Vector3(-12, 0, 22), true)
	burn.seen = true
	burn.hp = burn.max_hp * 0.2
	var before_n := g.get_child_count()
	g.cam.focus = burn.position + Vector3(0, 0, 4)
	await _wait(1.6)
	await _shot("yangin")
	_check("agir hasarli bina tuter ve yanar", g.get_child_count() > before_n)

	# ---- 6: sıkışma, uzamsal ızgara, ayarlar, ses
	var jp := _land(hq + Vector3(30, 0, -10))
	var jam = g.spawn_unit(g.unit_of(0, "ifv"), 0, jp)
	jam.go(jp + Vector3(20, 0, 0), false)
	jam.speed = 0.0001
	# Hedef uzaktayken (köprü ya da geçit kuyruğu) hemen pes etmez, ama sonunda vazgeçer.
	var gave_up := false
	var early := false
	for n in 50:
		await _wait(0.5)
		if jam.order == "idle":
			gave_up = true
			early = n < 16
			break
	_check("sikisan birlik yanlara kayip sonunda vazgecer", gave_up and not early)
	var far := 0
	for e in g.nearby(Vector3.ZERO, 10.0):
		if Entity.flat(e.global_position, Vector3.ZERO) > 10.0 + Game.BUCKET * 2.0:
			far += 1
	var all_near := 0
	for e in g.entities:
		if e.alive and Entity.flat(e.global_position, jp) < 12.0:
			all_near += 1
	var grid_near := 0
	for e in g.nearby(jp, 12.0):
		if e.alive and Entity.flat(e.global_position, jp) < 12.0:
			grid_near += 1
	_check("uzamsal izgara yakindakilerin hepsini bulur", far == 0 and grid_near == all_near)
	_check("ayarlar okunur", Settings.get_v("sound") and Settings.KEYS.size() == 7 and Settings.get_v("nature") and not Settings.get_v("notch"))
	var st := Sfx.stream("cannon")
	_check("sesler sentezlenir", st != null and st.data.size() > 10000)

	# ---- doktrin, boş yuvalar, deneysel silahlar
	_check("Ukrayna'nin tanki yok", g.unit_of(0, "tank") == "")
	var fslots: Array = Defs.BUILDINGS[Defs.bid(0, "fabrika")].slots
	var rslots: Array = Defs.BUILDINGS[Defs.bid(1, "fabrika")].slots
	_check("bos yuva yerinde kalir (yuva duzeni ulkeden bagimsiz)", fslots.size() == rslots.size() and fslots.has("") and fslots[fslots.find("") ] == "")
	var fpv_id := g.unit_of(0, "sdrone_fpv")
	_check("IHA doktrininde dronlar ucuz", g.unit_cost(0, fpv_id) <= int(Defs.UNITS[fpv_id].cost) * 0.76)
	var bra := g.unit_of(0, "ifv")
	_check("IHA doktrininde zirhli pahali", g.unit_cost(0, bra) > int(Defs.UNITS[bra].cost) * 1.1)
	# doktrin fiyat çarpanları 0,75 ile 1,3 arasında kalır (aynı birim ülkeler arasında en çok ~1,7 kat farklı)
	var span_ok := true
	for dk in Scenarios.DOCTRINES:
		for mk in Scenarios.DOCTRINES[dk].mods:
			if String(mk).begins_with("cost_"):
				var mv := float(Scenarios.DOCTRINES[dk].mods[mk])
				if mv < 0.75 or mv > 1.3:
					span_ok = false
					print("   doktrin %s %s = %.2f" % [dk, mk, mv])
	_check("doktrin fiyat carpanlari 0,75-1,3 arasinda", span_ok)
	var expn := 0
	for id in Defs.UNITS:
		if Defs.UNITS[id].get("exp", false):
			expn += 1
	_check("deneysel silahlar isaretli", expn >= 4 and Defs.UNITS["ru_t14"].get("exp", false) and int(Defs.UNITS["ru_t14"].cost) > 1500)

	# ---- takımlar
	_check("takim iliskileri", Defs.foe(0, 1) and not Defs.foe(0, 0) and not Defs.foe(0, Defs.NEUTRAL))

	# ---- kaynak yatağı ve maden
	_check("baslangicta kaynak yataklari belirir", g.deposits.size() >= 1)
	var dep = g.deposits[0]
	_check("yataga birlik yokken maden kurulamaz", not g.can_place(0, "maden", dep.position) or Entity.flat(dep.position, hq) <= Defs.BUILD_ZONE)
	var esc = g.spawn_unit(g.unit_of(0, "ifv"), 0, g.terrain.nearest_free(dep.position + Vector3(8, 0, 0)))
	await _wait(0.1)
	_check("yatagin yaninda birlik varken maden kurulur", g.place_building(0, "maden", dep.position + Vector3(2, 0, 1)) and dep.mine != null)
	var mine = dep.mine
	_check("maden yatagin ortasina oturur", mine != null and Entity.flat(mine.position, dep.position) < 0.1)
	mine.built = true
	mine.hp = mine.max_hp
	var full: float = mine.mine_income()
	_check("maden gelir getirir", full >= Defs.DEPOSIT_RICH.x * 0.99)
	mine.take_damage(mine.max_hp * 0.5 / mine.damage_taken_mult())
	_check("hasarli madenin verimi duser", mine.mine_income() < full * 0.6)
	var mh: float = mine.hp
	mine._repair_tick()
	_check("vurulan maden bir sure onarilmaz", is_equal_approx(mine.hp, mh))
	mine.last_hit = -100.0
	mine._repair_tick()
	_check("yaninda birlik varken maden onarilir", mine.hp > mh)
	var inc_now: float = mine.mine_income()
	mine.held_t = Defs.MINE_HOLD_TIME
	_check("elde tutulan madenin verimi %20 artar", absf(mine.mine_income() / inc_now - 1.2) < 0.01)
	mine.held_t = 0.0
	var foe_near = g.spawn_unit(g.unit_of(1, "inf"), 1, g.terrain.nearest_free(mine.position + Vector3(-6, 0, 0)))
	g._rebuild_buckets()
	mh = mine.hp
	mine._repair_tick()
	_check("dusman yanindayken onarim durur", is_equal_approx(mine.hp, mh))
	foe_near.die()

	# ---- ikmal noktası tahribi ve onarımı
	var sp = g.points[g.points.size() - 1]
	sp.claim(1)
	var inc0: float = sp.current_income()
	sp.take_damage(sp.max_hp * 0.5)
	_check("hasarli noktanin geliri duser", sp.current_income() < inc0 * 0.6)
	sp.take_damage(sp.max_hp)
	_check("tahrip edilen nokta kimsesiz kalir", sp.owner_team == Defs.NEUTRAL)
	_check("tahrip edilen nokta bir sure tahrip kalir", sp.ruined() and sp.ruin_left() > Defs.RUIN_TIME - 2.0)
	sp.ruined_until = -1.0
	sp.last_hit = -100.0
	sp.claim(0)
	var guard = g.spawn_unit(g.unit_of(0, "ifv"), 0, g.terrain.nearest_free(sp.position + Vector3(5, 0, 0)))
	g._rebuild_buckets()
	var ph: float = sp.hp
	sp._repair()
	_check("askeri birlik varken nokta onarilir", sp.hp > ph)
	guard.die()
	sp.claim(Defs.NEUTRAL)

	# ---- lojistik: ikmal hattı ve ileri üs
	var far_p := _land(Vector3(0, 0, 0))
	var lone = g.spawn_unit(g.unit_of(0, "ifv"), 0, far_p)
	g._supply_tick()
	var far_ok: bool = not g.supplied(0, far_p)
	_check("ikmal hattinin disindaki birlik isaretlenir", not far_ok or not lone.supplied)
	if not lone.supplied:
		var db: float = lone.damage_base()
		lone.supplied = true
		_check("ikmalsiz birlik az hasar verir", db < lone.damage_base() * 0.8)
		lone.supplied = false
	g._rebuild_buckets()
	g.fog.recompute()
	_check("birlik yanindayken ileri us kurulur", g.place_building(0, "ileri", far_p + Vector3(8, 0, 6)))
	var fob = g.entities[g.entities.size() - 1]
	fob.built = true
	g._supply_tick()
	_check("ileri us ikmal saglar", g.supplied(0, far_p) and lone.supplied)
	var fob_ok := false
	var fob_why := []
	for i in 12:
		var ang := TAU * i / 12.0
		var why: String = g.place_reason(0, "kisla", fob.position + Vector3(cos(ang), 0, sin(ang)) * 13.0)
		fob_why.append(why)
		if why == "":
			fob_ok = true
	if not fob_ok:
		print("   ileri us: %s  %s" % [fob.position, fob_why])
	_check("ileri usun yanina kisla kurulabilir", fob_ok)
	_check("ileri usun yanina fabrika kurulamaz", g.place_reason(0, "fabrika", fob.position + Vector3(12, 0, 0)) != "")

	# ---- köprü: yıkılır, nehri kapatır, askerî varlıkla onarılır
	var br: Bridge = g.bridges[0]
	var bc: Vector3 = br.position
	_check("kopru gecilebilir", not ter.solid(bc))
	br.take_damage(br.max_hp * 2.0)
	_check("kopru yikilir ve nehri kapatir", br.down and ter.solid(bc))
	var fixer = g.spawn_unit(g.unit_of(0, "ifv"), 0, g.terrain.nearest_free(br.a))
	await _wait(3.0)
	_check("yeni vurulan kopru onarilmaz", br.down and br.repair_t == 0.0)
	br.last_hit = -100.0
	await _wait(Bridge.REPAIR_TIME + 3.0)
	_check("yanindaki birlikler kopruyu onarir", not br.down and not ter.solid(bc))
	_check("kopru tabliyesinin ustu yuksektir", absf(ter.height(bc) - Terrain.DECK_H) < 0.01)
	var foe_tank = g.spawn_unit(g.unit_of(1, "tank"), 1, g.terrain.nearest_free(br.b + (br.b - br.a).normalized() * 6.0))
	g.fog.recompute()
	_check("kopru gormeden de hedef alinir", foe_tank.can_hit(br))
	foe_tank.die()
	# yıkık köprüden geçilmez
	br.take_damage(br.max_hp * 2.0)
	var axis: Vector3 = (br.b - br.a).normalized()
	var walker = g.spawn_unit(g.unit_of(0, "ifv"), 0, g.terrain.nearest_free(br.a - axis * 6.0))
	walker.go(br.b + axis * 8.0, false)
	var crossed := false
	var wet := false
	var far_side: Vector3 = br.b + axis * 8.0
	for z_i in 30:
		await _wait(0.2)
		if Entity.flat(walker.position, far_side) < 5.0:
			crossed = true
		if ter.kind_at(walker.position) == Terrain.WATER:
			wet = true
	if crossed or wet:
		print("   kopru: a=%s b=%s birim=%s emir=%s" % [br.a, br.b, walker.position, walker.order])
	_check("yikik kopruden gecilmez", br.down and not crossed and not wet)
	walker.die()

	# ---- inşa alanı büyür
	var circles0: int = g.zone_circles(0).size()
	var edge := Vector3.INF
	for kk in 24:
		var q: Vector3 = hq + Vector3(cos(kk * TAU / 24.0), 0, sin(kk * TAU / 24.0)) * (Defs.BUILD_ZONE - 4.0)
		if g.can_place(0, "santral", q):
			edge = q
			break
	_check("alanin kenarina bina kurulur", edge != Vector3.INF)
	if edge != Vector3.INF:
		var outer: Vector3 = hq + (edge - hq).normalized() * (Defs.BUILD_ZONE + 10.0)
		_check("disaridaki nokta once alanda degil", not g.in_zone(0, outer))
		var sb := g.spawn_building(Defs.bid(0, "santral"), 0, edge, true)
		_check("kenardaki bina alani buyutur", g.zone_circles(0).size() == circles0 + 1 and g.in_zone(0, outer))
		g.fog.recompute()
		_check("insa alani sisle ortulmez", g.fog.sees(0, outer))
		sb.die()

	# ---- birlik listeleri
	for cc in Scenarios.COUNTRIES:
		var cnt := {}
		for u in Scenarios.COUNTRIES[cc].units:
			var ud: Dictionary = Scenarios.CLASSES[u[2]]
			if int(u[4].get("tier", 1)) >= 3:
				continue
			cnt[u[2]] = int(cnt.get(u[2], 0)) + 1
		var arty: int = int(cnt.get("arty", 0)) + int(cnt.get("mlrs", 0))
		var doc: String = Scenarios.COUNTRIES[cc].doctrine
		_check("%s: uzun menzilli zirhli sayisi" % cc, arty <= (2 if doc == "zirh" else 1))
		_check("%s: tek dron savar" % cc, int(cnt.get("spaag", 0)) + int(cnt.get("laser", 0)) == 1)
		_check("%s: zirhli hava savunma var" % cc, int(cnt.get("ads", 0)) == 1)
		_check("%s: ayni turden iki ucak yok" % cc, int(cnt.get("fighter", 0)) <= 1 and int(cnt.get("striker", 0)) <= 1 and int(cnt.get("stealth", 0)) <= 1)
	var ads_id := g.unit_of(0, "ads")
	var adsd: Dictionary = Defs.UNITS[ads_id]
	_check("zirhli hava savunma ucaga sert, yere zayif-orta vurur (zirhli aracin isini yapmaz)", float(adsd.mult.air) >= 1.2 and float(adsd.mult.heavy) < 0.3 and float(adsd.mult.light) < 0.5 and float(adsd.mult.inf) < 0.5)
	_check("buyuk hava savunmanin ucaga etkisi %20 azaldi, fuze onleme ayni", is_equal_approx(float(adsd.mult.air), 1.28) and is_equal_approx(float(adsd.mult.missile), 1.6)
		and is_equal_approx(float(Defs.BUILDINGS[Defs.bid(0, "sam")].mult.air), 0.8))
	var ua_fpv: Dictionary = Defs.UNITS[g.unit_of(0, "sdrone_fpv")]
	_check("Ukrayna kamikaze dronlari zirhliya %70 fazla vurur", Defs.COUNTRY[0] == "ua" and is_equal_approx(float(ua_fpv.mult.light), 1.2 * 1.7) and is_equal_approx(float(ua_fpv.mult.heavy), 0.65 * 1.7) and is_equal_approx(float(ua_fpv.mult.inf), 0.8))
	var ua_tb2: Dictionary = Defs.UNITS[g.unit_of(0, "uav_strike")]
	_check("Ukrayna silahli IHA'lari zirhliya %35 fazla vurur, TB2 3 fuzeli", is_equal_approx(float(ua_tb2.mult.heavy), 1.0 * 1.35) and int(ua_tb2.ammo) == 3)
	var ru_tanks := 0
	for u in Scenarios.COUNTRIES.ru.units:
		if u[2] == "tank":
			ru_tanks += 1
	_check("Rusya'da iki tank (T-72B3, T-14), T-90M ve Msta-S yok", ru_tanks == 2 and not Defs.UNITS.has("ru_t90") and not Defs.UNITS.has("ru_msta"))
	_check("piyadenin atesi %15 guclendi", is_equal_approx(float(Scenarios.CLASSES.inf.dmg), 13.8))
	var x_rc = g.spawn_unit(g.unit_of(0, "sdrone_recon"), 0, hq + Vector3(0, 0, 14))
	var x_fi = g.spawn_unit(g.unit_of(1, "inf"), 1, x_rc.position + Vector3(3, 0, 0))
	var x_aa = g.spawn_unit(g.unit_of(1, "spaag"), 1, x_rc.position + Vector3(-3, 0, 0))
	var x_fp = g.spawn_unit(g.unit_of(0, "sdrone_fpv"), 0, x_rc.position + Vector3(0, 0, 3))
	_check("piyade kesif dronunu vuramaz, dron savar vurur", not x_fi.can_hit(x_rc) and x_aa.can_hit(x_rc))
	_check("piyade FPV dronunu hala vurabilir", x_fi.can_hit(x_fp))
	for x in [x_rc, x_fi, x_aa, x_fp]:
		x.die()
	_check("piyade %10 hizli, kara araci %5 yavas", is_equal_approx(float(Defs.UNITS[g.unit_of(0, "inf")].speed), 3.4 * 1.1) and is_equal_approx(float(Defs.UNITS[g.unit_of(0, "ifv")].speed), 5.2 * 0.95))
	_check("IHA gorusu genis", float(Defs.UNITS[g.unit_of(0, "uav_strike")].vision) >= 30.0)
	for r in Scenarios.RESEARCH:
		_check("arastirma aciklamasi: %s" % r.id, String(r.desc).length() > 20)
	# (köprünün yanındaki onarıcı, köprü yeniden yıkılınca suya düşmüş olabilir)
	for e in [fixer, lone, esc]:
		if is_instance_valid(e) and e.alive:
			e.die()

	# ---- hava savunması, yardım, saldırı emri, inşaat iptali, ikmal, füze canı, uçak onarımı, hava akını
	var hs_p := _land(hq + Vector3(30, 0, 30))
	var gun = g.spawn_unit(g.unit_of(0, "spaag") if g.unit_of(0, "spaag") != "" else g.unit_of(0, "laser"), 0, hs_p)
	var walker2 = g.spawn_unit(g.unit_of(1, "inf"), 1, g.terrain.nearest_free(hs_p + Vector3(8, 0, 0)))
	g.fog.recompute()
	_check("dron savar yerdeki piyadeyi vurabilir", gun.can_hit(walker2))
	var hp0: float = walker2.hp
	await _wait(2.0)
	_check("dron savar yerdeki dusmana kendiliginden ates eder", walker2.hp < hp0)
	var hs_fpv_id: String = g.unit_of(1, "sdrone_fpv")
	if hs_fpv_id != "":
		var hs_fpv = g.spawn_unit(hs_fpv_id, 1, hs_p + Vector3(-10, 0, 4))
		hs_fpv.set_process(false)
		await _wait(3.0)
		_check("dron savar yer hedefini birakip drona doner ve dusurur", not is_instance_valid(hs_fpv) or not hs_fpv.alive)
	walker2.die()
	gun.die()
	var samb := g.spawn_building(Defs.bid(0, "sam"), 0, g.terrain.nearest_free(hq + Vector3(-20, 0, -24)), true)
	var raider = g.spawn_unit(g.unit_of(1, "ifv"), 1, g.terrain.nearest_free(samb.position + Vector3(14, 0, 0)))
	raider.set_process(false)
	g.fog.recompute()
	var rh: float = raider.hp
	await _wait(3.5)
	_check("hava savunma binasi yerdeki hedefe ates eder (us savunmasi)", raider.hp < rh)
	raider.die()
	# yardım: dosta saldırı varsa yakındaki boştaki birlik saldırgana yönelir
	var hp2 := _land(hq + Vector3(-34, 0, 28))
	var z_victim = g.spawn_unit(g.unit_of(0, "inf"), 0, hp2)
	var friend = g.spawn_unit(g.unit_of(0, "ifv"), 0, g.terrain.nearest_free(hp2 + Vector3(-12, 0, 0)))
	var busy = g.spawn_unit(g.unit_of(0, "ifv"), 0, g.terrain.nearest_free(hp2 + Vector3(-10, 0, 6)))
	busy.go(hp2 + Vector3(0, 0, -50), false)
	var foe2 = g.spawn_unit(g.unit_of(1, "ifv"), 1, g.terrain.nearest_free(hp2 + Vector3(15, 0, 0)))
	foe2.set_process(false)
	await _wait(0.2)
	z_victim.take_damage(10.0, foe2)
	_check("dosta saldiri olunca yakindaki birlik yardima gelir", friend.target == foe2)
	if busy.order != "move":
		print("   yuruyen: emir=%s hedef=%s" % [busy.order, busy.dest])
	_check("yuruyen birligin emri bozulmaz", busy.order == "move" and busy.target != friend)
	# saldırı emri: hedefe ateş edemeyen birlik ilerlemez
	var ewid: String = g.unit_of(0, "ew")
	if ewid != "":
		var ewu = g.spawn_unit(ewid, 0, g.terrain.nearest_free(hp2 + Vector3(-14, 0, -6)))
		var ep: Vector3 = ewu.position
		g.order_attack([ewu], foe2)
		await _wait(1.0)
		_check("ates edemeyen birlik hedefin dibine girmez", Entity.flat(ewu.position, ep) < 0.5 and ewu.order != "attack")
		ewu.die()
	for z_u in [z_victim, friend, busy, foe2]:
		if is_instance_valid(z_u) and z_u.alive:
			z_u.die()
	# inşaat iptali: para tamamen geri gelir
	var z_spot := Vector3.INF
	for z_kk in 24:
		var z_q: Vector3 = hq + Vector3(cos(z_kk * TAU / 24.0), 0, sin(z_kk * TAU / 24.0)) * 20.0
		if g.can_place(0, "kisla", z_q):
			z_spot = z_q
			break
	var m0: float = g.teams[0].money
	if z_spot != Vector3.INF and g.place_building(0, "kisla", z_spot):
		var nb: Building = g.entities[g.entities.size() - 1]
		_check("insaat parasi duser", g.teams[0].money < m0)
		g.cancel_building(nb)
		await _wait(0.2)
		_check("insaat iptal edilince para geri gelir ve bina kalkar", absf(g.teams[0].money - m0) < 30.0 and (not is_instance_valid(nb) or not nb.alive) and not g.entities.has(nb))
	else:
		_check("iptal denemesi icin kisla kurulur", false)
	# ikmal noktası: az para, geniş ikmal alanı
	var sup = null
	for p in g.points:
		if p.kind == "supply":
			sup = p
			break
	_check("ikmal noktasi $2 getirir, genis alani besler", sup != null and is_equal_approx(sup.income, 2.0) and SupplyPoint.SUPPLY_R >= 60.0)
	# balistik füze: hava savunması canını düşürür
	var s := Shot.new()
	g.add_child(s)
	s.src_team = 1
	s.bhp_max = 300.0
	s.bhp = 300.0
	s.t = 0.6
	s.global_position = samb.position + Vector3(4, 12, 0)
	samb.cd_timer = 0.0
	s._air_defense()
	_check("hava savunmasi balistik fuzenin canini dusurur (ya da iska)", s.bhp < 300.0 or samb.cd_timer > 0.0)
	s.queue_free()
	samb.die()
	# uçak pistte onarılır
	var z_af := g.spawn_building(Defs.bid(0, "havaalani"), 0, g.terrain.nearest_free(hq + Vector3(26, 0, -30)), true)
	var jid: String = g.unit_of(0, "fighter") if g.unit_of(0, "fighter") != "" else g.unit_of(0, "uav_strike")
	var jet2 = g.spawn_unit(jid, 0, z_af.position)
	jet2.hp = jet2.max_hp * 0.3
	jet2.state = "parked"
	jet2.rearm_t = 0.0
	await _wait(float(jet2.d.get("rearm", 8.0)) * g.mod(0, "rearm") + 6.0)
	_check("ucak inince onarilir", jet2.hp >= jet2.max_hp * 0.99)
	jet2.die()
	z_af.die()
	# hava akını: iki uçak gelir, bombalar, döner ve kaybolur
	var tgt := _land(hq + Vector3(60, 0, 0))
	var dummy = g.spawn_unit(g.unit_of(1, "ifv"), 1, tgt)
	dummy.set_process(false)
	dummy.max_hp = 1e6
	dummy.hp = 1e6
	var z_before := g.entities.size()
	g._air_raid(0, tgt)
	_check("hava akini iki ucak gonderir", g.entities.size() == z_before + 2)
	var t0: float = g.time
	while g.time - t0 < 40.0 and dummy.hp >= 1e6:
		await _wait(0.5)
	_check("hava akini hedefi bombalar", dummy.hp < 1e6)
	var gone := false
	while g.time - t0 < 70.0 and not gone:
		await _wait(0.5)
		gone = true
		for z_e in g.entities:
			if z_e is AirUnit and z_e.state == "raid":
				gone = false
	_check("hava akini ucaklari donup kaybolur", gone)
	dummy.die()

	# Füze Üssü varken sol panelde füze düğmeleri çıkar ve hedef seçimini başlatır.
	g.teams[0].tier = 3
	g.teams[0].money = 50000.0
	var fz := g.spawn_building(Defs.bid(0, "fuze"), 0, g.terrain.nearest_free(hq + Vector3(-24, 0, -30)), true)
	g.hud._update_missiles()
	_check("sol panelde fuze dugmesi cikar", g.hud.mis_box.visible and g.hud.mis_btns[0].visible and not g.hud.mis_btns[0].disabled)
	g.hud._side_missile(0)
	_check("sol paneldeki fuze dugmesi hedef secimini baslatir", g.targeting == fz and g.targeting_i == 0)
	g.cancel_targeting()
	fz.die()
	await _wait(0.2)
	g.hud._update_missiles()
	_check("fuze ussu yokken dugme gizlenir", not g.hud.mis_box.visible)

	# ---- kayıt
	if not is_instance_valid(b) or not b.alive:
		b = g.spawn_unit(g.unit_of(0, "inf"), 0, _land(hq + Vector3(-12, 0, 12)))
	g.order_task([b], "dig")
	await _wait(Defs.DIG_TIME + 0.6)
	g.save_game()
	var info := Game.saved_info()
	var alive := 0
	for e in g.entities:
		if e.alive:
			alive += 1
	_check("oyun kaydedilir", not info.is_empty() and info.ents.size() == alive and int(info.scn) == 0)
	var f := FileAccess.open("user://mechtest_sayi.txt", FileAccess.WRITE)
	f.store_string("%d %d %d" % [alive, int(g.teams[0].money), int(g.time)])
	f = null

	# ---- piyadenin sahada onarımı
	var x_rp := _land(hq + Vector3(-40, 0, 40))
	var x_rb := g.spawn_building(Defs.bid(0, "kisla"), 0, x_rp, true)
	x_rb.hp = x_rb.max_hp * 0.5
	var x_rv = g.spawn_unit(g.unit_of(0, "ifv"), 0, x_rp + Vector3(x_rb.radius + 5.0, 0, 0))
	x_rv.hp = x_rv.max_hp * 0.5
	var x_medic = g.spawn_unit(g.unit_of(0, "inf"), 0, x_rp + Vector3(x_rb.radius + 2.5, 0, 0))
	await _wait(3.0)
	_check("piyade yanindaki binayi onarir", x_rb.hp > x_rb.max_hp * 0.505 and x_rb.hp < x_rb.max_hp * 0.6)
	_check("piyade yanindaki zirhliyi onarir", x_rv.hp > x_rv.max_hp * 0.51 and x_rv.hp < x_rv.max_hp * 0.62)
	x_rv.take_damage(1.0)
	var x_rv_hp: float = x_rv.hp
	await _wait(2.0)
	_check("yeni vurulan zirhli hemen onarilmaz", x_rv.hp <= x_rv_hp + 0.01)
	x_medic.die()
	x_rv.die()

	# ---- birlik sınırında birim sırada bekler
	var x_ts0 = g.teams[0]
	var x_cap0: int = x_ts0.pop_cap
	x_ts0.pop_cap = x_ts0.pop
	x_ts0.money += 1000.0
	var x_qn: int = x_rb.queue.size()
	_check("birlik siniri doluyken birim kuyruga girer", g.queue_unit(x_rb, g.unit_of(0, "inf")) and x_rb.queue.size() == x_qn + 1)
	x_rb.prod_t = 999.0
	await _wait(0.5)
	_check("sinir doluyken birim sirada bekler", x_rb.queue.size() == x_qn + 1 and x_rb.waiting_cap())
	x_ts0.pop_cap = x_cap0
	await _wait(0.5)
	_check("yer acilinca birim cikar", x_rb.queue.size() == x_qn)
	_check("birlik siniri 45", Defs.POP_CAP == 45)

	# ---- saldırı simgeleri: yeniden eskiye
	g.alert_base(hq + Vector3(100, 0, 0), "Deneme A")
	await _wait(0.3)
	g.alert_base(hq + Vector3(-100, 0, 0), "Deneme B")
	var x_al: Array = g.attack_list()
	_check("saldiri simgeleri yeniden eskiye", x_al.size() >= 2 and x_al[0].what == "Deneme B")

	# ---- bütün silahlı kara birlikleri binaya ateş eder
	var x_tp := _land(hq + Vector3(60, 0, -60))
	var x_tb := g.spawn_building(Defs.bid(1, "kisla"), 1, x_tp, true)
	x_tb.max_hp = 1.0e7
	x_tb.hp = x_tb.max_hp
	var x_shooters: Array = []
	var x_k := 0
	for x_id in Defs.UNITS:
		var x_ud: Dictionary = Defs.UNITS[x_id]
		if x_ud.cc != Defs.COUNTRY[0] or x_ud.get("air", false) or not x_ud.has("dmg"):
			continue
		var x_ang := x_k * TAU / 12.0
		x_k += 1
		var x_sp: Vector3 = g.terrain.nearest_free(x_tp + Vector3(cos(x_ang), 0, sin(x_ang)) * (x_tb.radius + 14.0 + float(x_ud.get("min_range", 0.0))))
		var x_su = g.spawn_unit(x_id, 0, x_sp)
		x_shooters.append(x_su)
	g.fog.recompute()
	g.order_attack(x_shooters, x_tb)
	await _wait(25.0)
	for x_su in x_shooters:
		_check("%s binaya ates eder" % x_su.d.name, x_su.alive and x_su.xp > 0.0)
		if not (x_su.alive and x_su.xp > 0.0):
			print("    emir=%s hedef=%s uzaklik=%.1f menzil=%.1f vurabilir=%s gorus=%s alive=%s" % [x_su.order, x_su.target == x_tb, Entity.flat(x_su.position, x_tb.position) - x_tb.radius, x_su.weapon_range(), x_su.can_hit(x_tb), g.terrain.los_clear(x_su.global_position, x_tb.global_position, Entity.los_skip(x_tb)), x_su.alive])
		x_su.die()
	x_tb.die()

	print("MECHTEST BITTI  hata=%d" % fails)
	get_tree().quit(1 if fails > 0 else 0)
